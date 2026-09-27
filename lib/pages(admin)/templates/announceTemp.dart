import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// 🟢 Main Dialog — Shows all Announcement Templates (Shared across counselors)
void showAnnounceTemp(BuildContext context, Map<String, dynamic> userData) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Row(
        children: [
          const Icon(Icons.campaign, color: Color(0xFF345F00)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Announcement Templates",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          Tooltip(
            message: "Add new announcement",
            child: IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF345F00)),
              onPressed: () {
                Navigator.pop(context);
                showAddAnnouncementDialog(context, userData);
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
              .where('templateType', isEqualTo: 'Announcement')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "No announcement templates yet.",
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
                final message = data['announcement'] ?? '';
                final status = data['status'] ?? 'Unknown';
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final createdBy = data['createdBy'] ?? 'Unknown';

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF345F00),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(status),
                              labelStyle: TextStyle(
                                color: status == "Active"
                                    ? Colors.white
                                    : Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                              backgroundColor: status == "Active"
                                  ? Colors.green
                                  : Colors.grey.shade300,
                            ),
                          ],
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
                              icon:
                                  const Icon(Icons.edit, color: Colors.blueAccent),
                              tooltip: "Edit",
                              onPressed: () {
                                showEditAnnouncementDialog(
                                    context, userData, doc.id, data);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: "Delete",
                              onPressed: () {
                                showDeleteConfirmation(context, doc.id);
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

/// 🟢 Add New Announcement (Shared - no counId filter)
void showAddAnnouncementDialog(
  BuildContext context,
  Map<String, dynamic> userData,
) {
  final titleController = TextEditingController();
  final announcementController = TextEditingController();
  bool isSaving = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add New Announcement"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Announcement Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: announcementController,
                decoration: const InputDecoration(
                  labelText: "Announcement Message",
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: isSaving ? null : () => Navigator.pop(context),
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
                    final announcement = announcementController.text.trim();

                    if (title.isEmpty || announcement.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Please fill in all fields.")),
                      );
                      return;
                    }

                    setState(() => isSaving = true);
                    try {
                      await FirebaseFirestore.instance.collection('templates').add({
                        'templateType': 'Announcement',
                        'title': title,
                        'announcement': announcement,
                        'status': 'Active',
                        'createdBy': userData['counId'] ?? 'Unknown',
                        'createdByCountId': userData['counId'], // Store for reference only
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        showAnnounceTemp(context, userData);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("✅ Announcement added successfully!")),
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

/// 🟢 Edit Announcement
void showEditAnnouncementDialog(
  BuildContext context,
  Map<String, dynamic> userData,
  String docId,
  Map<String, dynamic> data,
) {
  final titleController = TextEditingController(text: data['title'] ?? '');
  final announcementController =
      TextEditingController(text: data['announcement'] ?? '');
  String status = data['status'] ?? 'Active';
  bool isSaving = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Announcement"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Announcement Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: announcementController,
                decoration: const InputDecoration(
                  labelText: "Announcement Message",
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(
                  labelText: "Status",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "Active", child: Text("Active")),
                  DropdownMenuItem(value: "Inactive", child: Text("Inactive")),
                ],
                onChanged: (val) => setState(() => status = val!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: isSaving ? null : () => Navigator.pop(context),
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
            label: Text(isSaving ? "Updating..." : "Update"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: isSaving
                ? null
                : () async {
                    final title = titleController.text.trim();
                    final announcement = announcementController.text.trim();

                    if (title.isEmpty || announcement.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Please fill in all fields.")),
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
                        'announcement': announcement,
                        'status': status,
                        'lastModifiedBy': userData['coundId'] ?? 'Unknown',
                        'lastModifiedAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        showAnnounceTemp(context, userData);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("✅ Announcement updated.")),
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

/// 🟢 Delete Confirmation (with loading)
void showDeleteConfirmation(BuildContext context, String docId) {
  bool isDeleting = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Announcement"),
        content: const Text(
          "Are you sure you want to delete this announcement template? This action cannot be undone.",
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
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.delete_forever),
            label: Text(isDeleting ? "Deleting..." : "Delete"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
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
                              content: Text("🗑️ Announcement deleted.")),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e")),
                        );
                      }
                    } finally {
                      setState(() => isDeleting = false);
                    }
                  },
          ),
        ],
      ),
    ),
  );
}