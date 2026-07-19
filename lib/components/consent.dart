import 'package:flutter/material.dart';

class AskConsent extends StatelessWidget {
  const AskConsent({super.key});

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // prevent closing without choosing
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Mood & Emotion Tracker",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This feature lets you log your daily moods "
                "(Neutral, Positive, Negative) and emotions "
                "(Joy, Sadness, Surprise, Fear, Disgust, Contempt, Anger).",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                "• Moods are shown on a calendar with colors for easy tracking.\n"
                "• Emotions can be logged up to 4 times a day and shown as blended gradients.\n"
                "• You may also add notes to reflect on your feelings.",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                "This helps you better understand your own well-being.",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showConsentDialog(context);
            },
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  void _showConsentDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Consent for Monitoring",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "We kindly ask for your consent to allow the guidance counselor "
                "to view your logged moods and emotions, including the notes you write. "
                "\n\nThe purpose is to provide better support and understanding of your well-being. "
                "Your participation is completely voluntary, and your choice will be respected.",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                "You can change this setting anytime in your Profile page.",
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Save consent = false in database
            },
            child: const Text("Turn Off"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Save consent = true in database
            },
            child: const Text("Turn On"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ask Consent")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _showInfoDialog(context),
          child: const Text("Show Consent Dialog"),
        ),
      ),
    );
  }
}
