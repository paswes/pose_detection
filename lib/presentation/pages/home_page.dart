import 'package:flutter/material.dart';
import 'package:pose_detection/presentation/pages/capture_page.dart';

/// Homepage showing recorded sessions with navigation to capture
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meine Übungen',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: _buildEmptyState(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCapture(context),
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 24),
          Text(
            'Noch keine Aufnahmen',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF888888),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tippe auf + um eine Übung aufzunehmen',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCapture(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CapturePage()),
    );
  }
}
