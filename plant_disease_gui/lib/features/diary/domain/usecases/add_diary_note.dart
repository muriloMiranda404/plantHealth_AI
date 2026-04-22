import '../entities/diary_note.dart';
import '../repositories/diary_repository.dart';

class AddDiaryNote {
  final DiaryRepository repository;

  AddDiaryNote(this.repository);

  Future<void> call(DiaryNote note) async {
    await repository.addNote(note);
  }
}
