// Trigger when an appointment is updated
import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as nodemailer from "nodemailer";
import { https, logger } from "firebase-functions/v2";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";



admin.initializeApp();
const db = admin.firestore();

export const sendAppointmentNotification = onDocumentUpdated(
  "appointments/{appointmentId}",
  async (event) => {
    if (!event.data) {
      console.error("Event data is undefined.");
      return;
    }

    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    if (!beforeData || !afterData) return;

    // Only trigger if the status changed
    if (beforeData.status === afterData.status) return;

    const studId = afterData.studId;
    const status = afterData.status;

    let messageText = "";
    let titleText = "Appointment Update";

    if (status === "accepted") {
      titleText = "Appointment Accepted";
      messageText = "Your appointment request has been accepted.";
    } else if (status === "missed") {
      titleText = "Missed Appointment";
      messageText = "You've missed your appointment.";
    } else if (status === "completed") {
      titleText = "Appointment Completed";
      messageText = "Thank you for attending your appointment.";
    } else {
      messageText = `Your appointment status has been updated to "${status}".`;
    }

    try {
      // Save notification to Firestore (with seen = false by default)
      const notifRef = db.collection("notifications").doc();
      await notifRef.set({
        studId,
        notifId: notifRef.id,
        notifType: "appointment",
        message: messageText,
        path: "/home_page",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        seen: false,
      });

      // Get student's FCM tokens
      const userQuery = await db
        .collection("Users")
        .where("studId", "==", studId)
        .limit(1)
        .get();

      if (userQuery.empty) {
        console.log(`⚠️ No user found with studId ${studId}`);
        return;
      }

      const tokens: string[] = userQuery.docs[0].data().fcmTokens || [];
      if (tokens.length === 0) {
        console.log(`⚠️ No FCM tokens found for studId ${studId}`);
        return;
      }

      // Send push notification
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: titleText,
          body: messageText,
        },
        android: { notification: { clickAction: "FLUTTER_NOTIFICATION_CLICK" } },
        apns: { payload: { aps: { category: "FLUTTER_NOTIFICATION_CLICK" } } },
      });

      console.log(
        `📢 Appointment notification sent: ${response.successCount} success, ${response.failureCount} failed`
      );

      if (response.failureCount > 0) {
        console.error(
          "Failed tokens:",
          response.responses.filter((r) => !r.success).map((r) => r.error)
        );
      }
    } catch (err) {
      console.error("❌ Error sending notification:", err);
    }
  }
);

export const sendCustomNotification = onDocumentCreated(
  "notificationRequests/{requestId}",
  async (event) => {
    if (!event.data) {
      console.error("❌ No event data found.");
      return;
    }

    const requestData = event.data.data();
    const studId = requestData.studId;
    const templateId = requestData.templateId;

    if (!studId || !templateId) {
      console.error("⚠️ Missing studId or templateId in request document.");
      return;
    }

    try {
      // ✅ Fetch the template data
      const templateDoc = await db.collection("templates").doc(templateId).get();
      if (!templateDoc.exists) {
        console.warn(`⚠️ Template not found for ID: ${templateId}`);
        return;
      }

      const { title, message } = templateDoc.data() as {
        title: string;
        message: string;
      };

      // ✅ Create notification document in Firestore
      const notifRef = db.collection("notifications").doc();
      await notifRef.set({
        notifId: notifRef.id,
        studId,
        notifType: "notification",
        message,
        path: "/moodTracker",
        seen: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // ✅ Find the user and retrieve their FCM tokens
      const userQuery = await db
        .collection("Users")
        .where("studId", "==", studId)
        .limit(1)
        .get();

      if (userQuery.empty) {
        console.warn(`⚠️ No user found with studId ${studId}`);
        return;
      }

      const userData = userQuery.docs[0].data();

      // ✅ Handle tokens as array or single string
      let tokens: string[] = [];

      if (Array.isArray(userData.fcmTokens)) {
        tokens = userData.fcmTokens.filter((t) => typeof t === "string");
      } else if (typeof userData.fcmToken === "string") {
        tokens = [userData.fcmToken];
      }

      if (tokens.length === 0) {
        console.warn(`⚠️ No valid FCM tokens found for studId ${studId}`);
        return;
      }

      // ✅ Send push notification to all tokens
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: title || "Notification",
          body: message || "You have a new update.",
        },
        android: {
          notification: { clickAction: "FLUTTER_NOTIFICATION_CLICK" },
        },
        apns: {
          payload: { aps: { category: "FLUTTER_NOTIFICATION_CLICK" } },
        },
      });

      console.log(
        `📢 Notification sent to ${tokens.length} devices — ${response.successCount} succeeded, ${response.failureCount} failed`
      );

      // ✅ (Optional) Clean up request document
      await db
        .collection("notificationRequests")
        .doc(event.params.requestId)
        .delete();

    } catch (error) {
      console.error("❌ Error sending custom notification:", error);
    }
  }
);

