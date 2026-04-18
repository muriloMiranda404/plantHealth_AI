import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AppProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final NotificationService _notifications = NotificationService();

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;
  set selectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  bool isConnected = false;
  String raspIP = "127.0.0.1";
  String remoteHost = "";
  int videoPort = 5000;
  int wsPort = 8765;
  bool isCloudMode = false;
  bool useRemoteSsl = false;

  Map<String, double> sensorData = {
    'u1': 0,
    'u2': 0,
    'l1': 0,
    'l2': 0,
    't1': 0,
    't2': 0,
    'p1': 0,
    'p2': 0,
    'ec': 0,
    'water_level': 100,
    'battery': 100,
  };

  Map<String, List<FlSpot>> histories = {
    'u1': [],
    'u2': [],
    'l1': [],
    'l2': [],
    't1': [],
    't2': [],
    'p1': [],
    'p2': [],
    'ec': [],
    'water_level': [],
    'battery': [],
  };

  String plantStatus = "Iniciando...";
  bool hasDisease = false;
  double confidence = 0.0;
  int healthScore = 100;

  List<Map<String, String>> logs = [];
  List<Map<String, dynamic>> diaryNotes = [];
  List<Map<String, dynamic>> eventGallery = [];

  Future<void> deleteDiaryNote(int id) async {
    await _db.deleteDiary(id);
    await loadFromDb();
  }

  Future<void> addDiaryNote(
    String note, {
    bool isReminder = false,
    DateTime? reminderTime,
    String? imagePath,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'note': note,
      'timestamp': timestamp,
      'is_reminder': isReminder ? 1 : 0,
      'reminder_time': reminderTime?.millisecondsSinceEpoch,
      'image_path': imagePath,
    };
    await _db.insertDiary(data);

    // Agendar notificação apenas no Android/iOS
    if (isReminder &&
        reminderTime != null &&
        (Platform.isAndroid || Platform.isIOS)) {
      try {
        await _notifications.showNotification(
          id: timestamp.hashCode,
          title: "Lembrete Agendado",
          body: "Sua nota: $note",
        );
      } catch (e) {
        debugPrint("Provider: Erro ao disparar notificação: $e");
      }
    }
    await loadFromDb();
  }

  void updateSensor(String key, double value) {
    if (sensorData.containsKey(key)) {
      sensorData[key] = value;
      _updateHistory(key, value);
      notifyListeners();
    }
  }

  void _updateHistory(String key, double value) {
    if (histories.containsKey(key)) {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      histories[key]!.add(FlSpot(now, value));
      if (histories[key]!.length > 50) {
        histories[key]!.removeAt(0);
      }
    }
  }

  void addLog(String message, {String category = 'system'}) {
    logs.insert(0, {
      'message': message,
      'category': category,
      'timestamp': DateTime.now().toString(),
    });
    if (logs.length > 100) logs.removeLast();
    notifyListeners();
  }

  Future<void> loadFromDb() async {
    final historyData = await _db.getHistory();
    for (var item in historyData) {
      final key = item['sensor_key'] as String;
      if (histories.containsKey(key)) {
        histories[key]!.insert(
          0,
          FlSpot(item['timestamp'].toDouble(), item['value'] as double),
        );
      }
    }
    diaryNotes = await _db.getDiary();
    eventGallery = await _db.getEvents();
    notifyListeners();
  }

  void setDiaryNotes(List<Map<String, dynamic>> notes) {
    diaryNotes = List.from(notes);
    notifyListeners();
  }

  // More methods to be added as needed...
}
