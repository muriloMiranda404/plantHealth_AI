import 'package:flutter/material.dart';
import '../../domain/entities/diary_note.dart';
import '../../domain/usecases/add_diary_note.dart';
import '../../domain/usecases/delete_diary_note.dart';
import '../../domain/usecases/get_diary_notes.dart';

class DiaryProvider with ChangeNotifier {
  final GetDiaryNotes getDiaryNotes;
  final AddDiaryNote addDiaryNote;
  final DeleteDiaryNote deleteDiaryNote;

  List<DiaryNote> _notes = [];
  List<DiaryNote> get notes => _notes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  DiaryProvider({
    required this.getDiaryNotes,
    required this.addDiaryNote,
    required this.deleteDiaryNote,
  });

  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();
    _notes = await getDiaryNotes();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addNote(String note, {bool isReminder = false, DateTime? reminderTime, String? imagePath}) async {
    final diaryNote = DiaryNote(
      note: note,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isReminder: isReminder,
      reminderTime: reminderTime?.millisecondsSinceEpoch,
      imagePath: imagePath,
    );
    await addDiaryNote(diaryNote);
    await loadNotes();
  }

  Future<void> deleteNote(int id) async {
    await deleteDiaryNote(id);
    await loadNotes();
  }
}
