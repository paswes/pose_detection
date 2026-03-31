import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/presentation/bloc/video_upload_cubit.dart';
import 'package:pose_detection/presentation/bloc/video_upload_state.dart';
import 'package:pose_detection/presentation/pages/session_details_page.dart';

/// Full-screen page that processes a picked video and navigates to details.
///
/// When [videoPath] is provided, skips the gallery picker and processes
/// directly. Otherwise opens the picker on launch.
class VideoUploadPage extends StatefulWidget {
  /// Optional pre-picked video path to skip the gallery picker.
  final String? videoPath;

  const VideoUploadPage({super.key, this.videoPath});

  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  late final VideoUploadCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<VideoUploadCubit>();
    if (widget.videoPath != null) {
      _cubit.processVideoFromPath(widget.videoPath!);
    } else {
      _cubit.pickAndProcessVideo();
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Video verarbeiten',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        body: SafeArea(
          child: BlocConsumer<VideoUploadCubit, VideoUploadState>(
            listener: _handleStateChange,
            builder: (context, state) {
              return switch (state) {
                VideoUploadIdle() => const SizedBox.shrink(),
                VideoUploadPicking() => _buildPicking(),
                VideoUploadProcessing() => _buildProcessing(state),
                VideoUploadSaving() => _buildSaving(),
                VideoUploadComplete() => const SizedBox.shrink(),
                VideoUploadError() => _buildError(state),
              };
            },
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, VideoUploadState state) {
    if (state is VideoUploadComplete) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailsPage(session: state.session),
        ),
      );
    }
    if (state is VideoUploadIdle) {
      // User cancelled the picker
      Navigator.pop(context);
    }
  }

  Widget _buildPicking() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Video auswaehlen...',
            style: TextStyle(color: Color(0xFF888888), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing(VideoUploadProcessing state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: state.progress > 0 ? state.progress : null,
              color: const Color(0xFF4CAF50),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            state.totalFrames > 0
                ? 'Frame ${state.completedFrames} / ${state.totalFrames}'
                : 'Frames werden vorbereitet...',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pose-Erkennung laeuft...',
            style: TextStyle(color: Color(0xFF666666), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSaving() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4CAF50)),
          SizedBox(height: 16),
          Text(
            'Speichern...',
            style: TextStyle(color: Color(0xFF888888), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError(VideoUploadError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Color(0xFFFF5252),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              state.message,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _cubit.pickAndProcessVideo(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Erneut versuchen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
