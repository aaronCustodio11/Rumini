import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// 🟢 Main Dialog — Shows all Notification Templates (Shared across counselors)
void showNotifTemp(BuildContext context, Map<String, dynamic> userData) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Row(
        children: [
          const Icon(Icons.notifications_active, color: Color(0xFF345F00)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Notification Templates",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          Tooltip(
            message: "Add new notification",
            child: IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF345F00)),
              onPressed: () {
                Navigator.pop(context);
                showAddNotifDialog(context, userData);
              },
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 420,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('templates')
              .where('templateType', isEqualTo: 'Notification')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "No notification templates yet.",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final docs = snapshot.data!.docs;
            final dateFormat = DateFormat('MMMM d, y – h:mm a');

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final title = data['title'] ?? 'Untitled';
                final message = data['message'] ?? '';
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final createdBy = data['createdBy'] ?? 'Unknown';

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF345F00),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (createdAt != null)
                              Expanded(
                                child: Text(
                                  "Created: ${dateFormat.format(createdAt)}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            Text(
                              "By: $createdBy",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: "Edit",
                              onPressed: () {
                                showEditNotifDialog(context, userData, doc.id, data);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: "Delete",
                              onPressed: () {
                                _confirmDeleteNotif(context, doc.id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.grey),
          label: const Text("Close"),
        ),
      ],
    ),
  );
}

/// 🟢 Add Notification Template (Shared - no counId filter)
void showAddNotifDialog(BuildContext context, Map<String, dynamic> userData) {
  final titleController = TextEditingController();
  final messageController = TextEditingController();
  bool isSaving = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add New Notification"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Notification Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: "Notification Message",
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.cancel, color: Colors.grey),
            label: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(isSaving ? "Saving..." : "Save"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF345F00),
              foregroundColor: Colors.white,
            ),
            onPressed: isSaving
                ? null
                : () async {
                    final title = titleController.text.trim();
                    final message = messageController.text.trim();

                    if (title.isEmpty || message.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please fill in all fields."),
                        ),
                      );
                      return;
                    }

                    setState(() => isSaving = true);
                    try {
                      await FirebaseFirestore.instance.collection('templates').add({
                        'templateType': 'Notification',
                        'title': title,
                        'message': message,
                        'createdBy': userData['counId'] ?? 'Unknown',
                        'createdByCountId': userData['counId'], // Store for reference only
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        showNotifTemp(context, userData);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("✅ Notification added successfully!"),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    } finally {
                      setState(() => isSaving = false);
                    }
                  },
          ),
        ],
      ),
    ),
  );
}

/// 🟢 Edit Notification Template
void showEditNotifDialog(
  BuildContext context,
  Map<String, dynamic> userData,
  String docId,
  Map<String, dynamic> data,
) {
  final titleController = TextEditingController(text: data['title']);
  final messageController = TextEditingController(text: data['message']);
  bool isSaving = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Notification"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Notification Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: "Notification Message",
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.cancel, color: Colors.grey),
            label: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(isSaving ? "Saving..." : "Save Changes"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF345F00),
              foregroundColor: Colors.white,
            ),
            onPressed: isSaving
                ? null
                : () async {
                    final title = titleController.text.trim();
                    final message = messageController.text.trim();

                    if (title.isEmpty || message.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please fill in all fields."),
                        ),
                      );
                      return;
                    }

                    setState(() => isSaving = true);
                    try {
                      await FirebaseFirestore.instance
                          .collection('templates')
                          .doc(docId)
                          .update({
                        'title': title,
                        'message': message,
                        'lastModifiedBy': userData['counId'] ?? 'Unknown',
                        'lastModifiedAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        showNotifTemp(context, userData);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ Notification updated successfully!"),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    } finally {
                      setState(() => isSaving = false);
                    }
                  },
          ),
        ],
      ),
    ),
  );
}

/// 🟢 Delete Confirmation (with loading state)
void _confirmDeleteNotif(BuildContext context, String docId) {
  bool isDeleting = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Confirm Deletion"),
        content: const Text(
          "Are you sure you want to delete this notification template?",
        ),
        actions: [
          TextButton.icon(
            onPressed: isDeleting ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.cancel, color: Colors.grey),
            label: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: isDeleting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete),
            label: Text(isDeleting ? "Deleting..." : "Delete"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: isDeleting
                ? null
                : () async {
                    setState(() => isDeleting = true);
                    try {
                      await FirebaseFirestore.instance
                          .collection('templates')
                          .doc(docId)
                          .delete();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("🗑️ Template deleted successfully."),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error deleting: $e")),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setState(() => isDeleting = false);
                      }
                    }
                  },
          ),
        ],
      ),
    ),
  );
}