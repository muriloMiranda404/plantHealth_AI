import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/notification_settings_entity.dart';
import 'dart:convert';

abstract class SettingsRepository {
  Future<NotificationSettingsEntity> getNotificationSettings();
  Future<void> saveNotificationSettings(NotificationSettingsEntity settings);
}

class SettingsRepositoryImpl implements SettingsRepository {
  @override
  Future<NotificationSettingsEntity> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('is_notifications_enabled') ?? true;
    final String? notifJson = prefs.getString('notification_settings_v1');
    
    Map<String, CategorySettings> categories = {};
    if (notifJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(notifJson);
      decoded.forEach((key, val) {
        categories[key] = CategorySettings(
          push: val['push'] ?? true,
          log: val['log'] ?? true,
        );
      });
    }

    final isDndEnabled = prefs.getBool('is_dnd_enabled') ?? false;
    final dndStart = prefs.getString('dnd_start_time') ?? "22:00";
    final dndEnd = prefs.getString('dnd_end_time') ?? "07:00";
    final bypassDnd = prefs.getBool('bypass_dnd_critical') ?? true;

    return NotificationSettingsEntity(
      isEnabled: isEnabled,
      categories: categories,
      dnd: DndSettings(
        isEnabled: isDndEnabled,
        startHour: int.parse(dndStart.split(':')[0]),
        startMinute: int.parse(dndStart.split(':')[1]),
        endHour: int.parse(dndEnd.split(':')[0]),
        endMinute: int.parse(dndEnd.split(':')[1]),
        bypassForCritical: bypassDnd,
      ),
    );
  }

  @override
  Future<void> saveNotificationSettings(NotificationSettingsEntity settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_notifications_enabled', settings.isEnabled);
    
    Map<String, dynamic> notifMap = {};
    settings.categories.forEach((key, val) {
      notifMap[key] = {'push': val.push, 'log': val.log};
    });
    await prefs.setString('notification_settings_v1', jsonEncode(notifMap));
    
    await prefs.setBool('is_dnd_enabled', settings.dnd.isEnabled);
    await prefs.setString('dnd_start_time', "${settings.dnd.startHour}:${settings.dnd.startMinute}");
    await prefs.setString('dnd_end_time', "${settings.dnd.endHour}:${settings.dnd.endMinute}");
    await prefs.setBool('bypass_dnd_critical', settings.dnd.bypassForCritical);
  }
}
