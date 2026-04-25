import 'package:flutter/material.dart';
import 'package:plant_health/features/settings/domain/entities/notification_settings_entity.dart';
import 'package:plant_health/features/settings/data/repositories/settings_repository_impl.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsRepository repository;

  NotificationSettingsEntity? _notificationSettings;
  NotificationSettingsEntity? get notificationSettings => _notificationSettings;

  SettingsProvider(this.repository);

  Future<void> loadSettings() async {
    _notificationSettings = await repository.getNotificationSettings();
    notifyListeners();
  }

  Future<void> updateNotificationEnabled(bool value) async {
    if (_notificationSettings == null) return;
    _notificationSettings = NotificationSettingsEntity(
      isEnabled: value,
      categories: _notificationSettings!.categories,
      dnd: _notificationSettings!.dnd,
    );
    await repository.saveNotificationSettings(_notificationSettings!);
    notifyListeners();
  }

}
