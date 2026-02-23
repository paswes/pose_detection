import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/features/anatomy/presentation/pages/anatomy_page.dart';
import 'package:pose_detection/presentation/bloc/session_list_cubit.dart';
import 'package:pose_detection/presentation/bloc/session_list_state.dart';
import 'package:pose_detection/presentation/pages/capture_page.dart';
import 'package:pose_detection/presentation/pages/session_details_page.dart';

/// Home page showing recorded sessions with navigation to capture.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SessionListCubit _cubit;
  bool _isPicking = false;

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

  Future<void> _pickAndUploadVideo() async {
    if (_isPicking) return;

    setState(() => _isPicking = true);

    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);

      if (!mounted) return;
      setState(() => _isPicking = false);

      if (video == null) return;

      _cubit.processVideoFromPath(video.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPicking = false);
    }
  }

  void _showMoreSheet() {
    WoltModalSheet.show(
      context: context,
      pageListBuilder: (sheetContext) => [
        SliverWoltModalSheetPage(
          backgroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          hasSabGradient: false,
          isTopBarLayerAlwaysVisible: true,
          topBarTitle: const Text(
            'Mehr',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailingNavBarWidget: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF888888)),
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ),
          mainContentSliversBuilder: (context) => [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.list(
                children: [
                  _MoreSheetItem(
                    icon: Icons.videocam_rounded,
                    label: 'Live Capture',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _navigateToCapture();
                    },
                  ),
                  _MoreSheetItem(
                    icon: Icons.accessibility_new_rounded,
                    label: 'Anatomie',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.push(
                        this.context,
                        MaterialPageRoute(
                          builder: (_) => const AnatomyPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      modalBarrierColor: Colors.black54,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<SessionListCubit, SessionListState>(
        builder: (context, state) => switch (state) {
          SessionListInitializing() => _InitializingScreen(state: state),
          SessionListLoaded() => _buildLoadedScaffold(state),
        },
      ),
    );
  }

  Widget _buildLoadedScaffold(SessionListLoaded state) {
    final sessions = state.sessions;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (sessions.isNotEmpty && !state.processingVideo)
            GestureDetector(
              onTap: _showMoreSheet,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: Color(0xFF888888),
                  size: 24,
                ),
              ),
            ),
        ],
      ),
      body: sessions.isEmpty && !state.processingVideo
          ? _buildEmptyState()
          : _buildSessionList(state),
      floatingActionButton: sessions.isEmpty && !state.processingVideo
          ? null
          : GestureDetector(
              onTap: _pickAndUploadVideo,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: _isPicking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(
                        Icons.video_library_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'Noch keine Sessions',
        style: TextStyle(
          fontSize: 16,
          color: Color(0xFF666666),
        ),
      ),
    );
  }

  Widget _buildSessionList(SessionListLoaded state) {
    final sessions = state.sessions;
    final extra = state.processingVideo ? 1 : 0;
    return ListView.builder(
      itemCount: sessions.length + extra,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        if (state.processingVideo && index == 0) {
          return _ProcessingCard(
            completed: state.processingCompleted,
            total: state.processingTotal,
            progress: state.processingProgress,
          );
        }
        final session = sessions[index - extra];
        return _SessionCard(
          session: session,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionDetailsPage(session: session),
            ),
          ),
          onDismissed: () => _cubit.deleteSession(session.id),
          onConfirmDelete: () => _confirmDelete(session),
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Spacer(),
                Image.asset(
                  'assets/logo.png',
                  width: 240,
                  height: 240,
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.totalFrames > 0 ? state.progress : null,
                    backgroundColor: const Color(0xFF2A2A2A),
                    color: Color.fromARGB(255, 74, 230, 215),
                    minHeight: 4,
                  ),
                ),
                if (state.totalFrames > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.totalFrames > 0
                        ? 'Demo wird vorbereitet...'
                        : 'Wird geladen...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
                Spacer(),
                Image.asset(
                  'assets/powered_by.png',
                  width: 300,
                  height: 64,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -- More Sheet Item --

class _MoreSheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF888888), size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Processing Card --

class _ProcessingCard extends StatelessWidget {
  final int completed;
  final int total;
  final double progress;

  const _ProcessingCard({
    required this.completed,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  value: total > 0 ? progress : null,
                  color: const Color(0xFF4CAF50),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Video wird verarbeitet...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total > 0
                        ? 'Frame $completed / $total'
                        : 'Pose-Erkennung läuft...',
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
                        '${minutes}m ${seconds}s  •  ${session.frameCount} frames',
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
