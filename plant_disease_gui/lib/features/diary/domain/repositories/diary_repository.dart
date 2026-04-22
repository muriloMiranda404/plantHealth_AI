import '../entities/diary_note.dart';

abstract class DiaryRepository {
  Future<List<DiaryNote>> getNotes();
  Future<void> addNote(DiaryNote note);
  Future<void> deleteNote(int id);
}
