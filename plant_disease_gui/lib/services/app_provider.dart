import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool isEcoModeEnabled = false;

  String getPlantContext() {
    return """
    Status da Planta: $plantStatus
    Saúde Score: $healthScore/100
    Umidade do Solo: ${sensorData['u1']?.toStringAsFixed(1) ?? '--'}%
    Temperatura: ${sensorData['t1']?.toStringAsFixed(1) ?? '--'}°C
    Luminosidade: ${sensorData['l1']?.toStringAsFixed(1) ?? '--'}%
    pH do Solo: ${sensorData['p1']?.toStringAsFixed(1) ?? '--'}
    Modo Eco: ${isEcoModeEnabled ? 'Ativo' : 'Desativado'}
    """;
  }

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

  String widgetSlot1 = 't1';
  String widgetSlot2 = 'u1';

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
      _updateWidgetData();
      notifyListeners();
    }
  }

  void _updateWidgetData() {
    if (Platform.isAndroid || Platform.isIOS) {
      HomeWidget.saveWidgetData<String>(
        'widget_status',
        "Status: $plantStatus",
      );

      final val1 = sensorData[widgetSlot1]?.toStringAsFixed(1) ?? '--';
      final val2 = sensorData[widgetSlot2]?.toStringAsFixed(1) ?? '--';

      HomeWidget.saveWidgetData<String>(
        'widget_temp',
        "${_getSensorLabel(widgetSlot1)}: $val1",
      );
      HomeWidget.saveWidgetData<String>(
        'widget_hum',
        "${_getSensorLabel(widgetSlot2)}: $val2",
      );

      HomeWidget.updateWidget(
        name: 'PlantGuardWidgetProvider',
        androidName: 'PlantGuardWidgetProvider',
      );
    } else if (Platform.isWindows) {
      // No Windows, a lógica de slots já está pronta para ser consumida pela UI
      // de configurações que unificamos no main.dart.
    }
  }

  String _getSensorLabel(String key) {
    switch (key) {
      case 'u1':
        return 'Umid';
      case 'u2':
        return 'Umid2';
      case 'l1':
        return 'Luz';
      case 'l2':
        return 'Luz2';
      case 't1':
        return 'Temp';
      case 't2':
        return 'Temp2';
      case 'p1':
        return 'pH';
      case 'ec':
        return 'EC';
      case 'water_level':
        return 'Nível';
      case 'battery':
        return 'Bat';
      default:
        return key.toUpperCase();
    }
  }

  String getSensorDisplayName(String key) {
    switch (key) {
      case 'u1':
        return 'Umidade 1';
      case 'u2':
        return 'Umidade 2';
      case 'l1':
        return 'Luz 1';
      case 'l2':
        return 'Luz 2';
      case 't1':
        return 'Temperatura 1';
      case 't2':
        return 'Temperatura 2';
      case 'p1':
        return 'pH';
      case 'ec':
        return 'Condutividade';
      case 'water_level':
        return 'Nível de Água';
      case 'battery':
        return 'Bateria';
      default:
        return key.toUpperCase();
    }
  }

  void setWidgetSlots(String slot1, String slot2) {
    widgetSlot1 = slot1;
    widgetSlot2 = slot2;
    _updateWidgetData();
    notifyListeners();
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
