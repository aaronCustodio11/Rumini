import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class PsychoeducDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function() onPostChanged;
  final Map<String, dynamic>? existingPost; // null for add, populated for edit

  const PsychoeducDialog({
    Key? key,
    required this.userData,
    required this.onPostChanged,
    this.existingPost,
  }) : super(key: key);

  @override
  State<PsychoeducDialog> createState() => _PsychoeducDialogState();
}

class _PsychoeducDialogState extends State<PsychoeducDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customTagController = TextEditingController();

  // For web and mobile compatibility
  XFile? _pickedFile;
  Uint8List? _webImageBytes;
  String? _existingImageUrl;
  bool _imageChanged = false;

  bool _isLoading = false;
  String _errorMessage = '';
  bool _isEditMode = false;
  String? _postId;

  // Default tags list
  final List<String> _defaultTags = [
    'Career',
    'Relationship',
    'Self Development',
    'Studies',
    'Social Relationship',
    'Family',
    'Abused/Sensitive Cases',
    'Others',
  ];

  // Selected tags
  final List<String> _selectedTags = [];

  // Custom tags
  final List<String> _customTags = [];
  bool _showCustomTagField = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // Check if we're in edit mode
    if (widget.existingPost != null) {
      _isEditMode = true;
      _postId = widget.existingPost!['postId'];

      // Populate fields with existing data
      _titleController.text = widget.existingPost!['title'] ?? '';
      _descriptionController.text = widget.existingPost!['description'] ?? '';
      _existingImageUrl = widget.existingPost!['image'];

      // Handle tags
      final List<dynamic>? tags = widget.existingPost!['tags'];
      if (tags != null) {
        for (var tag in tags) {
          if (_defaultTags.contains(tag)) {
            _selectedTags.add(tag);
          } else {
            _customTags.add(tag);
          }
        }

        // If custom tags exist, show custom tag field
        if (_customTags.isNotEmpty) {
          _selectedTags.add('Others');
          _showCustomTagField = true;
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  // Method to pick image from gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _pickedFile = pickedFile;
          _imageChanged = true;
        });

        // Handle web platform differently
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  // Toggle tag selection
  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }

      // Show custom tag field if "Others" is selected
      if (tag == 'Others') {
        _showCustomTagField = _selectedTags.contains('Others');
        // If we're removing "Others", clear custom tags
        if (!_showCustomTagField) {
          _customTags.clear();
        }
      }
    });
  }

  // Add custom tag
  void _addCustomTag() {
    final customTag = _customTagController.text.trim();
    if (customTag.isNotEmpty) {
      setState(() {
        _customTags.add(customTag);
        _customTagController.clear();
      });
    }
  }

  // Remove custom tag
  void _removeCustomTag(String tag) {
    setState(() {
      _customTags.remove(tag);
      // If all custom tags are removed, also deselect "Others"
      if (_customTags.isEmpty) {
        _selectedTags.remove('Others');
        _showCustomTagField = false;
      }
    });
  }

  // Get all selected tags including custom tags
  List<String> _getAllTags() {
    final List<String> allTags = List.from(_selectedTags);

    // Remove "Others" if it exists and add custom tags instead
    if (allTags.contains('Others')) {
      allTags.remove('Others');
    }

    allTags.addAll(_customTags);
    return allTags;
  }

  // Submit form and create/update post
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Check image requirement
      if (!_isEditMode && _pickedFile == null) {
        setState(() {
          _errorMessage = 'Please select an image for the post';
        });
        return;
      }

      if (_isEditMode && _existingImageUrl == null && _pickedFile == null) {
        setState(() {
          _errorMessage = 'Please select an image for the post';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Generate postId if new, otherwise use existing
        final String postId = _isEditMode ? _postId! : const Uuid().v4();
        String imageUrl = _existingImageUrl ?? '';

        // Only upload new image if picked or in add mode
        if (_pickedFile != null && (_imageChanged || !_isEditMode)) {
          // Upload image to Firebase Storage
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('psychoeduc_ads')
              .child('$postId.jpg');

          UploadTask uploadTask;
          // Choose the right upload method for web or mobile
          if (kIsWeb) {
            // Upload the Uint8List directly for web
            uploadTask = storageRef.putData(
                _webImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
          } else {
            // Use File for mobile platforms
            uploadTask = storageRef.putFile(File(_pickedFile!.path));
          }

          final snapshot = await uploadTask.whenComplete(() {});

          // Get the download URL
          imageUrl = await snapshot.ref.getDownloadURL();
          print(
              'DEBUG - ${_isEditMode ? 'Updated' : 'Created'} image with URL: $imageUrl');

          // Validate URL format
          if (!imageUrl.startsWith('http')) {
            throw Exception('Invalid image URL format: $imageUrl');
          }
        }

        // Prepare post data
        final Map<String, dynamic> postData = {
          'postId': postId,
          'counId': widget.userData['counId'],
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'tags': _getAllTags(),
          'image': imageUrl,
        };

        // Add created timestamp only for new posts
        if (!_isEditMode) {
          postData['createdAt'] = FieldValue.serverTimestamp();
          postData['currentLikes'] = 0;
        }

        // Add last updated timestamp for edits
        if (_isEditMode) {
          postData['updatedAt'] = FieldValue.serverTimestamp();
        }

        // Create or update post in Firestore
        await FirebaseFirestore.instance
            .collection('psychoeduc_ads')
            .doc(postId)
            .set(postData, SetOptions(merge: _isEditMode));

        // Call callback for refresh and close dialog
        widget.onPostChanged();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } catch (error) {
        setState(() {
          _errorMessage =
              '${_isEditMode ? 'Error updating' : 'Error creating'} post: $error';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Make dialog more compact by using ConstrainedBox
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.5,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog title
                  Text(
                    _isEditMode
                        ? 'Edit Psychoeduc Post'
                        : 'Add New Psychoeduc Post',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image selection - Web and mobile compatible
                  Center(
                    child: (_pickedFile != null || _existingImageUrl != null)
                        ? Column(
                            children: [
                              // Improved image preview with aspect ratio
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: _pickedFile != null
                                      ? (kIsWeb
                                          ? _webImageBytes != null
                                              ? Image.memory(
                                                  _webImageBytes!,
                                                  fit: BoxFit.contain,
                                                )
                                              : const Center(
                                                  child:
                                                      Text('Loading image...'))
                                          : Image.network(
                                              _pickedFile!.path,
                                              fit: BoxFit.contain,
                                            ))
                                      : Image.network(
                                          _existingImageUrl!,
                                          fit: BoxFit.contain,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (context, object, stackTrace) {
                                            return const Center(
                                              child:
                                                  Text('Error loading image'),
                                            );
                                          },
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text('Change Image'),
                              ),
                            ],
                          )
                        : Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: InkWell(
                              onTap: _pickImage,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Select Image',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Title field
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Description field
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tags section
                  const Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Tag chips with smaller size
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _defaultTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        onSelected: (_) => _toggleTag(tag),
                        backgroundColor: Colors.grey[200],
                        selectedColor:
                            Theme.of(context).primaryColor.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),

                  // Custom tags section if "Others" is selected
                  if (_showCustomTagField) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _customTagController,
                            decoration: const InputDecoration(
                              labelText: 'Add custom tag',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addCustomTag,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            minimumSize: const Size(40, 40),
                          ),
                          child: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),

                    // Display custom tags
                    if (_customTags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _customTags.map((tag) {
                          return Chip(
                            label:
                                Text(tag, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => _removeCustomTag(tag),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 0),
                          );
                        }).toList(),
                      ),
                    ],
                  ],

                  // Error message
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(_isEditMode ? 'Update Post' : 'Create Post'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
