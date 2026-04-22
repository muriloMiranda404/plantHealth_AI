import '../../domain/entities/diary_note.dart';

class DiaryNoteModel extends DiaryNote {
  DiaryNoteModel({
    super.id,
    required super.note,
    required super.timestamp,
    required super.isReminder,
    super.reminderTime,
    super.imagePath,
  });

  factory DiaryNoteModel.fromMap(Map<String, dynamic> map) {
    return DiaryNoteModel(
      id: map['id'],
      note: map['note'],
      timestamp: map['timestamp'],
      isReminder: map['is_reminder'] == 1,
      reminderTime: map['reminder_time'],
      imagePath: map['image_path'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'note': note,
      'timestamp': timestamp,
      'is_reminder': isReminder ? 1 : 0,
      'reminder_time': reminderTime,
      'image_path': imagePath,
    };
  }
}
