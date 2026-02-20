import 'dart:convert';

import 'package:pose_detection/data/models/landmark_data.dart';

/// A single frame of tracking data stored per session.
class TrackedFrame {
  final String sessionId;
  final int frameIndex;
  final int timestampMicros;
  final List<LandmarkData> landmarks;
  final bool isPersonDetected;
  final double personConfidence;

  const TrackedFrame({
    required this.sessionId,
    required this.frameIndex,
    required this.timestampMicros,
    required this.landmarks,
    required this.isPersonDetected,
    required this.personConfidence,
  });

  Map<String, dynamic> toMap() => {
    'session_id': sessionId,
    'frame_index': frameIndex,
    'timestamp_micros': timestampMicros,
    'landmarks_json': jsonEncode(landmarks.map((l) => l.toJson()).toList()),
    'is_person_detected': isPersonDetected ? 1 : 0,
    'person_confidence': personConfidence,
  };

  factory TrackedFrame.fromMap(Map<String, dynamic> map) {
    final landmarksList = (jsonDecode(map['landmarks_json'] as String) as List)
        .map((e) => LandmarkData.fromJson(e as Map<String, dynamic>))
        .toList();

    return TrackedFrame(
      sessionId: map['session_id'] as String,
      frameIndex: (map['frame_index'] as int?) ?? 0,
      timestampMicros: map['timestamp_micros'] as int,
      landmarks: landmarksList,
      isPersonDetected: (map['is_person_detected'] as int) == 1,
      personConfidence: (map['person_confidence'] as num).toDouble(),
    );
  }
}
