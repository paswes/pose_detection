import 'package:equatable/equatable.dart';

import 'package:pose_detection/data/models/session.dart';

/// States for the video upload processing flow.
sealed class VideoUploadState extends Equatable {
  const VideoUploadState();

  @override
  List<Object?> get props => [];
}

/// Ready to pick a video.
class VideoUploadIdle extends VideoUploadState {
  const VideoUploadIdle();
}

/// Gallery picker is open.
class VideoUploadPicking extends VideoUploadState {
  const VideoUploadPicking();
}

/// Extracting frames and running ML Kit pose detection.
class VideoUploadProcessing extends VideoUploadState {
  final int completedFrames;
  final int totalFrames;

  const VideoUploadProcessing({
    required this.completedFrames,
    required this.totalFrames,
  });

  double get progress => totalFrames > 0 ? completedFrames / totalFrames : 0.0;

  @override
  List<Object?> get props => [completedFrames, totalFrames];
}

/// Saving session to database.
class VideoUploadSaving extends VideoUploadState {
  const VideoUploadSaving();
}

/// Processing complete — ready to navigate to session details.
class VideoUploadComplete extends VideoUploadState {
  final Session session;

  const VideoUploadComplete({required this.session});

  @override
  List<Object?> get props => [session.id];
}

/// Error during upload or processing.
class VideoUploadError extends VideoUploadState {
  final String message;

  const VideoUploadError({required this.message});

  @override
  List<Object?> get props => [message];
}
