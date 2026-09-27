import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Create a new page to show when form is already submitted
class FormAlreadySubmittedPage extends StatelessWidget {
  final String formTitle;
  final Timestamp submittedDate;

  const FormAlreadySubmittedPage({
    Key? key,
    required this.formTitle,
    required this.submittedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format the timestamp to a readable date
    final dateFormat = DateFormat('MMMM d, yyyy - h:mm a');
    final formattedDate = dateFormat.format(submittedDate.toDate());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Submission'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'You already submitted an answer to this form',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                formTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Text(
                'Submitted on:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                formattedDate,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}