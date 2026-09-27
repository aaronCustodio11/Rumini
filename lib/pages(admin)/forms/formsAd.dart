import 'package:rumini/components/sidebar.dart';
import 'package:rumini/pages(admin)/forms/formsCreate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Formsad extends StatefulWidget {
  final Map<String, dynamic> userData;
  const Formsad({super.key, required this.userData});

  @override
  State<Formsad> createState() => _FormsadState();
}

class _FormsadState extends State<Formsad> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 232, 232, 232),
    body: Row(
      children: [
        Sidebar(userData: widget.userData),
        Expanded(
          child: Column(
            children: [
             AppBar(
              iconTheme: IconThemeData(color: const Color(0xFF1B5E20)), // Icon color
              title: const Row(
                children: [
                  Icon(Icons.description_outlined), // Form-related icon
                  SizedBox(width: 8),
                  Text(
                    "Forms Page",
                    style: TextStyle(
                      color:  Color(0xFF1B5E20), // You can use Colors.green[900] if not const
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color.fromARGB(255, 232, 232, 232),
              elevation: 2, // Optional: Slight shadow
            ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 100.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 🔘 Add Form Button (top-right)
                      /// 🔍 Search + ➕ Add Form Card
                      /// 🔍 Search Bar + ➕ Add Form in a Card (Side by Side with Smaller Search)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              /// 🔍 Search Bar (Smaller Width)
                              SizedBox(
                                width: 300, // Adjust width as needed
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    hintText: 'Search forms...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value.toLowerCase().trim();
                                    });
                                  },
                                ),
                              ),

                              /// ➕ Add Form Button
                              ElevatedButton.icon(
                                onPressed: () {
                                  String formId = const Uuid().v4();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          Formscreate(currentformId: formId,userData: widget.userData),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text(
                                  "Add Form",
                                  style: TextStyle(
                                    color: Colors.white,       // Text color
                                    fontWeight: FontWeight.bold, // Bold font
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[800],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// 📋 Forms List
                      Expanded(
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('forms')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return const Center(child: Text("No forms found."));
                              }

                              final forms = snapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final title =
                                    (data['title'] ?? '').toString().toLowerCase();
                                final description = (data['description'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                return title.contains(_searchQuery) ||
                                    description.contains(_searchQuery);
                              }).toList();

                              if (forms.isEmpty) {
                                return const Center(
                                    child: Text("No matching forms found."));
                              }

                              return ListView.builder(
                                itemCount: forms.length,
                                itemBuilder: (context, index) {
                                  final form = forms[index];
                                  final data = form.data() as Map<String, dynamic>;

                                  final formId = data['formId'] ?? 'Unknown ID';
                                  final title = data['title'] ?? 'Untitled Form';

                                  // Updated Time Text
                                  String displayDate = 'No Date';
                                  if (data['timestamp'] != null &&
                                      data['timestamp'] is Timestamp) {
                                    final timestamp =
                                        data['timestamp'] as Timestamp;
                                    final updatedDate = timestamp
                                        .toDate()
                                        .add(const Duration(hours: 8));
                                    final now = DateTime.now()
                                        .add(const Duration(hours: 8));
                                    final difference = now.difference(updatedDate);

                                    if (difference.inDays >= 1) {
                                      displayDate =
                                      "Updated ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago";
                                    } else if (difference.inHours >= 1) {
                                      displayDate =
                                      "Updated ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago";
                                    } else if (difference.inMinutes >= 1) {
                                      displayDate =
                                      "Updated ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago";
                                    } else {
                                      displayDate = "Just now";
                                    }
                                  }

                                  return ListTile(
                                    leading: const Icon(Icons.description_outlined),
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayDate,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (data['status'] != null)
                                          Text(
                                            'Status: ${data['status'].toString().toUpperCase()}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: data['status']
                                                  .toString()
                                                  .toLowerCase() ==
                                                  'open'
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                    
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          tooltip: 'Edit Form',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => Formscreate(
                                                  currentformId: formId,userData: widget.userData,),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          tooltip: 'Delete Form',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text("Confirm Delete"),
                                                content: const Text(
                                                    "Are you sure you want to delete this form?"),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx, false),
                                                    child: const Text("Cancel"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx, true),
                                                    child: const Text("Delete",
                                                        style: TextStyle(
                                                            color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              await FirebaseFirestore.instance
                                                  .collection('forms')
                                                  .doc(form.id)
                                                  .delete();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
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
  );
}
}
