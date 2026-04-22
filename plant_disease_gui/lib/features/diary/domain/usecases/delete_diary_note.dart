import '../repositories/diary_repository.dart';

class DeleteDiaryNote {
  final DiaryRepository repository;

  DeleteDiaryNote(this.repository);

  Future<void> call(int id) async {
    await repository.deleteNote(id);
  }
}
