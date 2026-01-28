import 'package:flutter/material.dart';
import 'package:pose_detection/presentation/pages/dashboard_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PoseEngineApp());
}

class PoseEngineApp extends StatelessWidget {
  const PoseEngineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Engine Core',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        primaryColor: Colors.cyan,
        colorScheme: ColorScheme.dark(
          primary: Colors.cyan,
          secondary: Colors.cyan.shade700,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}
