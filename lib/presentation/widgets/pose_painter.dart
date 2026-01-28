import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';

/// Generic painter for drawing all 33 ML Kit pose landmarks
/// High-visibility cyan skeleton for analysis purposes
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Size widgetSize;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // High-visibility cyan color scheme
    final Paint landmarkPaint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 5
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw all skeletal connections
    _drawAllConnections(canvas, linePaint);

    // Draw all 33 landmark points
    for (final landmark in pose.landmarks.values) {
      final point = CoordinateTranslator.translatePoint(
        landmark.x,
        landmark.y,
        imageSize,
        widgetSize,
      );

      // Draw confidence indicator (larger = higher confidence)
      final confidence = landmark.likelihood;
      canvas.drawCircle(
        point,
        10 + (confidence * 5),
        Paint()..color = Colors.yellow.withValues(alpha: confidence * 0.5),
      );

      // Draw landmark point
      canvas.drawCircle(point, 7, landmarkPaint);
    }
  }

  /// Draw all skeletal connections for the complete pose
  void _drawAllConnections(Canvas canvas, Paint paint) {
    // Complete ML Kit Pose skeleton connections (33 landmarks total)
    final connections = [
      // Face (11 connections)
      [PoseLandmarkType.leftEyeInner, PoseLandmarkType.leftEye],
      [PoseLandmarkType.leftEye, PoseLandmarkType.leftEyeOuter],
      [PoseLandmarkType.leftEyeOuter, PoseLandmarkType.leftEar],
      [PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye],
      [PoseLandmarkType.rightEye, PoseLandmarkType.rightEyeOuter],
      [PoseLandmarkType.rightEyeOuter, PoseLandmarkType.rightEar],
      [PoseLandmarkType.leftMouth, PoseLandmarkType.rightMouth],
      [PoseLandmarkType.nose, PoseLandmarkType.leftEyeInner],
      [PoseLandmarkType.nose, PoseLandmarkType.rightEyeInner],
      [PoseLandmarkType.leftMouth, PoseLandmarkType.leftEar],
      [PoseLandmarkType.rightMouth, PoseLandmarkType.rightEar],

      // Torso (4 connections)
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],

      // Left arm (4 connections)
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex],
      [PoseLandmarkType.leftPinky, PoseLandmarkType.leftIndex],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb],

      // Right arm (4 connections)
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex],
      [PoseLandmarkType.rightPinky, PoseLandmarkType.rightIndex],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb],

      // Left leg (5 connections)
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
      [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],

      // Right leg (5 connections)
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
      [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
      [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
    ];

    for (final connection in connections) {
      final landmark1 = pose.landmarks[connection[0]];
      final landmark2 = pose.landmarks[connection[1]];

      if (landmark1 != null && landmark2 != null) {
        final point1 = CoordinateTranslator.translatePoint(
          landmark1.x,
          landmark1.y,
          imageSize,
          widgetSize,
        );
        final point2 = CoordinateTranslator.translatePoint(
          landmark2.x,
          landmark2.y,
          imageSize,
          widgetSize,
        );

        // Uniform cyan color - no conditional coloring
        canvas.drawLine(point1, point2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
  }
}
