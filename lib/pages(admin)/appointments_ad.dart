import 'package:rumini/helper/helper_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rumini/components/alertapointments.dart';
import 'package:rumini/components/sidebar.dart';
import 'package:rumini/model/appointment_model.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Import for StreamSubscription

class AppointmentsAd extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AppointmentsAd({super.key, required this.userData});

  @override
  State<AppointmentsAd> createState() => _AppointmentsAdState();
}

class _AppointmentsAdState extends State<AppointmentsAd> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  List<AppointmentModel> _selectedAppointments = [];
  List<AppointmentModel> _pendingAppointments = [];
  Map<DateTime, List<AppointmentModel>> _appointmentsByDay = {};

  // Set to track selected appointment IDs for bulk actions
  Set<String> _checkedAppointmentIds = {};
  Set<String> _checkedPendingAppointmentIds =
      {}; // New set for pending appointments

  // Status options for the dropdowns
  final List<String> _statusOptions = ['accepted', 'completed', 'missed','reschedule'];
  final List<String> _pendingStatusOptions = [
    'pending',
    'accepted',
    'denied',
    'reschedule'
  ]; // Options for pending appointments

  // Stream subscription for real-time updates
  late StreamSubscription<QuerySnapshot> _appointmentsSubscription;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _setupAppointmentsListener();
  }

  @override
  void dispose() {
    // Cancel subscription when widget is disposed
    _appointmentsSubscription.cancel();
    super.dispose();
  }

 void _setupAppointmentsListener() {
  try {
    // Base query for appointments
    Query query = FirebaseFirestore.instance.collection('appointments');

    // Check if user is a Counselor and filter accordingly
    if (widget.userData['role'].toString().toLowerCase() == 'counselor') {
      // Filter appointments for the specific counselor
      String counselorId = widget.userData['counId'] ?? '';
      
      // Validate counselor ID exists
      if (counselorId.isEmpty) {
        _showError('Counselor ID not found. Please contact support.');
        return;
      }
      
      query = query.where('counId', isEqualTo: counselorId);
    }

    // Listen to appointments collection in real-time with the appropriate query
    _appointmentsSubscription = query.snapshots().listen(
      (snapshot) {
        try {
          // Cast the snapshot to the correct type
          _processAppointmentsSnapshot(
            snapshot as QuerySnapshot<Map<String, dynamic>>,
          );
        } catch (e) {
          _showError('Error processing appointments: ${e.toString()}');
        }
      },
      onError: (error) {
        // Handle stream errors (network issues, permission denied, etc.)
        String errorMessage = 'Failed to load appointments.';
        
        if (error.toString().contains('permission-denied')) {
          errorMessage = 'You don\'t have permission to view appointments.';
        } else if (error.toString().contains('unavailable')) {
          errorMessage = 'Network error. Please check your connection.';
        }
        
        _showError(errorMessage);
        
        // Optionally: Set empty state
        if (mounted) {
          setState(() {
            _appointmentsByDay = {};
            _pendingAppointments = [];
            _selectedAppointments = [];
          });
        }
      },
      cancelOnError: false, // Keep listening even after errors
    );
  } catch (e) {
    _showError('Failed to setup appointments listener: ${e.toString()}');
  }
}

  void _processAppointmentsSnapshot(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  Map<DateTime, List<AppointmentModel>> tempMap = {};
  List<AppointmentModel> pendingList = [];

  for (var doc in snapshot.docs) {
    AppointmentModel appointment = AppointmentModel.fromFirestore(doc);
    DateTime eventDate = DateTime(
      appointment.date.year,
      appointment.date.month,
      appointment.date.day,
    );

    if (!tempMap.containsKey(eventDate)) {
      tempMap[eventDate] = [];
    }

    // Automatically mark appointments as missed if past date and still accepted
    if (appointment.date.isBefore(DateTime.now()) &&
        appointment.status.toLowerCase() == 'accepted') {
      // Use a separate function to update status to missed
      _markAppointmentAsMissed(appointment);
      continue; // Skip this appointment as it will be updated in next snapshot
    }

    // Only "pending" goes to pending list, everything else goes to calendar
    // This includes: accepted, completed, missed, reschedule, etc.
    if (appointment.status.toLowerCase() != 'pending') {
      tempMap[eventDate]!.add(appointment); // ✅ Reschedule will appear here
    } else if (appointment.status.toLowerCase() == 'pending') {
      pendingList.add(appointment);
    }
  }

  // FCFS sorting of pending appointments by createdAt (earliest first)
  pendingList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

  setState(() {
    _appointmentsByDay = tempMap;
    _pendingAppointments = pendingList;

    // Update selected appointments if a day is already selected
    if (_selectedDay != null) {
      DateTime eventDate = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
      );
      _selectedAppointments = _appointmentsByDay[eventDate] ?? [];
    }
  });
}

  void _fetchAppointmentsForDay(DateTime date) {
    DateTime eventDate = DateTime(date.year, date.month, date.day);
    setState(() {
      _selectedAppointments = _appointmentsByDay[eventDate] ?? [];
      // Clear checked appointments when changing day
      _checkedAppointmentIds.clear();
    });
  }

  int _countAppointmentsByStatus(String status) {
    int count = 0;

    _appointmentsByDay.forEach((date, appointmentsList) {
      count += appointmentsList
          .where(
            (appointment) =>
                appointment.status.toLowerCase() == status.toLowerCase(),
          )
          .length;
    });

    return count;
  }

  // Helper method to mark an appointment as missed
