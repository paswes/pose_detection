import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/features/anatomy/presentation/pages/anatomy_page.dart';
import 'package:pose_detection/presentation/bloc/session_list_cubit.dart';
import 'package:pose_detection/presentation/bloc/session_list_state.dart';
import 'package:pose_detection/presentation/pages/capture_page.dart';
import 'package:pose_detection/presentation/pages/session_details_page.dart';
import 'package:pose_detection/presentation/pages/video_upload_page.dart';

/// Home page showing recorded sessions with navigation to capture.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SessionListCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<SessionListCubit>();
    _cubit.loadSessions();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _navigateToCapture() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CapturePage()),
    );

    // Reload sessions if a new session was saved
    if (result == true) {
      _cubit.loadSessions();
    }
  }

  Future<void> _navigateToUpload() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VideoUploadPage()),
    );

    if (!mounted) return;
    _cubit.loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<SessionListCubit, SessionListState>(
        builder: (context, state) => switch (state) {
          SessionListInitializing() => _InitializingScreen(state: state),
          SessionListLoaded() => _buildLoadedScaffold(state.sessions),
        },
      ),
    );
  }

  Widget _buildLoadedScaffold(List<Session> sessions) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnatomyPage()),
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.accessibility_new_rounded,
                color: Color(0xFF888888),
                size: 24,
              ),
            ),
          ),
        ],
      ),
      body: sessions.isEmpty ? _buildEmptyState() : _buildSessionList(sessions),
      floatingActionButton: sessions.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                GestureDetector(
                  onTap: _navigateToUpload,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Icon(
                      Icons.video_library_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _navigateToCapture,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            size: 48,
            color: Color(0xFF444444),
          ),
          const SizedBox(height: 16),
          const Text(
            'Noch keine Sessions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _cubit.loadDemoSession,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Demo RDL laden',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _navigateToUpload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Video hochladen',
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

  Widget _buildSessionList(List<Session> sessions) {
    return ListView.builder(
      itemCount: sessions.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return _SessionCard(
          session: sessions[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionDetailsPage(session: sessions[index]),
            ),
          ),
          onDismissed: () => _cubit.deleteSession(sessions[index].id),
          onConfirmDelete: () => _confirmDelete(sessions[index]),
        );
      },
    );
  }

  Future<bool> _confirmDelete(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Session löschen?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          session.title,
          style: const TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Löschen',
              style: TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
        ],
      ),
    );

    return confirmed == true;
  }
}

// -- Initializing Screen --

class _InitializingScreen extends StatelessWidget {
  final SessionListInitializing state;

  const _InitializingScreen({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fitness_center_rounded,
                size: 56,
                color: Color(0xFF4CAF50),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pose Engine',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.totalFrames > 0
                    ? 'Demo wird vorbereitet...'
                    : 'Wird geladen...',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888888),
                ),
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.totalFrames > 0 ? state.progress : null,
                  backgroundColor: const Color(0xFF2A2A2A),
                  color: const Color(0xFF4CAF50),
                  minHeight: 4,
                ),
              ),
              if (state.totalFrames > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '${state.completedFrames} / ${state.totalFrames} Frames',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// -- Session Card --

class _SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final Future<bool> Function() onConfirmDelete;

  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDismissed,
    required this.onConfirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    final duration = session.duration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    final dateStr =
        '${session.createdAt.day.toString().padLeft(2, '0')}.${session.createdAt.month.toString().padLeft(2, '0')}.${session.createdAt.year}';
    final timeStr =
        '${session.createdAt.hour.toString().padLeft(2, '0')}:${session.createdAt.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onConfirmDelete(),
      onDismissed: (_) => onDismissed(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5252),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: session.isDemo
                        ? const Color(0xFF2196F3).withValues(alpha: 0.15)
                        : const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    session.isDemo
                        ? Icons.play_circle_outline_rounded
                        : Icons.videocam_rounded,
                    color: session.isDemo
                        ? const Color(0xFF2196F3)
                        : const Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              session.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (session.isDemo) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2196F3,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Demo',
                                style: TextStyle(
                                  color: Color(0xFF2196F3),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateStr $timeStr',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${minutes}m ${seconds}s  •  ${session.frameCount} frames  •  ${session.isFrontCamera ? 'Front' : 'Back'}  •  ${session.isLandscape ? 'Landscape' : 'Portrait'}',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
