import '../entities/diary_note.dart';
import '../repositories/diary_repository.dart';

class GetDiaryNotes {
  final DiaryRepository repository;

  GetDiaryNotes(this.repository);

  Future<List<DiaryNote>> call() async {
    return await repository.getNotes();
  }
}
