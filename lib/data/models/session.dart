/// A recorded pose detection session.
class Session {
  final String id;
  final String title;
  final DateTime createdAt;
  final int durationMs;
  final String videoPath;
  final int frameCount;
  final bool isFrontCamera;
  final bool isLandscape;

  const Session({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.durationMs,
    required this.videoPath,
    required this.frameCount,
    required this.isFrontCamera,
    required this.isLandscape,
  });

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'created_at': createdAt.millisecondsSinceEpoch,
    'duration_ms': durationMs,
    'video_path': videoPath,
    'frame_count': frameCount,
    'is_front_camera': isFrontCamera ? 1 : 0,
    'is_landscape': isLandscape ? 1 : 0,
  };

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      durationMs: map['duration_ms'] as int,
      videoPath: map['video_path'] as String,
      frameCount: map['frame_count'] as int,
      isFrontCamera: (map['is_front_camera'] as int) == 1,
      isLandscape: (map['is_landscape'] as int) == 1,
    );
  }
}
