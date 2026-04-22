class DiaryNote {
  final int? id;
  final String note;
  final int timestamp;
  final bool isReminder;
  final int? reminderTime;
  final String? imagePath;

  DiaryNote({
    this.id,
    required this.note,
    required this.timestamp,
    required this.isReminder,
    this.reminderTime,
    this.imagePath,
  });
}
