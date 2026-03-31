import 'dart:convert';

import 'package:pose_detection/core/domain/models/landmark.dart';

/// A single frame of tracking data stored per session.
class TrackedFrame {
  final String sessionId;
  final int timestampMicros;
  final List<Landmark> landmarks;
  final bool isPersonDetected;

  const TrackedFrame({
    required this.sessionId,
    required this.timestampMicros,
    required this.landmarks,
    required this.isPersonDetected,
  });

  Map<String, dynamic> toMap() => {
    'session_id': sessionId,
    'timestamp_micros': timestampMicros,
    'landmarks_json': jsonEncode(landmarks.map((l) => l.toJson()).toList()),
    'is_person_detected': isPersonDetected ? 1 : 0,
    // Legacy column kept for backwards compatibility with older DB versions
    'person_confidence': 0.0,
  };

  factory TrackedFrame.fromMap(Map<String, dynamic> map) {
    final landmarksList = (jsonDecode(map['landmarks_json'] as String) as List)
        .map((e) => Landmark.fromJson(e as Map<String, dynamic>))
        .toList();

    return TrackedFrame(
      sessionId: map['session_id'] as String,
      timestampMicros: map['timestamp_micros'] as int,
      landmarks: landmarksList,
      isPersonDetected: (map['is_person_detected'] as int) == 1,
    );
  }
}
