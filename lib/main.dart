import 'package:flutter/material.dart';
import 'package:pose_detection/squat_detector_view.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Detection',
      debugShowCheckedModeBanner: true,

      home: SquatDetectorView(),
    );
  }
}
