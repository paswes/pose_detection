import 'dart:io';

import 'package:pose_detection/core/data/database/app_database.dart';
import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/data/models/tracked_frame.dart';

class SessionRepository {
  final AppDatabase _database;

  SessionRepository({required AppDatabase database}) : _database = database;

  Future<void> saveSession(Session session, List<TrackedFrame> frames) async {
    final db = _database.database;

    await db.transaction((txn) async {
      await txn.insert('sessions', session.toMap());

      final batch = txn.batch();
      for (final frame in frames) {
        batch.insert('tracked_frames', frame.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Session>> getAllSessions() async {
    final db = _database.database;
    final maps = await db.query(
      'sessions',
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Session.fromMap(m)).toList();
  }

  Future<List<TrackedFrame>> getFramesForSession(String sessionId) async {
    final db = _database.database;
    final maps = await db.query(
      'tracked_frames',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp_micros ASC',
    );
    return maps.map((m) => TrackedFrame.fromMap(m)).toList();
  }

  Future<void> deleteSession(String sessionId) async {
    final db = _database.database;

    // Get video path before deleting
    final maps = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    if (maps.isNotEmpty) {
      final session = Session.fromMap(maps.first);
      final videoFile = File(session.videoPath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }
    }

    await db.delete(
      'tracked_frames',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }
}