void _markAppointmentAsMissed(AppointmentModel appointment) async {
  try {
    await FirebaseFirestore.instance
        .collection("appointments")
        .doc(appointment.id)
        .update({"status": "missed"});
    // No need to refresh - the listener will catch this update
  } catch (e) {
    if (mounted) {
      _showError('Failed to mark appointment as missed: ${e.toString()}');
    }
  }
}

void _updateAppointmentStatus(String appointmentId, String newStatus) async {
  try {
    // If denying, just delete immediately without updating status
    if (newStatus == 'denied') {
      _deleteAppointment(appointmentId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Appointment denied and removed'),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: Duration(seconds: 3),
          ),
        );
      }
      return; // Exit early after deletion
    }
    
    // For all other statuses (accepted, completed, missed, reschedule), update normally
    await FirebaseFirestore.instance
        .collection("appointments")
        .doc(appointmentId)
        .update({
      "status": newStatus,
    });
    
    // Show specific feedback for reschedule status
    if (newStatus == 'reschedule' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.schedule, color: Colors.white),
              SizedBox(width: 8),
              Text('Appointment marked for rescheduling'),
            ],
          ),
          backgroundColor: Colors.purple[700],
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    // No need to refresh - the listener will handle it
  } catch (e) {
    if (mounted) {
      _showError('Failed to update appointment status: ${e.toString()}');
    }
  }
}
// Update multiple appointments at once
void _bulkUpdateSelectedAppointments(String newStatus) async {
  if (_checkedAppointmentIds.isEmpty) {
    // Show message if no appointments are selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Text('No appointments selected'),
          ],
        ),
        backgroundColor: Colors.orange[700],
      ),
    );
    return;
  }

  // Store count before clearing
  final int updateCount = _checkedAppointmentIds.length;

  try {
    // Update all selected appointments
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (String id in _checkedAppointmentIds) {
      DocumentReference docRef =
          FirebaseFirestore.instance.collection("appointments").doc(id);
      batch.update(docRef, {"status": newStatus});
    }

    await batch.commit();

    // Clear selections - no need to refresh manually
    if (mounted) {
      setState(() {
        _checkedAppointmentIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$updateCount appointment${updateCount > 1 ? 's' : ''} updated to $newStatus',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      _showError('Failed to update appointments: ${e.toString()}');
      // Don't clear selections on error so user can retry
    }
  }
}

// Bulk update for pending appointments
void _bulkUpdatePendingAppointments(String newStatus) async {
  if (_checkedPendingAppointmentIds.isEmpty) {
    // Show message if no appointments are selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Text('No appointments selected'),
          ],
        ),
        backgroundColor: Colors.orange[700],
      ),
    );
    return;
  }

  // Store count before clearing
  final int updateCount = _checkedPendingAppointmentIds.length;

  try {
    // If denying, just delete immediately without updating status
    if (newStatus == 'denied') {
      WriteBatch deleteBatch = FirebaseFirestore.instance.batch();
      for (String id in _checkedPendingAppointmentIds) {
        DocumentReference docRef =
            FirebaseFirestore.instance.collection("appointments").doc(id);
        deleteBatch.delete(docRef);
      }
      await deleteBatch.commit();

      // Clear selections after successful deletion
      if (mounted) {
        setState(() {
          _checkedPendingAppointmentIds.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$updateCount appointment${updateCount > 1 ? 's' : ''} denied and removed',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: Duration(seconds: 3),
          ),
        );
      }
      return; // Exit early after deletion
    }

    // For all other statuses (pending, accepted, reschedule), update normally
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (String id in _checkedPendingAppointmentIds) {
      DocumentReference docRef =
          FirebaseFirestore.instance.collection("appointments").doc(id);
      batch.update(docRef, {"status": newStatus});
    }

    await batch.commit();

    // Clear selections - no need to refresh manually
    if (mounted) {
      setState(() {
        _checkedPendingAppointmentIds.clear();
      });

      // Customize message and color based on status
      String message;
      Color backgroundColor;
      IconData icon;

      if (newStatus == 'reschedule') {
        message = '$updateCount appointment${updateCount > 1 ? 's' : ''} marked for rescheduling';
        backgroundColor = Colors.purple[700]!;
        icon = Icons.schedule;
      } else {
        message = '$updateCount appointment${updateCount > 1 ? 's' : ''} updated to $newStatus';
        backgroundColor = Colors.green[700]!;
        icon = Icons.check_circle;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(message),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      _showError('Failed to update pending appointments: ${e.toString()}');
      // Don't clear selections on error so user can retry
    }
  }
}

