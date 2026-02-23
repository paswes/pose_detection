import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pose_detection/core/services/video_processing_service.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/presentation/bloc/video_upload_state.dart';

/// Manages the video upload → pose detection → save flow.
class VideoUploadCubit extends Cubit<VideoUploadState> {
  final VideoProcessingService _processingService;
  final SessionRepository _sessionRepository;

  VideoUploadCubit({
    required VideoProcessingService processingService,
    required SessionRepository sessionRepository,
  })  : _processingService = processingService,
        _sessionRepository = sessionRepository,
        super(const VideoUploadIdle());

  /// Pick a video from the gallery, process it, and save to DB.
  Future<void> pickAndProcessVideo() async {
    emit(const VideoUploadPicking());

    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);

      if (video == null) {
        // User cancelled the picker
        emit(const VideoUploadIdle());
        return;
      }

      await processVideoFromPath(video.path);
    } catch (e) {
      emit(VideoUploadError(message: 'Fehler beim Verarbeiten: $e'));
    }
  }

  /// Process an already-picked video file and save to DB.
  Future<void> processVideoFromPath(String videoPath) async {
    try {
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      final result = await _processingService.processVideo(
        videoPath,
        sessionId,
        onProgress: (completed, total) {
          emit(VideoUploadProcessing(
            completedFrames: completed,
            totalFrames: total,
          ));
        },
      );

      emit(const VideoUploadSaving());

      final isLandscape = result.imageWidth > result.imageHeight;
      final session = Session(
        id: result.sessionId,
        title: 'Video Upload',
        createdAt: DateTime.now(),
        durationMs: result.durationMs,
        videoPath: result.videoPath,
        frameCount: result.frames.length,
        isFrontCamera: false,
        isLandscape: isLandscape,
        imageWidth: result.imageWidth,
        imageHeight: result.imageHeight,
        sensorOrientation: 0,
      );

      await _sessionRepository.saveSession(session, result.frames);

      emit(VideoUploadComplete(session: session));
    } catch (e) {
      emit(VideoUploadError(message: 'Fehler beim Verarbeiten: $e'));
    }
  }

  /// Reset to idle state.
  void reset() => emit(const VideoUploadIdle());
}