export const notifyNewAppointmentRequest = onDocumentCreated(
  "appointments/{appointmentId}",
  async (event) => {
    if (!event.data) {
      console.error("❌ Event data is undefined.");
      return;
    }

    const appointmentData = event.data.data();
    const appointmentId = event.params.appointmentId;

    if (!appointmentData) {
      console.error("❌ Appointment data is missing.");
      return;
    }

    // Only create notification for pending/request appointments
    if (appointmentData.status?.toLowerCase() !== "pending") {
      console.log("⏭️ Skipping notification - status is not pending");
      return;
    }

    const counId = appointmentData.counId;
    const firstName = appointmentData.firstName || "Unknown";
    const studId = appointmentData.studId || "N/A";

    if (!counId) {
      console.warn("⚠️ No counselor ID found in appointment");
      return;
    }

    try {
      // Create notification document
      const notifRef = db.collection("notifications").doc();
      await notifRef.set({
        counId: counId,
        message: `You have a new request appointment from ${firstName} (${studId})`,
        notifType: "Request",
        path: "/appointments_ad",
        notifId: notifRef.id,
        appointmentId: appointmentId,
        seen: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Notification created for counselor ${counId} about appointment ${appointmentId}`);

      // Optional: Get counselor's FCM tokens and send push notification
      const counselorQuery = await db
        .collection("Users")
        .where("counId", "==", counId)
        .limit(1)
        .get();

      if (counselorQuery.empty) {
        console.log(`⚠️ No counselor found with counId ${counId}`);
        return;
      }

      const counselorData = counselorQuery.docs[0].data();
      
      // Handle tokens as array or single string
      let tokens: string[] = [];
      if (Array.isArray(counselorData.fcmTokens)) {
        tokens = counselorData.fcmTokens.filter((t) => typeof t === "string");
      } else if (typeof counselorData.fcmToken === "string") {
        tokens = [counselorData.fcmToken];
      }

      if (tokens.length === 0) {
        console.log(`⚠️ No FCM tokens found for counselor ${counId}`);
        return;
      }

      // Send push notification to counselor
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "New Appointment Request",
          body: `${firstName} (${studId}) has requested an appointment`,
        },
        data: {
          path: "/appointments_ad",
          appointmentId: appointmentId,
          type: "appointment_request",
        },
        android: { 
          notification: { 
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            channelId: "appointment_requests",
          } 
        },
        apns: { 
          payload: { 
            aps: { 
              category: "FLUTTER_NOTIFICATION_CLICK",
              sound: "default",
            } 
          } 
        },
      });

      console.log(
        `📢 Push notification sent: ${response.successCount} success, ${response.failureCount} failed`
      );

      if (response.failureCount > 0) {
        console.error(
          "Failed tokens:",
          response.responses.filter((r) => !r.success).map((r) => r.error)
        );
      }

    } catch (err) {
      console.error("❌ Error creating notification for new appointment:", err);
    }
  }
);

export const notifyNewFeedback = onDocumentCreated(
  "feedback/{feedbackId}",
  async (event) => {
    if (!event.data) {
      console.error("❌ No event data found for feedback.");
      return;
    }

    const feedbackData = event.data.data();
    const feedbackId = event.params.feedbackId;

    if (!feedbackData) {
      console.error("❌ Feedback data is missing.");
      return;
    }

    const counId = feedbackData.counId;
    const studId = feedbackData.studId;

    if (!counId || !studId) {
      console.warn("⚠️ Missing counId or studId in feedback document.");
      return;
    }

    try {
      // ✅ Get student's first name from Users collection
      const userQuery = await db
        .collection("Users")
        .where("studId", "==", studId)
        .limit(1)
        .get();

      if (userQuery.empty) {
        console.warn(`⚠️ No user found with studId ${studId}`);
        return;
      }

      const userData = userQuery.docs[0].data();
      const firstName = userData.firstName || "A student";

      // ✅ Create notification in Firestore
      const notifRef = db.collection("notifications").doc();
      await notifRef.set({
        notifId: notifRef.id,
        counId: counId,
        notifType: "Feedback",
        message: `${firstName} gives feedback.`,
        seen: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        path: "/FeedbackAd",
      });

      console.log(`✅ Feedback notification created for counselor ${counId}`);

      // ✅ Optional: Send push notification to counselor
      const counselorQuery = await db
        .collection("Users")
        .where("counId", "==", counId)
        .limit(1)
        .get();

      if (counselorQuery.empty) {
        console.log(`⚠️ No counselor found with counId ${counId}`);
        return;
      }

      const counselorData = counselorQuery.docs[0].data();

      // Handle tokens as array or single string
      let tokens: string[] = [];
      if (Array.isArray(counselorData.fcmTokens)) {
        tokens = counselorData.fcmTokens.filter((t) => typeof t === "string");
      } else if (typeof counselorData.fcmToken === "string") {
        tokens = [counselorData.fcmToken];
      }

      if (tokens.length === 0) {
        console.log(`⚠️ No FCM tokens found for counselor ${counId}`);
        return;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "New Feedback Received",
          body: `${firstName} has given feedback.`,
        },
        data: {
          path: "/FeedbackAd",
          feedbackId: feedbackId,
          type: "feedback_notification",
        },
        android: {
          notification: {
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            channelId: "feedback_channel",
          },
        },
        apns: {
          payload: {
            aps: {
              category: "FLUTTER_NOTIFICATION_CLICK",
              sound: "default",
            },
          },
        },
      });

      console.log(
        `📢 Feedback push notification sent: ${response.successCount} success, ${response.failureCount} failed`
      );

      if (response.failureCount > 0) {
        console.error(
          "Failed tokens:",
          response.responses.filter((r) => !r.success).map((r) => r.error)
        );
      }

    } catch (error) {
      console.error("❌ Error creating feedback notification:", error);
    }
  }
);

export const sendPasswordResetOTP = onCall(async (request) => {
  try {
    const studId = request.data?.studId;
    const counId = request.data?.counId;

    console.log("Received studId:", studId, "counId:", counId);

    // Must provide either studId or counId, but not both
    if ((!studId && !counId) || (studId && counId)) {
      throw new HttpsError(
        "invalid-argument",
        "Either Student ID or Counselor ID is required (but not both)."
      );
    }

    const userId = studId || counId;
    const userIdField = studId ? "studId" : "counId";

    if (typeof userId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "User ID must be a string."
      );
    }

    // 🔎 Fetch user by studId or counId
    const userSnap = await admin
      .firestore()
      .collection("Users")
      .where(userIdField, "==", userId)
      .limit(1)
      .get();

    if (userSnap.empty) {
      throw new HttpsError(
        "not-found",
        `No user found with that ${userIdField === "studId" ? "Student" : "Counselor"} ID.`
      );
    }

    const userDoc = userSnap.docs[0];
    const userData = userDoc.data();
    const recoveryEmail = userData.recoveryEmail;

    if (!recoveryEmail) {
      throw new HttpsError(
        "failed-precondition",
        "No recovery email associated with this account."
      );
    }

    // 🔢 Generate OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 5 * 60 * 1000)
    );

    // Store OTP with the appropriate ID field
    const otpData: any = {
      otp,
      expiresAt,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Add the appropriate ID field
    if (studId) {
      otpData.studId = studId;
    } else {
      otpData.counId = counId;
    }

    await admin.firestore().collection("OTP").doc(userId).set(otpData);

    console.log("✅ OTP saved to Firestore:", otp);

    // 📧 Configure nodemailer
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: "rumini.site@gmail.com",
        pass: "wzeutymcamtsnysr",
      },
    });

    const mailOptions = {
      from: "PLV Guidance Support <rumini.site@gmail.com>",
      to: recoveryEmail,
      subject: "Your Password Reset OTP",
      text: `Hello ${userId},\n\nYour OTP code is: ${otp}\n\nThis code will expire in 5 minutes.`,
    };

    console.log("📧 Attempting to send email to:", recoveryEmail);

    await transporter.sendMail(mailOptions);

    console.log("✅ Email sent successfully!");

    return {
      success: true,
      message: `OTP sent to ${recoveryEmail}`,
    };
  } catch (error) {
    console.error("❌ Error in sendPasswordResetOTP:", error);
    
    // If it's already an HttpsError, rethrow it
    if (error instanceof HttpsError) {
      throw error;
    }
    
    // Otherwise, wrap it in an INTERNAL error with details
    throw new HttpsError(
      "internal",
      `Failed to send OTP: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
});

export const resetUserPassword = https.onCall(
  async (request: any) => {
    const { studId, counId, newPassword } = request.data;

    // Must provide either studId or counId, but not both
    if ((!studId && !counId) || (studId && counId)) {
      throw new https.HttpsError(
        'invalid-argument',
        'Either Student ID or Counselor ID is required (but not both).'
      );
    }

    if (!newPassword) {
      throw new https.HttpsError('invalid-argument', 'New password is required.');
    }

    const userId = studId || counId;
    const userIdField = studId ? 'studId' : 'counId';

    try {
      const usersRef = admin.firestore().collection('Users');
      const userQuery = await usersRef.where(userIdField, '==', userId).get();

      if (userQuery.empty) {
        throw new https.HttpsError('not-found', 'User not found.');
      }

      const userDoc = userQuery.docs[0];
      const userData = userDoc.data();
      const uid = userData.uid;

      if (!uid) {
        throw new https.HttpsError('failed-precondition', 'UID missing in Firestore.');
      }

      await admin.auth().updateUser(uid, { password: newPassword });

      console.log(`Password reset successfully for UID: ${uid} (${userIdField}: ${userId})`);
      return { message: 'Password reset successfully!' };
    } catch (error: any) {
      console.error('Password reset error:', error);
      throw new https.HttpsError('internal', error.message);
    }
  }
);

export const deleteUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const db = getFirestore();
  const currentUserDoc = await db.collection('Users').doc(request.auth.uid).get();
  const currentUserRole = currentUserDoc.data()?.role;

  if (currentUserRole !== 'Admin' && currentUserRole !== 'Counselor') {
    throw new HttpsError('permission-denied', 'Only admins and counselors can delete users.');
  }

  const {uid} = request.data;
  if (!uid) throw new HttpsError('invalid-argument', 'UID is required.');
  if (uid === request.auth.uid) {
    throw new HttpsError('invalid-argument', 'Cannot delete your own account through this function.');
  }

  try {
    await getAuth().deleteUser(uid);
    logger.info(`Successfully deleted user ${uid} from Authentication`);
    return {success: true, message: `User ${uid} deleted successfully from Authentication`};
  } catch (error: any) {
    logger.error('Error deleting user:', error);
    throw new HttpsError('internal', `Failed to delete user: ${error.message}`);
  }
});


// Initialize admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

interface UserData {
  uid?: string;
  role?: string;
  [key: string]: any;
}

interface CreateUserAccountData {
  email: string;
  password: string;
  userData: UserData;
}

export const createUserAccount = https.onCall(
  async (request) => {
    const data = request.data as CreateUserAccountData;
    const context = request.auth;

    // Verify that the request is coming from an authenticated user
    if (!context) {
      throw new https.HttpsError(
        'unauthenticated',
        'User must be authenticated to create accounts.'
      );
    }

    // Verify that the caller is an Admin or Counselor
    const callerUid = context.uid;
    const callerDoc = await admin.firestore().collection('Users').doc(callerUid).get();
    const callerRole = callerDoc.data()?.role;

    if (callerRole !== 'Admin' && callerRole !== 'Counselor') {
      throw new https.HttpsError(
        'permission-denied',
        'Only Admins and Counselors can create user accounts.'
      );
    }

    const { email, password, userData } = data;

    try {
      // Check if email already exists
      try {
        await admin.auth().getUserByEmail(email);
        throw new https.HttpsError(
          'already-exists',
          'The email address is already in use by another account.'
        );
      } catch (error: any) {
        // If user doesn't exist, continue (this is what we want)
        if (error.code !== 'auth/user-not-found') {
          throw error;
        }
      }

      // Create the user in Firebase Authentication
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
      });

      // Add the UID to userData
      userData.uid = userRecord.uid;

      // Create the user document in Firestore
      await admin.firestore().collection('Users').doc(userRecord.uid).set(userData);

      return {
        success: true,
        uid: userRecord.uid,
        message: 'User account created successfully'
      };
    } catch (error: any) {
      logger.error('Error creating user:', error);
      
      // Handle specific error cases
      if (error.code === 'auth/email-already-exists') {
        throw new https.HttpsError(
          'already-exists',
          'The email address is already in use by another account.'
        );
      }
      
      throw new https.HttpsError('internal', error.message);
    }
  }
);

