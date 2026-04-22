import 'package:plant_health/core/data/datasources/local_database.dart';
import '../models/diary_note_model.dart';

abstract class DiaryLocalDataSource {
  Future<List<DiaryNoteModel>> getNotes();
  Future<void> addNote(DiaryNoteModel note);
  Future<void> deleteNote(int id);
}

class DiaryLocalDataSourceImpl implements DiaryLocalDataSource {
  final LocalDatabase localDatabase;

  DiaryLocalDataSourceImpl(this.localDatabase);

  @override
  Future<List<DiaryNoteModel>> getNotes() async {
    final db = await localDatabase.database;
    final maps = await db.query('diary', orderBy: 'timestamp DESC');
    return maps.map((map) => DiaryNoteModel.fromMap(map)).toList();
  }

  @override
  Future<void> addNote(DiaryNoteModel note) async {
    final db = await localDatabase.database;
    await db.insert('diary', note.toMap());
  }

  @override
  Future<void> deleteNote(int id) async {
    final db = await localDatabase.database;
    await db.delete('diary', where: 'id = ?', whereArgs: [id]);
  }
}
