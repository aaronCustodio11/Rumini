import 'package:rumini/components/navbar.dart';
import 'package:rumini/pages(admin)/chatbot_ad.dart';
import 'package:rumini/pages(admin)/chathistory_ad.dart';
import 'package:rumini/pages(admin)/feedbackAd.dart';
import 'package:rumini/pages(admin)/forms/formsAd.dart';
import 'package:rumini/pages(admin)/monitoring/monitor_ad.dart';
import 'package:rumini/pages(admin)/profilePage/profile_Ad.dart';
import 'package:rumini/pages(admin)/psychoeducAd.dart';
import 'package:rumini/pages(admin)/templates/templates_ad.dart';
import 'package:rumini/pages(user)/home/home_page.dart';
import 'package:rumini/loginPage/login_page.dart';
import 'package:rumini/pages(user)/moodtracker/moodtracker.dart';
import 'package:rumini/pages(user)/notifications/notif.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;            // ✅ added
import 'dart:io' show Platform;                                  // ✅ added
import 'package:rumini/firebase_options.dart';
import 'package:rumini/pages(admin)/appointments_ad.dart';
import 'package:rumini/pages(admin)/userdashboard/user_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ Safe notification permission request (Does NOT break web)
Future<void> requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // ✅ Web (must be inside try/catch and only simple request)
  if (kIsWeb) {
    try {
      NotificationSettings settings = await messaging.requestPermission();
      print("✅ Web notification permission: ${settings.authorizationStatus}");
    } catch (e) {
      print("⚠️ Web permission request error: $e");
    }
    return;
  }

  // ✅ Mobile (Android/iOS)
  try {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print("✅ Mobile notification permission: ${settings.authorizationStatus}");
  } catch (e) {
    print("❌ Mobile permission request error: $e");
  }
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());   // ✅ build UI first

  // ✅ ask for notifications ONLY after runApp()
  requestNotificationPermission();
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 🔹 Fetch user Firestore profile
  Future<Map<String, dynamic>> _getUserData(User user) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (!snapshot.exists) {
        print("⚠️ No Firestore document for user ${user.uid}");
        return {};
      }
      return snapshot.data() ?? {};
    } catch (e) {
      print("❌ Error fetching user data: $e");
      return {};
    }
  }

  /// 🔹 Save FCM token to Firestore
  Future<void> saveDeviceToken(User user) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final userDoc =
          FirebaseFirestore.instance.collection("Users").doc(user.uid);

      await userDoc.set({
        "fcmTokens": FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));

      print("✅ FCM token saved for user: ${user.uid}");
    } catch (e) {
      print("❌ Error saving FCM token: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData) {
            return const LoginPage();
          }

          final user = snapshot.data!;
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(user),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasError) {
                return const Scaffold(
                  body: Center(
                    child: Text("Something went wrong. Please try again."),
                  ),
                );
              }

              final userData = userSnapshot.data ?? {};
              if (userData.isEmpty || !userData.containsKey('role')) {
                return const LoginPage();
              }

              /// ✅ Save FCM token after login
              saveDeviceToken(user);

              final role = (userData['role'] ?? '').toString().trim();

              if (role == 'Student') {
                return Navbar(userData: userData, initialIndex: 0);
              } else if (role == 'Counselor' || role == 'Admin') {
                return ProfileAd(userData: userData);
              } else {
                return const LoginPage();
              }
            },
          );
        },
      ),

      /// 🔹 Router
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>? ?? {};

        WidgetBuilder builder;
        switch (settings.name) {
          case "/user_dashboard":
            builder = (context) => UserDashboard(userData: args);
            break;
          case "/home_page":
            builder = (context) => HomePage(userData: args);
            break;
          case "/navbar":
            final initialIndex = args['initialIndex'] as int? ?? 0;
            builder =
                (context) => Navbar(userData: args, initialIndex: initialIndex);
            break;
          case "/appointments_ad":
            builder = (context) => AppointmentsAd(userData: args);
            break;
          case "/login_page":
            builder = (context) => const LoginPage();
            break;
          case "/psychoeducational_ad":
            builder = (context) => PsychoeducAd(userData: args);
            break;
          case "/FormsAd":
            builder = (context) => Formsad(userData: args);
            break;
          case "/ChatbotAd":
            builder = (context) => ChatbotAd(userData: args);
            break;
          case "/ChathistoryAd":
            builder = (context) => ChatHistoryAd(userData: args);
            break;
          case "/Notifications":
            builder = (context) => NotificationsPage(userData: args);
            break;
          case "/MonitorAd":
            builder = (context) => MonitorAd(userData: args);
            break;
          case "/FeedbackAd":
            builder = (context) => FeedbackAd(userData: args);
            break;
          case "/TemplatesAd":
            builder = (context) => TemplatesAd(userData: args);
            break;
          case "/ProfileAd":
            builder = (context) => ProfileAd(userData: args);
            break;
          case "/moodTracker":
            builder = (context) => Moodtracker(userData: args);
            break;
          default:
            builder = (context) => UserDashboard(userData: args);
        }

        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (_, __, ___, child) => child,
        );
      },
    );
  }
}
