import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite database for storing recorded sessions and tracking data.
class AppDatabase {
  static const _databaseName = 'pose_detection.db';
  static const _databaseVersion = 5;

  Database? _database;

  Database get database {
    if (_database == null) throw Exception('Database not initialized');
    return _database!;
  }

  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        video_path TEXT NOT NULL,
        frame_count INTEGER NOT NULL,
        is_front_camera INTEGER NOT NULL DEFAULT 0,
        is_landscape INTEGER NOT NULL DEFAULT 0,
        image_width REAL NOT NULL DEFAULT 0,
        image_height REAL NOT NULL DEFAULT 0,
        sensor_orientation INTEGER NOT NULL DEFAULT 90,
        is_demo INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tracked_frames (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        timestamp_micros INTEGER NOT NULL,
        landmarks_json TEXT NOT NULL,
        is_person_detected INTEGER NOT NULL,
        person_confidence REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_frames_session ON tracked_frames (session_id)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE sessions ADD COLUMN is_front_camera INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE sessions ADD COLUMN is_landscape INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE sessions ADD COLUMN image_width REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE sessions ADD COLUMN image_height REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE sessions ADD COLUMN sensor_orientation INTEGER NOT NULL DEFAULT 90',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE sessions ADD COLUMN is_demo INTEGER NOT NULL DEFAULT 0',
      );
      // Mark existing demo session from previous versions
      await db.execute("UPDATE sessions SET is_demo = 1 WHERE id = 'demo_mel'");
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
