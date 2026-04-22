import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final directory = await getApplicationSupportDirectory();
      path = p.join(directory.path, 'sensor_history_v7.db');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, 'sensor_history_v7.db');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE history(id INTEGER PRIMARY KEY AUTOINCREMENT, sensor_key TEXT, value REAL, timestamp INTEGER)',
        );
        await db.execute(
          'CREATE TABLE diary(id INTEGER PRIMARY KEY AUTOINCREMENT, note TEXT, timestamp INTEGER, is_reminder INTEGER DEFAULT 0, reminder_time INTEGER, image_path TEXT)',
        );
        await db.execute(
          'CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, path TEXT, timestamp INTEGER)',
        );
      },
    );
  }
}
