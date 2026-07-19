import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String extensionName;
  final String studId;
  final String college;
  final String course;
  final String section;
  final String assignedCounselor;
  final DateTime date;
  final String time;
  final String concern;
  late final String status; // Added status field
  final DateTime createdAt;
  late String academicYear; // Added academicYear field
  late String? counId; // Added counselorId field

  AppointmentModel({
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.extensionName,
    required this.studId,
    required this.college,
    required this.course,
    required this.section,
    required this.assignedCounselor,
    required this.date,
    required this.time,
    required this.concern,
    this.status = 'pending', // Default status set to 'pending'
    required this.createdAt,
    required this.academicYear,
    required this.counId,
  });

  /// Converts Firestore document snapshot into an Appointment object
  factory AppointmentModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      [SnapshotOptions? options]) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("Document snapshot is null");
    }

    return AppointmentModel(
      id: snapshot.id,
      firstName: data['firstName'] ?? 'No First Name',
      middleName: data['middleName'] ?? 'No Middle Name',
      lastName: data['lastName'] ?? 'No Last Name',
      extensionName: data['extensionName'] ?? 'No Extension Name',
      studId: data['studId'] ?? 'No Student ID',
      college: data['college'] ?? 'No College',
      course: data['course'] ?? 'No Course',
      section: data['section'] ?? 'No Section',
      assignedCounselor: data['assignedCounselor'] ?? 'No Counselor',
      date:
          (data['date'] is Timestamp) ? data['date'].toDate() : DateTime.now(),
      time: data['time'] ?? 'No Time',
      concern: data['concern'] is List
          ? (data['concern'] as List).join(", ") // Converts a list to a string
          : data['concern'] ?? '',

      status: data['status'] ?? 'Pending', // Retrieve status from Firestore
      createdAt: (data['createdAt'] is Timestamp)
          ? data['createdAt'].toDate()
          : DateTime.now(),
      academicYear: data['academicYear'] ?? 'No Academic Year',
      counId: data['counId'] ?? 'No Counselor ID',
    );
  }

  /// Converts Appointment object into a Firestore-compatible map
  Map<String, Object?> toFirestore() {
    return {
      "firstName": firstName,
      "middleName": middleName,
      "lastName": lastName,
      "extensionName": extensionName,
      "studId": studId,
      "college": college,
      "course": course,
      "section": section,
      "assignedCounselor": assignedCounselor,
      "date": Timestamp.fromDate(date),
      "time": time,
      "concern": concern,
      "status": status, // Include status when saving to Firestore
      "createdAt": Timestamp.fromDate(createdAt),
      "academicYear": academicYear,
      "counId": counId,
    };
  }
}
