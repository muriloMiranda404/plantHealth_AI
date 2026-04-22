import '../../domain/entities/diary_note.dart';
import '../../domain/repositories/diary_repository.dart';
import '../datasources/diary_local_data_source.dart';
import '../models/diary_note_model.dart';

class DiaryRepositoryImpl implements DiaryRepository {
  final DiaryLocalDataSource localDataSource;

  DiaryRepositoryImpl(this.localDataSource);

  @override
  Future<List<DiaryNote>> getNotes() async {
    return await localDataSource.getNotes();
  }

  @override
  Future<void> addNote(DiaryNote note) async {
    final model = DiaryNoteModel(
      note: note.note,
      timestamp: note.timestamp,
      isReminder: note.isReminder,
      reminderTime: note.reminderTime,
      imagePath: note.imagePath,
    );
    await localDataSource.addNote(model);
  }

  @override
  Future<void> deleteNote(int id) async {
    await localDataSource.deleteNote(id);
  }
}
