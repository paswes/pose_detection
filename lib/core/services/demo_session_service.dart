import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:pose_detection/core/services/video_processing_service.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';

/// Seeds the database with a pre-bundled demo video on first launch.
///
/// The demo video (`assets/mel.mp4`) is processed through the standard
/// [VideoProcessingService] pipeline so its frames and landmarks are
/// identical to a user-uploaded video. Subsequent launches skip processing
/// because the session already exists in the DB.
class DemoSessionService {
  final SessionRepository _repository;
  final VideoProcessingService _processingService;

  static const _demoSessionId = 'demo_mel';
  static const _demoAssetPath = 'assets/mel.mp4';

  DemoSessionService({
    required SessionRepository repository,
    required VideoProcessingService processingService,
  }) : _repository = repository,
       _processingService = processingService;

  /// Whether the demo session still needs to be processed.
  Future<bool> needsProcessing() async {
    final existing = await _repository.getFramesForSession(_demoSessionId);
    return existing.isEmpty;
  }

  /// Ensures the demo session exists in the database.
  ///
  /// Returns immediately if already seeded. Otherwise copies the asset
  /// to Documents, runs pose detection on every frame, and saves the
  /// session + tracked frames to SQLite.
  Future<void> ensureDemoSession({
    void Function(int completed, int total)? onProgress,
  }) async {
    // Check if already seeded
    final existing = await _repository.getFramesForSession(_demoSessionId);
    if (existing.isNotEmpty) return;

    // Write bundled asset to temp file for the processing pipeline
    final videoPath = await _writeAssetToTempFile();

    // Process through the standard pipeline
    final result = await _processingService.processVideo(
      videoPath,
      _demoSessionId,
      onProgress: onProgress,
    );

    final isLandscape = result.imageWidth > result.imageHeight;
    final session = Session(
      id: _demoSessionId,
      title: 'RDL Demo',
      createdAt: DateTime.now(),
      durationMs: result.durationMs,
      videoPath: result.videoPath,
      frameCount: result.frames.length,
      isFrontCamera: false,
      isLandscape: isLandscape,
      imageWidth: result.imageWidth,
      imageHeight: result.imageHeight,
      sensorOrientation: 0,
      isDemo: true,
    );

    await _repository.saveSession(session, result.frames);
  }

  /// Write the bundled asset to a temp file.
  ///
  /// Uses temp directory so [VideoProcessingService.processVideo] can
  /// handle the copy to Documents via its own `_copyToDocuments` step.
  Future<String> _writeAssetToTempFile() async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'demo_mel.mp4');
    final tempFile = File(tempPath);

    if (tempFile.existsSync()) return tempPath;

    final data = await rootBundle.load(_demoAssetPath);
    await tempFile.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );

    return tempPath;
  }
}
