import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/features/anatomy/presentation/pages/anatomy_page.dart';
import 'package:pose_detection/presentation/bloc/session_list_cubit.dart';
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Sessions',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
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
        body: BlocBuilder<SessionListCubit, List<Session>>(
          builder: (context, sessions) {
            if (sessions.isEmpty) {
              return _buildEmptyState();
            }
            return _buildSessionList(sessions);
          },
        ),
        floatingActionButton: BlocBuilder<SessionListCubit, List<Session>>(
          builder: (context, sessions) {
            if (sessions.isEmpty) return const SizedBox.shrink();
            return GestureDetector(
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
            );
          },
        ),
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
            onTap: _navigateToCapture,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Starte erste Session',
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
        return _buildSessionCard(sessions[index]);
      },
    );
  }

  Widget _buildSessionCard(Session session) {
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
      confirmDismiss: (_) => _confirmDelete(session),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionDetailsPage(session: session),
          ),
        ),
        child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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

    if (confirmed == true) {
      _cubit.deleteSession(session.id);
      return true;
    }
    return false;
  }
}
