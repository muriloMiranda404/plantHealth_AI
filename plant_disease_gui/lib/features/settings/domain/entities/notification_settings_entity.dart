class NotificationSettingsEntity {
  final bool isEnabled;
  final Map<String, CategorySettings> categories;
  final DndSettings dnd;

  NotificationSettingsEntity({
    required this.isEnabled,
    required this.categories,
    required this.dnd,
  });
}

class CategorySettings {
  final bool push;
  final bool log;

  CategorySettings({required this.push, required this.log});
}

class DndSettings {
  final bool isEnabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool bypassForCritical;

  DndSettings({
    required this.isEnabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.bypassForCritical,
  });
}