void _deleteAppointment(String appointmentId) async {
  try {
    await FirebaseFirestore.instance
        .collection("appointments")
        .doc(appointmentId)
        .delete();
    // No need to refresh - the listener will handle it
  } catch (e) {
    if (mounted) {
      _showError('Failed to delete appointment: ${e.toString()}');
    }
    // Rethrow so calling function knows deletion failed
    rethrow;
  }
}

// Helper method to show errors consistently
void _showError(String message) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red[700],
      duration: Duration(seconds: 5),
      action: SnackBarAction(
        label: 'DISMISS',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ),
  );
}

  void _refreshAppointments() {
    setState(() {
      _checkedAppointmentIds.clear();
      _checkedPendingAppointmentIds.clear();
    });
    // The real-time listener is already handling updates
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color.fromARGB(
          255,
          232,
          232,
          232,
        ), // Background color for the page
        child: Row(
          children: [
            Sidebar(userData: widget.userData),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: const Color.fromARGB(255, 232, 232, 232),
                    title: const Row(
                      children: [
                        Icon(Icons.event, color: Color(0xFF345F00)),
                        SizedBox(width: 8),
                        Text("Appointments"),
                      ],
                    ),
                    titleTextStyle: const TextStyle(
                      color: Color(0xFF345F00),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: 20.0,
                        left: 40.0,
                        right: 40.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          /// Appointment Status Summary Section (No changes - remains at top)
                          Card(
  elevation: 4,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we should stack vertically based on screen width
        bool isNarrowScreen = constraints.maxWidth < 900;

        return isNarrowScreen
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// Status Cards Area (Full Width on Small Screens)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildResponsiveStatusCard(
                          Icons.access_time,
                          "Pending",
                          _pendingAppointments.length,
                          Colors.orange,
                          constraints.maxWidth,
                        ),
                        SizedBox(width: 12),
                        _buildResponsiveStatusCard(
                          Icons.check_circle,
                          "Accepted",
                          _countAppointmentsByStatus('accepted'),
                          Colors.green,
                          constraints.maxWidth,
                        ),
                        SizedBox(width: 12),
                        _buildResponsiveStatusCard(
                          Icons.done_all,
                          "Completed",
                          _countAppointmentsByStatus('completed'),
                          Colors.blue,
                          constraints.maxWidth,
                        ),
                        SizedBox(width: 12),
                        _buildResponsiveStatusCard(
                          Icons.event_busy,
                          "Missed",
                          _countAppointmentsByStatus('missed'),
                          Colors.yellow[700]!,
                          constraints.maxWidth,
                        ),
                        SizedBox(width: 12),
                        _buildResponsiveStatusCard(
                          Icons.update,
                          "Reschedule",
                          _countAppointmentsByStatus('reschedule'),
                          Colors.purple,
                          constraints.maxWidth,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  /// Buttons Row (Below Cards on Small Screens)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      /// Green Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  AddOrUpdateAppointmentDialog(
                                userData: widget.userData,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Add",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(width: 12),

                      /// Yellow Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _refreshAppointments();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellow[700],
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, color: Colors.black),
                              SizedBox(width: 8),
                              Text(
                                "Refresh",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Status Cards Area (Side by Side on Large Screens)
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildResponsiveStatusCard(
                            Icons.access_time,
                            "Pending",
                            _pendingAppointments.length,
                            Colors.orange,
                            constraints.maxWidth,
                          ),
                          SizedBox(width: 12),
                          _buildResponsiveStatusCard(
                            Icons.check_circle,
                            "Accepted",
                            _countAppointmentsByStatus('accepted'),
                            Colors.green,
                            constraints.maxWidth,
                          ),
                          SizedBox(width: 12),
                          _buildResponsiveStatusCard(
                            Icons.done_all,
                            "Completed",
                            _countAppointmentsByStatus('completed'),
                            Colors.blue,
                            constraints.maxWidth,
                          ),
                          SizedBox(width: 12),
                          _buildResponsiveStatusCard(
                            Icons.event_busy,
                            "Missed",
                            _countAppointmentsByStatus('missed'),
                            Colors.yellow[700]!,
                            constraints.maxWidth,
                          ),
                          SizedBox(width: 12),
                          _buildResponsiveStatusCard(
                            Icons.update,
                            "Reschedule",
                            _countAppointmentsByStatus('reschedule'),
                            Colors.purple,
                            constraints.maxWidth,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 5),

                  /// Buttons Column (Side by Side on Large Screens)
                  Column(
                    children: [
                      /// Green Button
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                AddOrUpdateAppointmentDialog(
                              userData: widget.userData,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                            horizontal: 37,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Add",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 12),

                      /// Yellow Button
                      ElevatedButton(
                        onPressed: () {
                          _refreshAppointments();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow[700],
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, color: Colors.black),
                            SizedBox(width: 8),
                            Text(
                              "Refresh",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
      },
    ),
  ),
),

                          SizedBox(height: 16),

                          /// Row containing Selected Day's Appointments (left) and Calendar (right)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// Selected Day's Appointments Section (Left Side)
                              Expanded(
                                flex: 3,
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20.0,
                                      horizontal: 30.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        /// Row for Selected Day's Appointments with Select All checkbox (label on top)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Title at the top left
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10.0,
                                                    horizontal: 1.0,
                                                  ),
                                              child: Text(
                                                "Selected Day's Appointments",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),

                                            // Bulk update dropdown with Select All checkbox
                                            if (_selectedAppointments
                                                .isNotEmpty)
                                              Row(
                                                children: [
                                                  // Select All checkbox with label on top
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        "Select All",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      SizedBox(height: 2),
                                                      Checkbox(
                                                        value:
                                                            _selectedAppointments
                                                                    .length ==
                                                                _checkedAppointmentIds
                                                                    .length &&
                                                            _selectedAppointments
                                                                .isNotEmpty,
                                                        onChanged: (bool? value) {
                                                          setState(() {
                                                            if (value == true) {
                                                              // Select all appointments
                                                              _checkedAppointmentIds =
                                                                  _selectedAppointments
                                                                      .map(
                                                                        (
                                                                          app,
                                                                        ) => app
                                                                            .id,
                                                                      )
                                                                      .toSet();
                                                            } else {
                                                              // Deselect all
                                                              _checkedAppointmentIds
                                                                  .clear();
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(width: 16),

                                                  // Update dropdown
                                                  SizedBox(width: 8),
                                                  DropdownButton<String>(
                                                    value: null,
                                                    hint: Text(
                                                      "Update Selected",
                                                    ),
                                                    items: _statusOptions.map((
                                                      String value,
                                                    ) {
                                                      return DropdownMenuItem<
                                                        String
                                                      >(
                                                        value: value,
                                                        child: Text(
                                                          value.capitalize(),
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (newValue) {
                                                      if (newValue != null) {
                                                        _bulkUpdateSelectedAppointments(
                                                          newValue,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),

                                        Container(
                                          decoration: BoxDecoration(
                                            color: Color(0xFF81BF36),
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: 15,
                                            horizontal: 12,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  "Full Name",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  "Counselor",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  "Concern",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  "Time",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  "Status",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  "Select",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Fixed height container for exactly 5 rows
                                        Container(
                                          height:
                                              750, // Fixed height for 5 rows (~50px per row)
                                          child:
                                              _selectedAppointments.isNotEmpty
                                              ? ListView.builder(
                                                  itemCount:
                                                      _selectedAppointments
                                                          .length,
                                                  itemBuilder: (context, index) {
                                                    final appointment =
                                                        _selectedAppointments[index];
                                                    return Container(
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                            vertical: 4,
                                                            horizontal: 4,
                                                          ),
                                                      padding: EdgeInsets.all(
                                                        8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: index.isEven
                                                            ? Colors.white
                                                            : Colors.grey[200],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child:
                                                          _buildSelectedAppointmentRow(
                                                            appointment,
                                                          ),
                                                    );
                                                  },
                                                )
                                              : Center(
                                                  child: Text(
                                                    "No appointments for this day",
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(width: 16),

                              /// Table Calendar Section (Right Side)
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: TableCalendar(
                                          firstDay: DateTime.utc(2000, 1, 1),
                                          lastDay: DateTime.utc(2100, 12, 31),
                                          focusedDay: _focusedDay,
                                          selectedDayPredicate: (day) {
                                            return isSameDay(_selectedDay, day);
                                          },
                                          onDaySelected:
                                              (selectedDay, focusedDay) {
                                                setState(() {
                                                  _selectedDay = selectedDay;
                                                  _focusedDay = focusedDay;
                                                });
                                                _fetchAppointmentsForDay(
                                                  selectedDay,
                                                );
                                              },
                                          enabledDayPredicate: (day) {
                                            // Disable Sundays
                                            return day.weekday !=
                                                DateTime.sunday;
                                          },
                                          calendarStyle: CalendarStyle(
                                            todayDecoration: BoxDecoration(
                                              color: Colors.orange,
                                              shape: BoxShape.circle,
                                            ),
                                            selectedDecoration: BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          headerStyle: HeaderStyle(
                                            formatButtonVisible: false,
                                            titleCentered: true,
                                          ),
                                          calendarBuilders: CalendarBuilders(
                                            markerBuilder: (context, date, events) {
                                              DateTime eventDate = DateTime(
                                                date.year,
                                                date.month,
                                                date.day,
                                              );
                                              if (!_appointmentsByDay
                                                  .containsKey(eventDate))
                                                return SizedBox();

                                              int eventCount =
                                                  _appointmentsByDay[eventDate]!
                                                      .length;
                                              int dotCount = eventCount > 3
                                                  ? 3
                                                  : eventCount;

                                              return Positioned(
                                                bottom: 5,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: List.generate(
                                                    dotCount,
                                                    (index) {
                                                      return Container(
                                                        margin:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 2,
                                                            ),
                                                        width: 6,
                                                        height: 6,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Colors.red,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 16),

                                    /// Requested Appointments Section (Below Calendar)
                                    Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20.0,
                                          horizontal: 30.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            /// Row for Requested Appointments with Select All checkbox (label on top)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                // Title at the top left
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10.0,
                                                        horizontal: 1.0,
                                                      ),
                                                  child: Text(
                                                    "Requested Appointments",
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),

                                                // Bulk update dropdown at top right with Select All checkbox
                                                if (_pendingAppointments
                                                    .isNotEmpty)
                                                  Row(
                                                    children: [
                                                      // Select All checkbox with label on top
                                                      Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "Select All",
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          SizedBox(height: 2),
                                                          Checkbox(
                                                            value:
                                                                _pendingAppointments
                                                                        .length ==
                                                                    _checkedPendingAppointmentIds
                                                                        .length &&
                                                                _pendingAppointments
                                                                    .isNotEmpty,
                                                            onChanged: (bool? value) {
                                                              setState(() {
                                                                if (value ==
                                                                    true) {
                                                                  // Select all pending appointments
                                                                  _checkedPendingAppointmentIds = _pendingAppointments
                                                                      .map(
                                                                        (
                                                                          app,
                                                                        ) => app
                                                                            .id,
                                                                      )
                                                                      .toSet();
                                                                } else {
                                                                  // Deselect all
                                                                  _checkedPendingAppointmentIds
                                                                      .clear();
                                                                }
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(width: 16),

                                                      // Update dropdown
                                                      SizedBox(width: 8),
                                                      DropdownButton<String>(
                                                        value: null,
                                                        hint: Text(
                                                          "Update Selected",
                                                        ),
                                                        items: _pendingStatusOptions.map((
                                                          String value,
                                                        ) {
                                                          return DropdownMenuItem<
                                                            String
                                                          >(
                                                            value: value,
                                                            child: Text(
                                                              value
                                                                  .capitalize(),
                                                            ),
                                                          );
                                                        }).toList(),
                                                        onChanged: (newValue) {
                                                          if (newValue !=
                                                              null) {
                                                            _bulkUpdatePendingAppointments(
                                                              newValue,
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),

                                            // Green header row
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFF81BF36,
                                                ), // Green background
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: 15,
                                                horizontal: 12,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      "Full Name",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      "Date",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      "Time",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      "Status",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      "Select",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Fixed height container for pending appointments
                                            Container(
                                              height:
                                                  370, // Fixed height for 5 rows (~50px per row)
                                              child:
                                                  _pendingAppointments
                                                      .isNotEmpty
                                                  ? ListView.builder(
                                                      itemCount:
                                                          _pendingAppointments
                                                              .length,
                                                      itemBuilder: (context, index) {
                                                        final appointment =
                                                            _pendingAppointments[index];
                                                        return Container(
                                                          margin:
                                                              EdgeInsets.symmetric(
                                                                vertical: 4,
                                                                horizontal: 4,
                                                              ),
                                                          padding:
                                                              EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: index.isEven
                                                                ? Colors.white
                                                                : Colors
                                                                      .grey[200], // Alternating colors
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ), // Rounded corners
                                                          ),
                                                          child:
                                                              _buildPendingAppointmentRow(
                                                                appointment,
                                                              ),
                                                        );
                                                      },
                                                    )
                                                  : Center(
                                                      child: Text(
                                                        "No pending appointments",
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveStatusCard(
  IconData icon,
  String label,
  int count,
  Color color,
  double parentWidth,
) {
  // Calculate responsive dimensions based on parent width
  double cardWidth;
  double iconSize;
  double countFontSize;
  double labelFontSize;
  double iconPadding;

  if (parentWidth < 600) {
    // Mobile
    cardWidth = 140;
    iconSize = 24;
    countFontSize = 20;
    labelFontSize = 12;
    iconPadding = 8;
  } else if (parentWidth < 900) {
    // Tablet
    cardWidth = 160;
    iconSize = 28;
    countFontSize = 22;
    labelFontSize = 13;
    iconPadding = 10;
  } else if (parentWidth < 1200) {
    // Small Desktop
    cardWidth = 170;
    iconSize = 30;
    countFontSize = 24;
    labelFontSize = 14;
    iconPadding = 12;
  } else {
    // Large Desktop
    cardWidth = 180;
    iconSize = 32;
    countFontSize = 26;
    labelFontSize = 14;
    iconPadding = 12;
  }

  return Container(
    width: cardWidth,
    padding: EdgeInsets.all(parentWidth < 600 ? 12 : 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.3),
          spreadRadius: 2,
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        /// Icon
        Container(
          padding: EdgeInsets.all(iconPadding),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: iconSize),
        ),

        SizedBox(width: parentWidth < 600 ? 8 : 12),

        /// Number and Label
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: countFontSize,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: labelFontSize,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  /// Updated helper widget for a pending appointment row with dropdown and checkbox
  Widget _buildPendingAppointmentRow(AppointmentModel appointment) {
    return InkWell(
      onTap: () => showAppointmentDetails(context, appointment),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Row(
          children: [
            // Name
            Expanded(
              flex: 3,
              child: Text(
                '${appointment.firstName} ${appointment.middleName} ${appointment.lastName} ${appointment.extensionName}',
              ),
            ),

            // Date
            Expanded(
              flex: 2,
              child: Text(DateFormat('MMMM d, y').format(appointment.date)),
            ),

            // Time
            Expanded(flex: 2, child: Text(appointment.time)),

            // Status dropdown with reduced font size
            Expanded(
              flex: 2,
              child: DropdownButton<String>(
                value: appointment.status.toLowerCase(),
                isExpanded: true,
                itemHeight: 48, // Slightly reduced to accommodate smaller text
                style: TextStyle(
                  fontSize: 12, // Reduced font size for dropdown button text
                  color: Colors.black,
                ),
                items: _pendingStatusOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value.capitalize(),
                      style: TextStyle(
                        fontSize: 14, // Reduced font size for dropdown items
                        fontWeight: FontWeight.normal,
                        color: _getStatusColor(
                          value,
                        ), // Assuming you have this helper function
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    _updateAppointmentStatus(appointment.id, newValue);
                  }
                },
              ),
            ),

            // Checkbox for selecting pending appointments
            Expanded(
              flex: 1,
              child: Checkbox(
                value: _checkedPendingAppointmentIds.contains(appointment.id),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _checkedPendingAppointmentIds.add(appointment.id);
                    } else {
                      _checkedPendingAppointmentIds.remove(appointment.id);
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedAppointmentRow(AppointmentModel appointment) {
    return InkWell(
      onTap: () => showAppointmentDetails(context, appointment),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Row(
          children: [
            // Name
            Expanded(
              flex: 3,
              child: Text(
                '${appointment.firstName} ${appointment.middleName} ${appointment.lastName} ${appointment.extensionName}',
              ),
            ),

            // Counselor
            Expanded(flex: 2, child: Text(appointment.assignedCounselor)),

            // Concern
            Expanded(flex: 2, child: Text(appointment.concern)),

            // Time
            Expanded(flex: 2, child: Text(appointment.time)),

            // Status dropdown with reduced font size
            Expanded(
              flex: 2,
              child: DropdownButton<String>(
                value: appointment.status.toLowerCase(),
                isExpanded: true,
                itemHeight: 48, // Slightly reduced to accommodate smaller text
                style: TextStyle(
                  fontSize: 12, // Reduced font size for dropdown button text
                  color: Colors.black,
                ),
                items: _statusOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value.capitalize(),
                      style: TextStyle(
                        fontSize: 14, // Reduced font size for dropdown items
                        fontWeight: FontWeight.normal,
                        color: _getStatusColor(
                          value,
                        ), // Assuming you have this helper function
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    _updateAppointmentStatus(appointment.id, newValue);
                  }
                },
              ),
            ),

            // Checkbox for selecting appointments
            Expanded(
              flex: 1,
              child: Checkbox(
                value: _checkedAppointmentIds.contains(appointment.id),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _checkedAppointmentIds.add(appointment.id);
                    } else {
                      _checkedAppointmentIds.remove(appointment.id);
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange;
    case 'accepted':
      return Colors.green;
    case 'completed':
      return Colors.blue;
    case 'missed':
      return Colors.yellow[700]!;
    case 'cancelled':
      return Colors.red;
      case 'reschedule':
      return Colors.purpleAccent;
    default:
      return Colors.black;
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
