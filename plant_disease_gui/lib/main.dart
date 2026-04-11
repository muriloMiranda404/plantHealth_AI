import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:nt4/nt4.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:math' as math;
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:nsd/nsd.dart';

void main() {
  runApp(const PlantGuardProApp());
}

class PlantGuardProApp extends StatefulWidget {
  const PlantGuardProApp({super.key});

  @override
  State<PlantGuardProApp> createState() => _PlantGuardProAppState();
}

class _PlantGuardProAppState extends State<PlantGuardProApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? true;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
      prefs.setBool('is_dark_mode', _themeMode == ThemeMode.dark);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PlantHealth',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: Colors.black26, width: 1.5),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Colors.black26,
          thickness: 1.5,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.greenAccent,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.05),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: Colors.white10),
          ),
        ),
      ),
      themeMode: _themeMode,
      home: MainTabController(
        onThemeToggle: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class MainTabController extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  const MainTabController({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<MainTabController> createState() => _MainTabControllerState();
}

class _MainTabControllerState extends State<MainTabController> {
  int _selectedIndex = 0;
  late NT4Client client;
  late final TextEditingController _ipController;
  bool isConnected = false;
  String raspIP = "127.0.0.1";
  bool isAiEnabled = true;
  bool isSimulationMode = false;
  Timer? _simulationTimer;

  bool isCloudMode = false;
  MqttServerClient? mqttClient;
  String mqttBroker = "broker.emqx.io";
  int mqttPort = 1883;
  String mqttTopicPrefix = "planthealth/sensor";

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NT4Topic? pumpPub;
  NT4Topic? phPub;
  NT4Topic? brightnessPub;
  NT4Topic? targetFpsPub;

  String plantStatus = "Iniciando...";
  bool hasDisease = false;
  double confidence = 0.0;

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

  Map<String, String> sensorUnits = {
    'u1': '%',
    'u2': '%',
    'l1': '%',
    'l2': '%',
    't1': '°C',
    't2': '°C',
    'p1': '',
    'p2': '',
    'ec': ' mS/cm',
    'water_level': '%',
    'battery': '%',
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
  int timerCount = 0;

  Map<String, double> _lastRawValues = {};
  Map<String, DateTime> _lastNoiseNotification = {};
  String activeGraphKey = 'u1';

  bool pumpState = false;
  double phCalibration = 0.5;

  bool isAutoPumpEnabled = false;
  String autoPumpMode = "Timer";
  double moistureThreshold = 30.0;
  int autoPumpInterval = 3600;
  int autoPumpDuration = 10;
  Timer? _autoPumpTimer;
  Timer? _autoPumpOffTimer;

  bool isEventRecordingEnabled = false;
  bool _isViewVisible = false;

  bool isMaintenanceMode = false;
  int maintenanceRemainingSeconds = 0;
  Timer? _maintenanceTimer;

  double cameraBrightness = 0.0;
  double cameraCurrentFps = 0.0;
  int cameraTargetFps = 18;
  static const List<int> _cameraFpsOptions = [10, 15, 18, 24, 30];

  bool isSystemLocked = true;
  double physicalLightIntensity = 0.0;

  Map<String, bool> sensorIntegrity = {
    'u1': true,
    'u2': true,
    'l1': true,
    'l2': true,
    't1': true,
    't2': true,
    'p1': true,
    'p2': true,
    'ec': true,
    'water_level': true,
    'battery': true,
  };
  Map<String, DateTime> lastSensorUpdate = {};

  String aiRecommendation = "Aguardando dados para análise...";
  String aiPriority = "BAIXO";
  Color aiPriorityColor = Colors.greenAccent;

  final List<String> _alerts = [];
  final bool _isStreamActive = true;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _uiRefreshTimer;
  static const Duration _uiRefreshInterval = Duration(milliseconds: 120);

  List<String> hudSensors = ['t1', 'u1', 'battery'];
  List<Map<String, dynamic>> eventGallery = [];
  List<Map<String, dynamic>> diaryNotes = [];
  List<String> comparisonSensors = [];
  Map<String, bool> simulatedFailures = {};

  @override
  void initState() {
    super.initState();
    _initDatabase();
    _startDiscovery();
    _initNotifications();
    _ipController = TextEditingController(text: raspIP);
    _loadSettings().then((_) {
      _reconnect();
    });
  }

  Database? _database;
  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'sensor_history.db');

    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE history(id INTEGER PRIMARY KEY AUTOINCREMENT, sensor_key TEXT, value REAL, timestamp INTEGER)',
        );
        await db.execute(
          'CREATE TABLE diary(id INTEGER PRIMARY KEY AUTOINCREMENT, note TEXT, timestamp INTEGER)',
        );
        await db.execute(
          'CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, path TEXT, timestamp INTEGER)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE diary(id INTEGER PRIMARY KEY AUTOINCREMENT, note TEXT, timestamp INTEGER)',
          );
          await db.execute(
            'CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, path TEXT, timestamp INTEGER)',
          );
        }
      },
    );

    _loadHistoryFromDb();
    _loadDiaryFromDb();
    _loadEventsFromDb();
  }

  Future<void> _loadHistoryFromDb() async {
    if (_database == null) return;
    final List<Map<String, dynamic>> maps = await _database!.query(
      'history',
      orderBy: 'timestamp DESC',
      limit: 500,
    );

    setState(() {
      for (var map in maps) {
        final key = map['sensor_key'] as String;
        if (histories.containsKey(key)) {
          histories[key]!.insert(
            0,
            FlSpot(map['timestamp'].toDouble(), map['value'] as double),
          );
        }
      }
    });
  }

  Future<void> _loadDiaryFromDb() async {
    if (_database == null) return;
    final List<Map<String, dynamic>> maps = await _database!.query(
      'diary',
      orderBy: 'timestamp DESC',
    );
    setState(() {
      diaryNotes = List.from(maps);
    });
  }

  Future<void> _loadEventsFromDb() async {
    if (_database == null) return;
    final List<Map<String, dynamic>> maps = await _database!.query(
      'events',
      orderBy: 'timestamp DESC',
      limit: 50,
    );
    setState(() {
      eventGallery = List.from(maps);
    });
  }

  Future<void> _addDiaryNote(String note) async {
    if (_database == null) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _database!.insert('diary', {'note': note, 'timestamp': timestamp});
    _loadDiaryFromDb();
  }

  Future<void> _addEvent(String type, String path) async {
    if (_database == null) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _database!.insert('events', {
      'type': type,
      'path': path,
      'timestamp': timestamp,
    });
    _loadEventsFromDb();
  }

  Future<void> _saveToDb(String key, double value) async {
    if (_database == null) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _database!.insert('history', {
      'sensor_key': key,
      'value': value,
      'timestamp': timestamp,
    });
  }

  Future<void> _clearDatabase() async {
    if (_database == null) return;
    await _database!.delete('history');
    _resetHistories();
    _addAlert("Banco de dados local limpo com sucesso");
  }

  Future<void> _startDiscovery() async {
    final discovery = await startDiscovery('_http._tcp');
    discovery.addListener(() {
      for (final service in discovery.services) {
        if (service.name != null && service.name!.contains('raspberry')) {
          final host = service.host;
          if (host != null && host != raspIP) {
            _addAlert("Raspberry encontrada via mDNS: $host");
            setState(() {
              raspIP = host;
              _ipController.text = host;
            });
            _reconnect();
            stopDiscovery(discovery);
            break;
          }
        }
      }
    });
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'plant_health_alerts',
          'Alertas de Saúde',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      math.Random().nextInt(1000),
      title,
      body,
      platformChannelSpecifics,
    );
  }

  void _reconnect() {
    if (isCloudMode) {
      _setupMQTT();
    } else {
      _setupNT4();
    }
  }

  double _processSensorValue(String key, double newValue) {
    if (_lastRawValues.containsKey(key)) {
      final lastVal = _lastRawValues[key]!;
      final diff = (newValue - lastVal).abs();

      double threshold = 15.0;
      if (key.startsWith('t')) threshold = 5.0;
      if (key.startsWith('p')) threshold = 1.0;

      if (diff > threshold) {
        final now = DateTime.now();
        final lastNotif = _lastNoiseNotification[key];
        if (lastNotif == null || now.difference(lastNotif).inSeconds > 30) {
          _lastNoiseNotification[key] = now;
          _showNotification(
            "Ruído Detectado",
            "Sensor ${_getSensorConfig(key).name} oscilando. Verifique conexões.",
          );
          _addAlert(
            "ALERTA: Ruído excessivo no sensor ${_getSensorConfig(key).name}",
          );
        }
        return (lastVal * 0.8) + (newValue * 0.2);
      }
    }
    _lastRawValues[key] = newValue;
    return newValue;
  }

  String _analyzeCorrelations() {
    List<String> correlations = [];

    double l1 = sensorData['l1'] ?? 0;
    double l2 = sensorData['l2'] ?? 0;
    double t1 = sensorData['t1'] ?? 25;
    double t2 = sensorData['t2'] ?? 25;
    double avgLux = (l1 + l2) / 2;
    double avgTemp = (t1 + t2) / 2;

    if (avgLux > 600 && avgTemp > 30) {
      correlations.add("Alta radiação solar elevando temperatura ambiente.");
    } else if (avgLux < 100 && avgTemp < 20) {
      correlations.add(
        "Baixa atividade fotossintética e resfriamento noturno.",
      );
    }

    double u1 = sensorData['u1'] ?? 50;
    double u2 = sensorData['u2'] ?? 50;
    double avgSoil = (u1 + u2) / 2;
    if (avgSoil > 80 && avgTemp < 15) {
      correlations.add("Risco de apodrecimento de raízes: Solo úmido e frio.");
    }

    return correlations.isEmpty
        ? "Sem correlações anômalas detectadas no momento."
        : correlations.join("\n");
  }

  void _showHealthDiagnosis() {
    String diagnostic = "DIAGNÓSTICO DE SAÚDE DA PLANTA\n";
    diagnostic += "--------------------------------\n\n";

    diagnostic +=
        "ESTADO GERAL: ${hasDisease ? 'Atenção (Doença Detectada)' : 'Saudável'}\n";
    diagnostic +=
        "Confiança da IA: ${(confidence * 100).toStringAsFixed(1)}%\n\n";

    List<String> criticals = [];
    sensorData.forEach((key, val) {
      if (key == 'water_level' && val < 20) {
        criticals.add("- Reservatório de água crítico ($val%)");
      }
      if (key == 'battery' && val < 15) {
        criticals.add("- Bateria do sistema baixa ($val%)");
      }
      if (key.startsWith('u') && val < 20) {
        criticals.add("- Umidade do solo muito baixa ($val%)");
      }
    });

    if (criticals.isNotEmpty) {
      diagnostic += "ALERTAS CRÍTICOS:\n${criticals.join('\n')}\n\n";
    }

    diagnostic += "CORRELAÇÕES E INSIGHTS:\n${_analyzeCorrelations()}\n\n";

    diagnostic +=
        "RECOMENDAÇÃO: ${aiRecommendation.isEmpty ? 'Mantenha o monitoramento atual.' : aiRecommendation}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.green),
            SizedBox(width: 10),
            Text("Diagnóstico de Saúde"),
          ],
        ),
        content: SingleChildScrollView(child: Text(diagnostic)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FECHAR"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generateReport();
            },
            child: const Text("EXPORTAR CSV"),
          ),
        ],
      ),
    );
  }

  void _toggleMaintenanceMode(bool enable, {int minutes = 30}) {
    _maintenanceTimer?.cancel();
    if (enable) {
      setState(() {
        isMaintenanceMode = true;
        maintenanceRemainingSeconds = minutes * 60;
      });
      _addAlert("Modo Manutenção: Ativado por $minutes minutos");

      _maintenanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (maintenanceRemainingSeconds > 0) {
          setState(() {
            maintenanceRemainingSeconds--;
          });
        } else {
          _toggleMaintenanceMode(false);
        }
      });
    } else {
      setState(() {
        isMaintenanceMode = false;
        maintenanceRemainingSeconds = 0;
      });
      _addAlert("Modo Manutenção: Desativado");
    }
  }

  void _sendCommand(String topicSuffix, dynamic value) {
    if (isCloudMode) {
      if (mqttClient?.connectionStatus?.state ==
          MqttConnectionState.connected) {
        final builder = MqttClientPayloadBuilder();
        builder.addString(value.toString());
        mqttClient!.publishMessage(
          "$mqttTopicPrefix/cmd/$topicSuffix",
          MqttQos.atLeastOnce,
          builder.payload!,
        );
      }
    } else {
      if (topicSuffix == 'pump' && pumpPub != null) {
        client.addSample(pumpPub!, value);
      } else if (topicSuffix == 'ph' && phPub != null) {
        client.addSample(phPub!, value);
      } else if (topicSuffix == 'brightness' && brightnessPub != null) {
        client.addSample(brightnessPub!, value);
      } else if (topicSuffix == 'fps' && targetFpsPub != null) {
        client.addSample(targetFpsPub!, value);
      }
    }
  }

  void _captureManualPhoto() {
    _sendCommand('take_photo', 'now');
    _addAlert("Comando enviado: Capturar Foto");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Solicitando foto à Raspberry Pi...")),
    );
  }

  void _startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isSimulationMode) {
        timer.cancel();
        return;
      }
      setState(() {
        final random = math.Random();
        sensorData.forEach((key, value) {
          double newVal;
          switch (key) {
            case 'u1':
              newVal = 60.0 + random.nextDouble() * 20.0;
              break;
            case 'u2':
              newVal = 55.0 + random.nextDouble() * 20.0;
              break;
            case 'l1':
              newVal = 300.0 + random.nextDouble() * 100.0;
              break;
            case 'l2':
              newVal = 310.0 + random.nextDouble() * 100.0;
              break;
            case 't1':
              newVal = 24.0 + random.nextDouble() * 4.0;
              break;
            case 't2':
              newVal = 23.0 + random.nextDouble() * 4.0;
              break;
            case 'p1':
              newVal = 6.2 + random.nextDouble() * 0.6;
              break;
            case 'p2':
              newVal = 6.1 + random.nextDouble() * 0.6;
              break;
            case 'ec':
              newVal = 1.2 + random.nextDouble() * 0.6;
              break;
            case 'water_level':
              newVal = 85.0 + random.nextDouble() * 10.0;
              break;
            case 'battery':
              newVal = 92.0 + random.nextDouble() * 8.0;
              break;
            default:
              newVal = random.nextDouble() * 100.0;
          }
          final val = _processSensorValue(key, newVal);
          sensorData[key] = val;
          lastSensorUpdate[key] = DateTime.now();
          _updateHistory(key, val);

          if (!(simulatedFailures[key] ?? false)) {
            sensorIntegrity[key] = true;
          }
        });

        if (random.nextDouble() > 0.98) {
          _showNotification(
            "Alerta de Simulação",
            "Anomalia detectada nos sensores simulados.",
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _autoPumpTimer?.cancel();
    _autoPumpOffTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _ipController.dispose();
    super.dispose();
  }

  void _scheduleUiRefresh({Set<int>? visibleTabs}) {
    if (!mounted) return;
    if (visibleTabs != null && !visibleTabs.contains(_selectedIndex)) return;
    if (_uiRefreshTimer?.isActive ?? false) return;

    _uiRefreshTimer = Timer(_uiRefreshInterval, () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _clearSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    mqttClient?.disconnect();
  }

  void _addAlert(String message) {
    final time = DateTime.now();
    final timestamp = "${time.hour}:${time.minute}:${time.second}";
    _alerts.insert(0, "[$timestamp] $message");
    if (_alerts.length > 20) _alerts.removeLast();
    _scheduleUiRefresh(visibleTabs: {0});
  }

  void _runAiRecommendation() {
    if (isMaintenanceMode) return;
    String problem = "";
    String cause = "";
    String action = "";
    String priority = "BAIXO";
    Color color = Colors.greenAccent;

    double ph = sensorData['p1'] ?? 7.0;
    double ec = sensorData['ec'] ?? 1.5;
    double temp = sensorData['t1'] ?? 25.0;
    double water = sensorData['water_level'] ?? 100.0;
    double battery = sensorData['battery'] ?? 100.0;
    double lux = (sensorData['l1'] ?? 0) + (sensorData['l2'] ?? 0);

    if (water < 20) {
      problem = "Nível de água baixo";
      cause = "Consumo ou evaporação";
      action = "Repor reservatório imediatamente";
      priority = "CRÍTICO";
      color = Colors.redAccent;
      _showNotification(
        "Alerta de Água",
        "O nível de água está em ${water.toStringAsFixed(1)}%!",
      );
      if (isEventRecordingEnabled) {
        _sendCommand('record_event', 'water_low');
      }
    } else if (ph < 5.5 || ph > 6.5) {
      problem = "pH fora do ideal ($ph)";
      cause = "Desequilíbrio químico";
      action = "Corrigir solução nutritiva";
      priority = "CRÍTICO";
      color = Colors.redAccent;
      _showNotification("Alerta de pH", "O pH está fora da faixa ideal: $ph");
      if (isEventRecordingEnabled) {
        _sendCommand('record_event', 'ph_anomaly');
      }
    } else if (ec > 2.5) {
      problem = "EC muito alta ($ec)";
      cause = "Excesso de nutrientes";
      action = "Diluir solução com água pura";
      priority = "MÉDIO";
      color = Colors.orangeAccent;
    } else if (battery < 15) {
      problem = "Bateria baixa";
      cause = "Falta de carga";
      action = "Recarregar ou trocar fonte";
      priority = "CRÍTICO";
      color = Colors.redAccent;
    } else if (temp > 30) {
      problem = "Temperatura alta ($temp°C)";
      cause = "Ambiente ou radiação";
      action = "Resfriar ou ventilar área";
      priority = "MÉDIO";
      color = Colors.orangeAccent;
    } else if (lux > 180) {
      problem = "Luz excessiva";
      cause = "Exposição direta ou tempo";
      action = "Reduzir intensidade/tempo";
      priority = "MÉDIO";
      color = Colors.orangeAccent;
    } else {
      problem = "Nenhum problema detectado";
      cause = "Sistema estável";
      action = "Manter monitoramento";
      priority = "BAIXO";
      color = Colors.greenAccent;
    }

    aiRecommendation =
        "Problema: $problem\nCausa: $cause\nAção recomendada: $action";
    aiPriority = priority;
    aiPriorityColor = color;
  }

  Future<void> _generateReport() async {
    List<List<dynamic>> rows = [];
    rows.add(["Timestamp", "Sensor", "Valor", "Unidade"]);

    sensorData.forEach((key, value) {
      final config = _getSensorConfig(key);
      rows.add([DateTime.now().toString(), config.name, value, config.unit]);
    });

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path =
        "${directory.path}/relatorio_plantas_${DateTime.now().millisecondsSinceEpoch}.csv";
    final file = File(path);
    await file.writeAsString(csv);

    await Share.shareXFiles([
      XFile(path),
    ], text: 'Relatório de Monitoramento de Plantas');
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('rasp_ip') ?? "127.0.0.1";
    final savedPh = prefs.getDouble('ph_calib') ?? 0.5;
    final savedBrightness = prefs.getDouble('camera_brightness') ?? 0.0;
    final savedTargetFps = prefs.getInt('camera_target_fps') ?? 18;
    final savedAiEnabled = prefs.getBool('ai_enabled') ?? true;
    final savedCloudMode = prefs.getBool('cloud_mode') ?? false;
    final savedMqttBroker = prefs.getString('mqtt_broker') ?? "broker.emqx.io";
    final savedMqttPort = prefs.getInt('mqtt_port') ?? 1883;
    final savedMqttTopic =
        prefs.getString('mqtt_topic') ?? "planthealth/sensor";

    final savedAutoPumpEnabled = prefs.getBool('auto_pump_enabled') ?? false;
    final savedAutoPumpMode = prefs.getString('auto_pump_mode') ?? "Timer";
    final savedMoistureThreshold =
        prefs.getDouble('moisture_threshold') ?? 30.0;
    final savedAutoPumpInterval = prefs.getInt('auto_pump_interval') ?? 3600;
    final savedAutoPumpDuration = prefs.getInt('auto_pump_duration') ?? 10;
    final savedEventRecording = prefs.getBool('event_recording') ?? false;

    _ipController.text = savedIp;
    setState(() {
      raspIP = savedIp;
      phCalibration = savedPh;
      cameraBrightness = savedBrightness;
      cameraTargetFps = _cameraFpsOptions.contains(savedTargetFps)
          ? savedTargetFps
          : _cameraFpsOptions.first;
      isAiEnabled = savedAiEnabled;
      isCloudMode = savedCloudMode;
      mqttBroker = savedMqttBroker;
      mqttPort = savedMqttPort;
      mqttTopicPrefix = savedMqttTopic;

      isAutoPumpEnabled = savedAutoPumpEnabled;
      autoPumpMode = savedAutoPumpMode;
      moistureThreshold = savedMoistureThreshold;
      autoPumpInterval = savedAutoPumpInterval;
      autoPumpDuration = savedAutoPumpDuration;
      isEventRecordingEnabled = savedEventRecording;

      if (isAutoPumpEnabled) {
        _startAutoPump();
      }

      sensorUnits.forEach((key, defaultValue) {
        sensorUnits[key] = prefs.getString('unit_$key') ?? defaultValue;
      });
    });

    if (phPub != null) {
      client.addSample(phPub!, phCalibration);
    }
    if (brightnessPub != null) {
      client.addSample(brightnessPub!, cameraBrightness);
    }
    if (targetFpsPub != null) {
      client.addSample(targetFpsPub!, cameraTargetFps);
    }
  }

  Future<void> _setupMQTT() async {
    _clearSubscriptions();
    _setupSensorIntegrityCheck();

    final clientId = 'PlantHealth_App_${math.Random().nextInt(100)}';
    mqttClient = MqttServerClient(mqttBroker, clientId);
    mqttClient!.port = mqttPort;
    mqttClient!.keepAlivePeriod = 20;
    mqttClient!.autoReconnect = true;
    mqttClient!.onDisconnected = () {
      if (mounted) setState(() => isConnected = false);
      _addAlert("MQTT: Desconectado. Tentando reconectar...");
    };
    mqttClient!.onConnected = () {
      if (mounted) setState(() => isConnected = true);
      _addAlert("MQTT: Conectado com sucesso");

      sensorData.keys.forEach((key) {
        final topic = "$mqttTopicPrefix/$key";
        mqttClient!.subscribe(topic, MqttQos.atMostOnce);
      });
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    mqttClient!.connectionMessage = connMessage;

    try {
      await mqttClient!.connect();

      mqttClient!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        final topic = c[0].topic;
        final sensorKey = topic.split('/').last;

        if (sensorData.containsKey(sensorKey)) {
          final rawVal = double.tryParse(pt) ?? 0.0;
          final val = _processSensorValue(sensorKey, rawVal);
          if (mounted) {
            setState(() {
              sensorData[sensorKey] = val;
              lastSensorUpdate[sensorKey] = DateTime.now();
              _updateHistory(sensorKey, val);

              if (!(simulatedFailures[sensorKey] ?? false)) {
                sensorIntegrity[sensorKey] = true;
              }
            });
            _saveToDb(sensorKey, val);
            _runAiRecommendation();
            _checkMoistureIrrigation();
            _scheduleUiRefresh(visibleTabs: {0, 1});
          }
        }
      });
    } catch (e) {
      _addAlert("Erro MQTT: $e");
      mqttClient!.disconnect();
    }
  }

  void _setupSensorIntegrityCheck() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !isConnected) return;

      final now = DateTime.now();
      bool changed = false;

      sensorData.forEach((key, _) {
        final lastUpdate = lastSensorUpdate[key];
        final bool isHealthy =
            (lastUpdate != null && now.difference(lastUpdate).inSeconds < 10) &&
            !(simulatedFailures[key] ?? false);

        if (sensorIntegrity[key] != isHealthy) {
          sensorIntegrity[key] = isHealthy;
          changed = true;
          if (!isHealthy) {
            final config = _getSensorConfig(key);
            _addAlert("ERRO: Sensor ${config.name} desconectado!");
          }
        }
      });

      if (changed) {
        _scheduleUiRefresh(visibleTabs: {0, 1});
      }
    });
  }

  void _updateHistory(String key, double val) {
    if (!histories.containsKey(key)) return;
    final history = histories[key]!;

    history.add(FlSpot(timerCount.toDouble(), val));

    if (history.length > 50) {
      history.removeAt(0);
    }

    if (key == activeGraphKey) {
      timerCount++;
    }
  }

  void _startAutoPump() {
    _autoPumpTimer?.cancel();
    if (!isAutoPumpEnabled || autoPumpMode != "Timer") return;

    _autoPumpTimer = Timer.periodic(Duration(seconds: autoPumpInterval), (
      timer,
    ) {
      _triggerPump("Irrigação por Timer");
    });
  }

  void _checkMoistureIrrigation() {
    if (!isAutoPumpEnabled || autoPumpMode != "Sensor") return;

    double u1 = sensorData['u1'] ?? 100.0;
    double u2 = sensorData['u2'] ?? 100.0;
    double avgMoisture = (u1 + u2) / 2;

    if (avgMoisture < moistureThreshold && !pumpState) {
      _triggerPump(
        "Irrigação por Sensor (Umidade: ${avgMoisture.toStringAsFixed(1)}%)",
      );
    }
  }

  void _triggerPump(String reason) {
    if (isMaintenanceMode) {
      _addAlert("Irrigação Ignorada: Modo Manutenção Ativo");
      return;
    }
    if (mounted) {
      setState(() {
        pumpState = true;
        _sendCommand('pump', true);
      });
      _addAlert("$reason: Bomba ligada");

      _autoPumpOffTimer?.cancel();
      _autoPumpOffTimer = Timer(Duration(seconds: autoPumpDuration), () {
        if (mounted) {
          setState(() {
            pumpState = false;
            _sendCommand('pump', false);
          });
          _addAlert("$reason: Bomba desligada");
        }
      });
    }
  }

  void _showComparisonDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Comparativo de Sensores"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: sensorData.keys.map((key) {
                final cfg = _getSensorConfig(key);
                final isSelected = comparisonSensors.contains(key);
                return CheckboxListTile(
                  title: Text(cfg.name),
                  secondary: Icon(cfg.icon, color: cfg.color, size: 20),
                  value: isSelected,
                  onChanged: (val) {
                    setDialogState(() {
                      setState(() {
                        if (val == true) {
                          if (!comparisonSensors.contains(key)) {
                            comparisonSensors.add(key);
                          }
                        } else {
                          comparisonSensors.remove(key);
                        }
                      });
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => comparisonSensors.clear());
                Navigator.pop(context);
              },
              child: const Text("LIMPAR"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullscreenChart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("Análise em Tela Cheia")),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: LineChart(
              _getChartData(
                comparisonSensors.isEmpty
                    ? [
                        histories[activeGraphKey]!
                            .map(
                              (spot) => FlSpot(
                                spot.x,
                                _convertValue(
                                  activeGraphKey,
                                  spot.y,
                                  sensorUnits[activeGraphKey]!,
                                ),
                              ),
                            )
                            .toList(),
                      ]
                    : comparisonSensors
                          .map(
                            (k) => histories[k]!
                                .map(
                                  (spot) => FlSpot(
                                    spot.x,
                                    _convertValue(k, spot.y, sensorUnits[k]!),
                                  ),
                                )
                                .toList(),
                          )
                          .toList(),
                comparisonSensors.isEmpty
                    ? [_getSensorConfig(activeGraphKey).color]
                    : comparisonSensors
                          .map((k) => _getSensorConfig(k).color)
                          .toList(),
                comparisonSensors.isEmpty
                    ? [activeGraphKey]
                    : comparisonSensors,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDiaryListDialog() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Text("Diário Completo", style: TextStyle(color: textColor)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: diaryNotes.isEmpty
              ? Center(
                  child: Text(
                    "Nenhum registro ainda.",
                    style: TextStyle(color: subTextColor),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: diaryNotes.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final note = diaryNotes[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      note['timestamp'] as int,
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        note['note'],
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(color: subTextColor, fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FECHAR"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showAddDiaryDialog();
            },
            child: const Text("ADICIONAR"),
          ),
        ],
      ),
    );
  }

  void _showAddDiaryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nova Nota no Diário"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Ex: Adicionei fertilizante hoje",
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addDiaryNote(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("SALVAR"),
          ),
        ],
      ),
    );
  }

  void _showFailureSimulatorDialog() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.redAccent),
              const SizedBox(width: 10),
              Text(
                "Simulador de Falhas",
                style: TextStyle(color: textColor, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Selecione os sensores para simular desconexão ou erro de hardware:",
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 15),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: sensorData.keys.map((key) {
                      final cfg = _getSensorConfig(key);
                      final isFailed = simulatedFailures[key] ?? false;
                      return SwitchListTile(
                        title: Text(
                          cfg.name,
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        secondary: Icon(
                          cfg.icon,
                          color: isFailed ? Colors.red : cfg.color,
                          size: 20,
                        ),
                        value: isFailed,
                        activeColor: Colors.red,
                        onChanged: (val) {
                          setDialogState(() {
                            setState(() {
                              simulatedFailures[key] = val;
                              if (val) {
                                sensorIntegrity[key] = false;
                                _addAlert(
                                  "SIMULAÇÃO: Sensor ${cfg.name} falhou!",
                                );
                              } else {
                                final lastUpdate = lastSensorUpdate[key];
                                final bool isHealthy =
                                    isSimulationMode ||
                                    (lastUpdate != null &&
                                        DateTime.now()
                                                .difference(lastUpdate)
                                                .inSeconds <
                                            10);
                                sensorIntegrity[key] = isHealthy;
                                if (isHealthy) {
                                  _addAlert(
                                    "SIMULAÇÃO: Sensor ${cfg.name} restaurado.",
                                  );
                                }
                              }
                              _scheduleUiRefresh();
                            });
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  simulatedFailures.clear();
                  sensorData.keys.forEach((key) {
                    final lastUpdate = lastSensorUpdate[key];
                    final bool isHealthy =
                        isSimulationMode ||
                        (lastUpdate != null &&
                            DateTime.now().difference(lastUpdate).inSeconds <
                                10);
                    sensorIntegrity[key] = isHealthy;
                  });
                  _scheduleUiRefresh();
                });
                Navigator.pop(context);
              },
              child: const Text(
                "LIMPAR TUDO",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CONCLUIR"),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnitsConfigDialog() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
              title: Text(
                'Configurar Unidades',
                style: TextStyle(color: textColor),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: sensorUnits.keys.map((key) {
                    final cfg = _getSensorConfig(key);
                    final List<String> options = _getUnitOptions(key);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(cfg.icon, color: cfg.color, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                cfg.name,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          DropdownButton<String>(
                            value: options.contains(sensorUnits[key])
                                ? sensorUnits[key]
                                : options.first,
                            dropdownColor: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            style: TextStyle(color: textColor),
                            items: options.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value.isEmpty ? "Nenhuma" : value),
                              );
                            }).toList(),
                            onChanged: (newValue) async {
                              if (newValue != null) {
                                setDialogState(() {
                                  setState(() {
                                    sensorUnits[key] = newValue;
                                  });
                                });
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString('unit_$key', newValue);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'FECHAR',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _getUnitOptions(String key) {
    switch (key) {
      case 't1':
      case 't2':
        return ['°C', '°F', 'K'];
      case 'u1':
      case 'u2':
      case 'l1':
      case 'l2':
      case 'water_level':
      case 'battery':
        return ['%', 'raw'];
      case 'p1':
      case 'p2':
        return ['', 'raw'];
      case 'ec':
        return [' mS/cm', 'raw'];
      default:
        return ['raw'];
    }
  }

  double _convertValue(String key, double value, String unit) {
    if (unit == 'raw') return value;

    switch (key) {
      case 't1':
      case 't2':
        if (unit == '°F') return (value * 9 / 5) + 32;
        if (unit == 'K') return value + 273.15;
        return value;
      case 'battery':
      case 'water_level':
      case 'u1':
      case 'u2':
      case 'l1':
      case 'l2':
        return value;
      default:
        return value;
    }
  }

  double _getDisplayValue(String key) {
    double rawValue = sensorData[key] ?? 0.0;
    String unit = sensorUnits[key] ?? '';
    return _convertValue(key, rawValue, unit);
  }

  void _resetHistories() {
    setState(() {
      histories.forEach((key, value) {
        value.clear();
      });
      timerCount = 0;
    });
    _addAlert("Gráficos resetados com sucesso");
  }

  void _showMqttConfigDialog() {
    final brokerController = TextEditingController(text: mqttBroker);
    final portController = TextEditingController(text: mqttPort.toString());
    final topicController = TextEditingController(text: mqttTopicPrefix);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Configurar Nuvem (MQTT)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: brokerController,
              decoration: const InputDecoration(
                labelText: "Broker (ex: broker.emqx.io)",
              ),
            ),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Porta (ex: 1883)"),
            ),
            TextField(
              controller: topicController,
              decoration: const InputDecoration(labelText: "Prefixo do Tópico"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                mqttBroker = brokerController.text;
                mqttPort = int.tryParse(portController.text) ?? 1883;
                mqttTopicPrefix = topicController.text;
              });
              await prefs.setString('mqtt_broker', mqttBroker);
              await prefs.setInt('mqtt_port', mqttPort);
              await prefs.setString('mqtt_topic', mqttTopicPrefix);
              Navigator.pop(context);
              _setupMQTT();
            },
            child: const Text("Salvar e Conectar"),
          ),
        ],
      ),
    );
  }

  void _setupNT4() {
    _clearSubscriptions();
    _setupSensorIntegrityCheck();

    client = NT4Client(
      serverBaseAddress: raspIP,
      onConnect: () {
        if (isConnected) return;
        setState(() => isConnected = true);
        pumpPub = client.publishNewTopic(
          '/SmartDashboard/CmdPump',
          NT4TypeStr.typeBool,
        );
        phPub = client.publishNewTopic(
          '/SmartDashboard/PH_Offset',
          NT4TypeStr.typeFloat64,
        );
        brightnessPub = client.publishNewTopic(
          '/SmartDashboard/CameraBrightness',
          NT4TypeStr.typeFloat64,
        );
        targetFpsPub = client.publishNewTopic(
          '/SmartDashboard/CameraTargetFPS',
          NT4TypeStr.typeFloat64,
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (pumpPub != null) client.addSample(pumpPub!, pumpState);
          if (phPub != null) client.addSample(phPub!, phCalibration);
          if (brightnessPub != null) {
            client.addSample(brightnessPub!, cameraBrightness);
          }
          if (targetFpsPub != null) {
            client.addSample(targetFpsPub!, cameraTargetFps);
          }
        });
      },
      onDisconnect: () {
        if (!isConnected) return;
        setState(() => isConnected = false);
      },
    );

    const opt = NT4SubscriptionOptions();

    _subscriptions.add(
      client.subscribe('/SmartDashboard/PlantStatus', opt).stream().listen((v) {
        final newStatus = v.toString();
        if (plantStatus == newStatus) return;
        plantStatus = newStatus;
        _scheduleUiRefresh(visibleTabs: {0});
      }),
    );
    _subscriptions.add(
      client.subscribe('/SmartDashboard/DiseaseDetected', opt).stream().listen((
        v,
      ) {
        final detected = v as bool;
        if (detected && !hasDisease) {
          _addAlert("ALERTA: $plantStatus");
        }
        if (hasDisease == detected) return;
        hasDisease = detected;
        _scheduleUiRefresh(visibleTabs: {0});
      }),
    );
    _subscriptions.add(
      client.subscribe('/SmartDashboard/Confidence', opt).stream().listen((v) {
        confidence = (v as num).toDouble();
      }),
    );
    _subscriptions.add(
      client.subscribe('/SmartDashboard/CameraFPS', opt).stream().listen((v) {
        final newFps = (v as num).toDouble();
        if ((cameraCurrentFps - newFps).abs() < 0.1) return;
        cameraCurrentFps = newFps;
        _scheduleUiRefresh(visibleTabs: {0});
      }),
    );
    _subscriptions.add(
      client.subscribe('/SmartDashboard/Locked', opt).stream().listen((v) {
        if (v == null) return;
        final newLocked = v as bool;
        if (isSystemLocked == newLocked) return;
        isSystemLocked = newLocked;
        _scheduleUiRefresh(visibleTabs: {0, 2});
      }),
    );
    _subscriptions.add(
      client.subscribe('/SmartDashboard/LightInt', opt).stream().listen((v) {
        if (v == null) return;
        final newInt = (v as num).toDouble();
        if ((physicalLightIntensity - newInt).abs() < 1.0) return;
        physicalLightIntensity = newInt;
        _scheduleUiRefresh(visibleTabs: {0, 2});
      }),
    );

    final List<Map<String, String>> sensorConfigs = [
      {'topic': 'Umid1', 'key': 'u1'},
      {'topic': 'Umid2', 'key': 'u2'},
      {'topic': 'Luz1', 'key': 'l1'},
      {'topic': 'Luz2', 'key': 'l2'},
      {'topic': 'Temp1', 'key': 't1'},
      {'topic': 'Temp2', 'key': 't2'},
      {'topic': 'PH1', 'key': 'p1'},
      {'topic': 'PH2', 'key': 'p2'},
      {'topic': 'EC', 'key': 'ec'},
      {'topic': 'WaterLevel', 'key': 'water_level'},
      {'topic': 'Battery', 'key': 'battery'},
    ];

    for (var s in sensorConfigs) {
      _subscriptions.add(
        client.subscribe('/SmartDashboard/${s['topic']}', opt).stream().listen((
          v,
        ) {
          if (v == null) return;

          final key = s['key']!;
          final val = (v as num).toDouble();

          setState(() {
            sensorData[key] = val;
            lastSensorUpdate[key] = DateTime.now();
            _updateHistory(key, val);
          });
          _saveToDb(key, val);

          _runAiRecommendation();
          _checkMoistureIrrigation();
          _scheduleUiRefresh(visibleTabs: {0, 1});
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF0A0A0A)
              : Colors.white,
          selectedItemColor: Colors.green,
          unselectedItemColor: widget.isDarkMode
              ? Colors.white24
              : Colors.black26,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.remove_red_eye_outlined),
              activeIcon: Icon(Icons.remove_red_eye),
              label: 'Visão',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.query_stats),
              activeIcon: Icon(Icons.insights),
              label: 'Gráficos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_input_component),
              activeIcon: Icon(Icons.settings_input_component),
              label: 'Ações',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune),
              activeIcon: Icon(Icons.tune),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
      body: _buildCurrentTab(),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildMonitorTab();
      case 1:
        return _buildAnalyticsTab();
      case 2:
        return _buildControlTab();
      case 3:
        return _buildSettingsTab();
      default:
        return Container();
    }
  }

  Widget _buildMonitorTab() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    if (!_isViewVisible) {
      Future.delayed(
        Duration.zero,
        () => setState(() => _isViewVisible = true),
      );
    }

    return _TabScaffold(
      title: "IA Real-Time",
      child: ListView(
        children: [
          _buildInteractiveCard(
            height: isAiEnabled ? 250 : 350,
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_selectedIndex == 0)
                      Mjpeg(
                        isLive: _isStreamActive && _selectedIndex == 0,
                        error: (context, error, stack) => Center(
                          child: Text(
                            "Câmera Offline\n(Inicie o detection_service.py)",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        stream: "http://$raspIP:5000/video_feed",
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.red, size: 12),
                            Text(
                              " LIVE",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildEventGallery(),
          const SizedBox(height: 15),
          _buildInteractiveCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "FPS da Câmera",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Atual: ${cameraCurrentFps.toStringAsFixed(1)} FPS",
                          style: TextStyle(
                            color: isDark ? Colors.greenAccent : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Alvo: $cameraTargetFps FPS",
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _cameraFpsOptions.contains(cameraTargetFps)
                            ? cameraTargetFps
                            : _cameraFpsOptions.first,
                        dropdownColor: isDark
                            ? const Color(0xFF121212)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        style: TextStyle(color: textColor),
                        iconEnabledColor: isDark
                            ? Colors.greenAccent
                            : Colors.green,
                        items: _cameraFpsOptions
                            .map(
                              (fps) => DropdownMenuItem<int>(
                                value: fps,
                                child: Text("$fps FPS"),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null || value == cameraTargetFps) return;
                          setState(() => cameraTargetFps = value);
                          _sendCommand('fps', value);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setInt('camera_target_fps', value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildQuickTelemetrySection(),
          const SizedBox(height: 15),
          _buildInteractiveCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.light_mode, color: Colors.amberAccent),
                      const SizedBox(width: 12),
                      Text(
                        "Luminosidade da Câmera",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        cameraBrightness.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    min: -80,
                    max: 80,
                    divisions: 16,
                    value: cameraBrightness,
                    activeColor: Colors.amberAccent,
                    label: cameraBrightness.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() => cameraBrightness = value);
                      _sendCommand('brightness', value);
                    },
                    onChangeEnd: (value) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('camera_brightness', value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildInteractiveCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    isSystemLocked ? Icons.lock_outline : Icons.lock_open,
                    color: isSystemLocked ? Colors.redAccent : Colors.green,
                    size: 30,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSystemLocked
                              ? "Controle Físico Bloqueado"
                              : "Controle Físico Liberado",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          isSystemLocked
                              ? "Aproxime o cartão RFID para liberar"
                              : "Use o potenciômetro para ajustar a luz",
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!isSystemLocked)
                    Column(
                      children: [
                        Text(
                          "Luz Física",
                          style: TextStyle(fontSize: 10, color: subTextColor),
                        ),
                        Text(
                          "${physicalLightIntensity.toStringAsFixed(0)}%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            isAiEnabled
                ? "DIAGNÓSTICO RASPBERRY PI (IA)"
                : "DIAGNÓSTICO ARDUINO (SENSORES)",
            style: TextStyle(
              fontSize: 10,
              color: subTextColor.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _buildInteractiveCard(
            height: 220,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDynamicGlowIcon(),
                const SizedBox(height: 15),
                Text(
                  _getDynamicStatus().toUpperCase(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                _buildDynamicStatusBadge(),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "RECOMENDAÇÃO INTELIGENTE",
            style: TextStyle(
              fontSize: 10,
              color: subTextColor.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _buildInteractiveCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.psychology, color: Colors.blueAccent),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getDynamicPriorityColor().withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getDynamicPriorityColor().withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          _getDynamicPriority(),
                          style: TextStyle(
                            color: _getDynamicPriorityColor(),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getDynamicRecommendation(),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "LOG DE ALERTAS",
            style: TextStyle(
              fontSize: 10,
              color: subTextColor.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _buildInteractiveCard(
            height: 150,
            child: _getDynamicAlerts().isEmpty
                ? Center(
                    child: Text(
                      "Nenhum alerta recente",
                      style: TextStyle(color: subTextColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: _getDynamicAlerts().length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _getDynamicAlerts()[index],
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final config = _getSensorConfig(activeGraphKey);
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return _TabScaffold(
      title: "Telemetria",
      actions: [
        IconButton(
          icon: const Icon(Icons.compare_arrows),
          onPressed: _showComparisonDialog,
          tooltip: "Comparar Sensores",
        ),
        IconButton(
          icon: const Icon(Icons.settings_suggest),
          onPressed: _showUnitsConfigDialog,
          tooltip: "Configurar Unidades",
        ),
      ],
      child: ListView(
        children: [
          _buildInteractiveCard(
            height: 240,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        comparisonSensors.isEmpty ? config.name : "Comparativo",
                        style: TextStyle(
                          color: comparisonSensors.isEmpty
                              ? config.color
                              : Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen, size: 20),
                        onPressed: () => _showFullscreenChart(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: RepaintBoundary(
                      child: LineChart(
                        _getChartData(
                          comparisonSensors.isEmpty
                              ? [
                                  histories[activeGraphKey]!
                                      .map(
                                        (spot) => FlSpot(
                                          spot.x,
                                          _convertValue(
                                            activeGraphKey,
                                            spot.y,
                                            sensorUnits[activeGraphKey]!,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ]
                              : comparisonSensors
                                    .map(
                                      (k) => histories[k]!
                                          .map(
                                            (spot) => FlSpot(
                                              spot.x,
                                              _convertValue(
                                                k,
                                                spot.y,
                                                sensorUnits[k]!,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    )
                                    .toList(),
                          comparisonSensors.isEmpty
                              ? [config.color]
                              : comparisonSensors
                                    .map((k) => _getSensorConfig(k).color)
                                    .toList(),
                          comparisonSensors.isEmpty
                              ? [activeGraphKey]
                              : comparisonSensors,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetHistories,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(
                        "Resetar Gráficos",
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "SELECIONE UM SENSOR PARA ANALISAR",
            style: TextStyle(
              fontSize: 10,
              color: subTextColor.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: sensorData.keys.map((k) => _sensorActionCard(k)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlTab() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return _TabScaffold(
      title: "Painel de Ação",
      child: ListView(
        children: [
          _buildInteractiveCard(
            onTap: _showHealthDiagnosis,
            child: ListTile(
              leading: const Icon(
                Icons.health_and_safety,
                color: Colors.greenAccent,
                size: 30,
              ),
              title: Text(
                "Diagnóstico de Saúde",
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              subtitle: Text(
                "Análise inteligente e correlações",
                style: TextStyle(color: subTextColor),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ),
          const SizedBox(height: 15),
          if (isMaintenanceMode)
            _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.build_circle,
                      color: Colors.orangeAccent,
                      size: 30,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Modo Manutenção Ativo",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            "Tempo restante: ${maintenanceRemainingSeconds ~/ 60}:${(maintenanceRemainingSeconds % 60).toString().padLeft(2, '0')}",
                            style: TextStyle(color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _toggleMaintenanceMode(false),
                      child: const Text(
                        "SAIR",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (!isAutoPumpEnabled)
            _buildInteractiveCard(
              child: SwitchListTile(
                secondary: Icon(
                  Icons.water_drop,
                  color: pumpState
                      ? Colors.blue
                      : (isDark ? Colors.white24 : Colors.black26),
                  size: 30,
                ),
                title: Text(
                  "Sistema de Irrigação",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  pumpState ? "BOMBA ATIVA" : "AGUARDANDO COMANDO",
                  style: TextStyle(color: subTextColor),
                ),
                value: pumpState,
                activeThumbColor: Colors.blueAccent,
                onChanged: (v) {
                  setState(() => pumpState = v);
                  _sendCommand('pump', v);
                },
              ),
            )
          else
            _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_fix_high,
                      color: Colors.blueAccent,
                      size: 30,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Irrigação Automática Ativa",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            "O controle manual está desabilitado.",
                            style: TextStyle(color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 15),
          if (!isMaintenanceMode)
            _buildInteractiveCard(
              onTap: () => _toggleMaintenanceMode(true),
              child: ListTile(
                leading: const Icon(
                  Icons.build_circle_outlined,
                  color: Colors.orangeAccent,
                  size: 30,
                ),
                title: Text(
                  "Ativar Modo Manutenção",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  "Pausa alertas e irrigação por 30 min",
                  style: TextStyle(color: subTextColor),
                ),
                trailing: const Icon(
                  Icons.timer_outlined,
                  color: Colors.orangeAccent,
                ),
              ),
            ),
          const SizedBox(height: 15),
          _buildInteractiveCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.science, color: Colors.purpleAccent),
                      const SizedBox(width: 15),
                      Text(
                        "Calibração pH",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        phCalibration.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.purpleAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: phCalibration,
                    activeColor: Colors.purpleAccent,
                    onChanged: (v) => setState(() => phCalibration = v),
                    onChangeEnd: (v) {
                      _sendCommand('ph', v);
                      SharedPreferences.getInstance().then(
                        (p) => p.setDouble('ph_calib', v),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildInteractiveCard(
            child: ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
              title: Text(
                "Câmera",
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              subtitle: Text(
                "Capturar imagem de alta resolução",
                style: TextStyle(color: subTextColor),
              ),
              trailing: ElevatedButton(
                onPressed: _captureManualPhoto,
                child: const Text("FOTO"),
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildInteractiveCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.history,
                    color: Colors.orangeAccent,
                  ),
                  title: Text(
                    "Diário de Cultivo",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    "${diaryNotes.length} registros no histórico",
                    style: TextStyle(color: subTextColor),
                  ),
                  onTap: _showDiaryListDialog,
                  trailing: const Icon(Icons.chevron_right, size: 16),
                ),
                if (diaryNotes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        ...diaryNotes.take(2).map((note) {
                          final date = DateTime.fromMillisecondsSinceEpoch(
                            note['timestamp'] as int,
                          );
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note['note'],
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${date.day}/${date.month} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(
                    Icons.bug_report,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    "Simulador de Falhas",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    "Simular erros para testar a IA",
                    style: TextStyle(color: subTextColor),
                  ),
                  onTap: _showFailureSimulatorDialog,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white24,
                  ),
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(
                    Icons.delete_sweep,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    "Resetar Banco de Dados",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    "Apagar histórico do SQLite",
                    style: TextStyle(color: subTextColor),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Limpar Banco de Dados?"),
                        content: const Text(
                          "Isso apagará todo o histórico de sensores salvo no celular. Esta ação não pode ser desfeita.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("CANCELAR"),
                          ),
                          TextButton(
                            onPressed: () {
                              _clearDatabase();
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "LIMPAR TUDO",
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return _TabScaffold(
      title: "Configuração",
      actions: [
        IconButton(
          icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: widget.onThemeToggle,
          tooltip: "Alternar Tema",
        ),
      ],
      child: ListView(
        children: [
          _buildInteractiveCard(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  TextField(
                    controller: _ipController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      icon: const Icon(Icons.router, color: Colors.greenAccent),
                      labelText: "Endereço IP da Raspberry Pi",
                      labelStyle: TextStyle(color: subTextColor),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (v) async {
                      final newIp = v.trim();
                      if (newIp.isEmpty || newIp == raspIP) return;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('rasp_ip', newIp);
                      setState(() => raspIP = newIp);
                      _reconnect();
                    },
                  ),
                  const Divider(color: Colors.white10),
                  SwitchListTile(
                    title: Text(
                      "Irrigação Automática",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    subtitle: Text(
                      isAutoPumpEnabled
                          ? "Ativa (${autoPumpMode == 'Timer' ? 'por Timer' : 'por Sensor'})"
                          : "Desativada",
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    value: isAutoPumpEnabled,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (v) async {
                      setState(() => isAutoPumpEnabled = v);
                      _startAutoPump();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('auto_pump_enabled', v);
                    },
                  ),
                  if (isAutoPumpEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Modo:",
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              DropdownButton<String>(
                                value: autoPumpMode,
                                dropdownColor: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12,
                                ),
                                items: ["Timer", "Sensor"].map((mode) {
                                  return DropdownMenuItem(
                                    value: mode,
                                    child: Text(mode),
                                  );
                                }).toList(),
                                onChanged: (val) async {
                                  if (val != null) {
                                    setState(() => autoPumpMode = val);
                                    _startAutoPump();
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString(
                                      'auto_pump_mode',
                                      val,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          if (autoPumpMode == "Timer")
                            Row(
                              children: [
                                Text(
                                  "Intervalo: ",
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    min: 60,
                                    max: 86400,
                                    divisions: 144,
                                    value: autoPumpInterval.toDouble(),
                                    activeColor: Colors.blueAccent,
                                    onChanged: (v) {
                                      setState(
                                        () => autoPumpInterval = v.toInt(),
                                      );
                                    },
                                    onChangeEnd: (v) async {
                                      _startAutoPump();
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setInt(
                                        'auto_pump_interval',
                                        v.toInt(),
                                      );
                                    },
                                  ),
                                ),
                                Text(
                                  "${autoPumpInterval ~/ 60} min",
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          if (autoPumpMode == "Sensor")
                            Row(
                              children: [
                                Text(
                                  "Limiar Solo: ",
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    min: 0,
                                    max: 100,
                                    value: moistureThreshold,
                                    activeColor: Colors.brown,
                                    onChanged: (v) {
                                      setState(() => moistureThreshold = v);
                                    },
                                    onChangeEnd: (v) async {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setDouble(
                                        'moisture_threshold',
                                        v,
                                      );
                                    },
                                  ),
                                ),
                                Text(
                                  "${moistureThreshold.toStringAsFixed(0)}%",
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          Row(
                            children: [
                              Text(
                                "Duração: ",
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  min: 1,
                                  max: 300,
                                  value: autoPumpDuration.toDouble(),
                                  activeColor: Colors.blueAccent,
                                  onChanged: (v) {
                                    setState(
                                      () => autoPumpDuration = v.toInt(),
                                    );
                                  },
                                  onChangeEnd: (v) async {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setInt(
                                      'auto_pump_duration',
                                      v.toInt(),
                                    );
                                  },
                                ),
                              ),
                              Text(
                                "$autoPumpDuration seg",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(color: Colors.white10),
                  ListTile(
                    leading: const Icon(
                      Icons.screenshot_monitor,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      "Sensores no HUD (Vídeo)",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    subtitle: Text(
                      "${hudSensors.length} sensores selecionados",
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => StatefulBuilder(
                          builder: (context, setDialogState) => AlertDialog(
                            title: const Text("Selecionar Sensores HUD"),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView(
                                shrinkWrap: true,
                                children: sensorData.keys.map((key) {
                                  final cfg = _getSensorConfig(key);
                                  final isSelected = hudSensors.contains(key);
                                  return CheckboxListTile(
                                    title: Text(cfg.name),
                                    secondary: Icon(
                                      cfg.icon,
                                      color: cfg.color,
                                      size: 20,
                                    ),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        setState(() {
                                          if (val == true) {
                                            if (!hudSensors.contains(key))
                                              hudSensors.add(key);
                                          } else {
                                            hudSensors.remove(key);
                                          }
                                        });
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("FECHAR"),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    trailing: const Icon(Icons.chevron_right, size: 16),
                  ),
                  const Divider(color: Colors.white10),
                  SwitchListTile(
                    title: Text(
                      "Gravar Eventos de Anomalia",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    subtitle: Text(
                      isEventRecordingEnabled
                          ? "Raspberry gravará fotos/vídeos em alertas"
                          : "Gravação desativada",
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    value: isEventRecordingEnabled,
                    activeThumbColor: Colors.redAccent,
                    onChanged: (v) async {
                      setState(() => isEventRecordingEnabled = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('event_recording', v);
                    },
                  ),
                  const Divider(color: Colors.white10),
                  SwitchListTile(
                    title: Text(
                      "Habilitar Inteligência Artificial",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    subtitle: Text(
                      isAiEnabled
                          ? "Modo IA Ativo (Diagnóstico em Tempo Real)"
                          : "IA Desativada (Apenas Sensores e Vídeo)",
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    value: isAiEnabled,
                    activeThumbColor: Colors.greenAccent,
                    onChanged: (v) async {
                      setState(() => isAiEnabled = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('ai_enabled', v);
                    },
                  ),
                  const Divider(color: Colors.white10),
                  SwitchListTile(
                    title: Text(
                      "Modo Nuvem (Longa Distância)",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    subtitle: Text(
                      isCloudMode
                          ? "Conectado via MQTT (Internet)"
                          : "Conectado via Rede Local (Raspberry)",
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    value: isCloudMode,
                    activeThumbColor: Colors.orangeAccent,
                    onChanged: (v) async {
                      setState(() => isCloudMode = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('cloud_mode', v);
                      _reconnect();
                    },
                  ),
                  if (isCloudMode) ...[
                    const Divider(color: Colors.white10),
                    ListTile(
                      leading: const Icon(
                        Icons.cloud,
                        color: Colors.orangeAccent,
                      ),
                      title: Text(
                        "Configurar MQTT",
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        "$mqttBroker:$mqttPort",
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                      onTap: () {
                        _showMqttConfigDialog();
                      },
                      trailing: const Icon(Icons.edit, size: 16),
                    ),
                  ],
                  const Divider(color: Colors.white10),
                  SwitchListTile(
                    title: Text(
                      "Modo Simulação",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    subtitle: Text(
                      isSimulationMode
                          ? "Gerando dados aleatórios"
                          : "Usando dados reais (Raspberry/Arduino)",
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    value: isSimulationMode,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (v) {
                      setState(() {
                        isSimulationMode = v;
                        if (v) _startSimulation();
                      });
                    },
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    onTap: _resetHistories,
                    leading: const Icon(Icons.history, color: Colors.redAccent),
                    title: Text(
                      "Resetar Histórico de Gráficos",
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                    subtitle: Text(
                      "Limpar todos os dados coletados na sessão",
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildInteractiveCard(
            onTap: _reconnect,
            child: ListTile(
              leading: Icon(
                isConnected ? Icons.check_circle : Icons.error,
                color: isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
              title: Text(
                isConnected ? "LINK ESTÁVEL" : "DESCONECTADO",
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                isCloudMode ? "MODO NUVEM ATIVO" : "IP ATUAL: $raspIP",
                style: TextStyle(color: subTextColor),
              ),
              trailing: Icon(
                Icons.refresh,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventGallery() {
    if (eventGallery.isEmpty) return const SizedBox();
    final isDark = widget.isDarkMode;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "GALERIA DE EVENTOS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: subTextColor.withValues(alpha: 0.6),
                letterSpacing: 1.5,
              ),
            ),
            Text(
              "${eventGallery.length} REGISTROS",
              style: TextStyle(
                fontSize: 9,
                color: subTextColor.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: eventGallery.length,
            itemBuilder: (context, index) {
              final event = eventGallery[index];
              final date = DateTime.fromMillisecondsSinceEpoch(
                event['timestamp'] as int,
              );
              final String type = event['type'] ?? 'Evento';

              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          image:
                              event['path'] != null &&
                                  File(event['path'] as String).existsSync()
                              ? DecorationImage(
                                  image: FileImage(
                                    File(event['path'] as String),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            event['path'] == null ||
                                !File(event['path'] as String).existsSync()
                            ? Center(
                                child: Icon(
                                  type == 'IA'
                                      ? Icons.psychology
                                      : Icons.image_not_supported,
                                  size: 24,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(
                        fontSize: 9,
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTelemetrySection() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    if (hudSensors.isEmpty) return const SizedBox();

    return _buildInteractiveCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Text(
                  "Telemetria Rápida",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: Text(
                    "VER TUDO",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 20,
              runSpacing: 15,
              children: hudSensors.map((key) {
                final cfg = _getSensorConfig(key);
                final val = _getDisplayValue(key);
                return SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Icon(cfg.icon, color: cfg.color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cfg.label,
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              "${val.toStringAsFixed(1)}${cfg.unit}",
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowIcon() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (hasDisease ? Colors.redAccent : Colors.greenAccent)
                .withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Icon(
        hasDisease ? Icons.warning_rounded : Icons.check_circle_rounded,
        size: 100,
        color: hasDisease ? Colors.redAccent : Colors.greenAccent,
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: (hasDisease ? Colors.redAccent : Colors.greenAccent).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (hasDisease ? Colors.redAccent : Colors.greenAccent)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        hasDisease ? "ANOMALIA DETECTADA" : "SAÚDE EXCELENTE",
        style: TextStyle(
          color: hasDisease ? Colors.redAccent : Colors.greenAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDynamicGlowIcon() {
    bool hasIssue = isAiEnabled
        ? hasDisease
        : sensorIntegrity.values.any((v) => v == false) || !isConnected;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (hasIssue ? Colors.redAccent : Colors.greenAccent)
                .withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Icon(
        hasIssue ? Icons.warning_rounded : Icons.check_circle_rounded,
        size: 100,
        color: hasIssue ? Colors.redAccent : Colors.greenAccent,
      ),
    );
  }

  String _getDynamicStatus() {
    if (isAiEnabled) return plantStatus;

    if (!isConnected) return "Arduino Offline";
    if (sensorIntegrity.values.any((v) => v == false)) return "Erro de Sensor";
    return "Arduino Online";
  }

  Widget _buildDynamicStatusBadge() {
    bool hasIssue = isAiEnabled
        ? hasDisease
        : sensorIntegrity.values.any((v) => v == false) || !isConnected;

    String text = "";
    if (isAiEnabled) {
      text = hasDisease ? "ANOMALIA DETECTADA" : "SAÚDE EXCELENTE";
    } else {
      if (!isConnected) {
        text = "ERRO DE CONEXÃO";
      } else if (sensorIntegrity.values.any((v) => v == false)) {
        text = "VERIFICAR HARDWARE";
      } else {
        text = "SISTEMA OPERACIONAL";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: (hasIssue ? Colors.redAccent : Colors.greenAccent).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (hasIssue ? Colors.redAccent : Colors.greenAccent).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: hasIssue ? Colors.redAccent : Colors.greenAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getDynamicPriorityColor() {
    if (isAiEnabled) return aiPriorityColor;
    return (sensorIntegrity.values.any((v) => v == false) || !isConnected)
        ? Colors.redAccent
        : Colors.greenAccent;
  }

  String _getDynamicPriority() {
    if (isAiEnabled) return aiPriority;
    return (sensorIntegrity.values.any((v) => v == false) || !isConnected)
        ? "CRÍTICO"
        : "NORMAL";
  }

  String _getDynamicRecommendation() {
    if (isAiEnabled) return aiRecommendation;

    if (!isConnected) {
      return "Verifique o cabo USB do Arduino e se o script de integração está rodando na Raspberry Pi.";
    }
    if (sensorIntegrity.values.any((v) => v == false)) {
      String faulty = sensorIntegrity.entries
          .where((e) => !e.value)
          .map((e) => _getSensorConfig(e.key).name)
          .join(", ");
      return "Falha detectada nos sensores: $faulty. Verifique as conexões físicas.";
    }
    return "Todos os sensores estão operando normalmente. Os dados estão sendo recebidos em tempo real.";
  }

  List<String> _getDynamicAlerts() {
    if (isAiEnabled) return _alerts;

    List<String> arduinoAlerts = [];
    if (!isConnected) {
      arduinoAlerts.add("[ALERTA] Arduino não detectado na rede.");
    }
    sensorIntegrity.forEach((key, healthy) {
      if (!healthy) {
        arduinoAlerts.add(
          "[FALHA] Sensor ${_getSensorConfig(key).name} desconectado.",
        );
      }
    });
    return arduinoAlerts;
  }

  Widget _sensorActionCard(String key) {
    final cfg = _getSensorConfig(key);
    bool isActive = activeGraphKey == key;
    bool isHealthy = sensorIntegrity[key] ?? true;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => activeGraphKey = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? cfg.color.withValues(alpha: 0.15)
              : (isDark
                    ? (isHealthy
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.red.withValues(alpha: 0.1))
                    : (isHealthy
                          ? Colors.white
                          : Colors.red.withValues(alpha: 0.05))),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: !isHealthy
                ? Colors.redAccent
                : (isActive
                      ? cfg.color
                      : (isDark ? Colors.white10 : Colors.black26)),
            width: isActive ? 2 : 1.5,
          ),
          boxShadow: !isDark && isHealthy
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    cfg.icon,
                    color: isHealthy ? cfg.color : Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cfg.label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isHealthy
                          ? (isDark ? Colors.white54 : Colors.black54)
                          : Colors.redAccent,
                    ),
                  ),
                  Text(
                    isHealthy
                        ? "${_getDisplayValue(key).toStringAsFixed(1)}${cfg.unit}"
                        : "ERRO",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isHealthy
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHealthy ? Colors.greenAccent : Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: (isHealthy ? Colors.greenAccent : Colors.redAccent)
                          .withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            if (!isHealthy)
              const Positioned(
                top: 20,
                right: 5,
                child: Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  LineChartData _getChartData(
    List<List<FlSpot>> allLines,
    List<Color> colors,
    List<String> keys,
  ) {
    if (allLines.isEmpty || allLines.first.isEmpty) {
      allLines = [
        [const FlSpot(0, 0)],
      ];
      colors = [Colors.grey];
      keys = [''];
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var spots in allLines) {
      if (spots.isEmpty) continue;
      final values = spots.map((e) => e.y).toList();
      double currentMin = values.reduce(math.min);
      double currentMax = values.reduce(math.max);
      if (currentMin < minY) minY = currentMin;
      if (currentMax > maxY) maxY = currentMax;
    }

    if (minY == double.infinity) {
      minY = 0;
      maxY = 100;
    } else {
      minY = (minY * 0.9).floorToDouble();
      maxY = (maxY * 1.1).ceilToDouble();
      if (maxY - minY < 5) maxY = minY + 5;
    }

    List<HorizontalLine> rangeLines = [];
    if (keys.length == 1) {
      final key = keys.first;
      if (key.startsWith('t')) {
        rangeLines.add(_buildRangeLine(20, Colors.blue.withValues(alpha: 0.3)));
        rangeLines.add(_buildRangeLine(28, Colors.red.withValues(alpha: 0.3)));
      } else if (key.startsWith('p')) {
        rangeLines.add(
          _buildRangeLine(5.5, Colors.purple.withValues(alpha: 0.3)),
        );
        rangeLines.add(
          _buildRangeLine(6.5, Colors.purple.withValues(alpha: 0.3)),
        );
      } else if (key.startsWith('u')) {
        rangeLines.add(
          _buildRangeLine(40, Colors.brown.withValues(alpha: 0.3)),
        );
      }
    }

    return LineChartData(
      extraLinesData: ExtraLinesData(horizontalLines: rangeLines),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => colors.first.withValues(alpha: 0.8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                spot.y.toStringAsFixed(1),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: minY,
      maxY: maxY,
      lineBarsData: List.generate(allLines.length, (i) {
        return LineChartBarData(
          spots: allLines[i],
          isCurved: true,
          color: colors[i],
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: allLines.length == 1,
            color: colors[i].withValues(alpha: 0.1),
          ),
        );
      }),
    );
  }

  HorizontalLine _buildRangeLine(double value, Color color) {
    return HorizontalLine(
      y: value,
      color: color,
      strokeWidth: 1,
      dashArray: [5, 5],
      label: HorizontalLineLabel(
        show: true,
        alignment: Alignment.topRight,
        style: TextStyle(color: color, fontSize: 8),
      ),
    );
  }

  _SensorConfig _getSensorConfig(String key) {
    String unit = sensorUnits[key] ?? "";
    bool isHealthy = sensorIntegrity[key] ?? true;

    Color _mixError(Color themeColor) {
      if (isHealthy) return themeColor;
      return Color.lerp(themeColor, Colors.redAccent, 0.5) ?? Colors.redAccent;
    }

    switch (key) {
      case 'u1':
        return _SensorConfig(
          "Umidade Solo 1",
          "U1",
          Icons.water_drop,
          _mixError(Colors.blueAccent),
          unit,
        );
      case 'u2':
        return _SensorConfig(
          "Umidade Solo 2",
          "U2",
          Icons.water_drop,
          _mixError(Colors.blue),
          unit,
        );
      case 'l1':
        return _SensorConfig(
          "Luz Ambiente 1",
          "L1",
          Icons.wb_sunny,
          _mixError(Colors.yellowAccent),
          unit,
        );
      case 'l2':
        return _SensorConfig(
          "Luz Ambiente 2",
          "L2",
          Icons.wb_sunny,
          _mixError(Colors.orangeAccent),
          unit,
        );
      case 't1':
        return _SensorConfig(
          "Temperatura 1",
          "T1",
          Icons.thermostat,
          _mixError(Colors.redAccent),
          unit,
        );
      case 't2':
        return _SensorConfig(
          "Temperatura 2",
          "T2",
          Icons.thermostat,
          _mixError(Colors.deepOrange),
          unit,
        );
      case 'p1':
        return _SensorConfig(
          "Nível pH 1",
          "P1",
          Icons.science,
          _mixError(Colors.purpleAccent),
          unit,
        );
      case 'p2':
        return _SensorConfig(
          "Nível pH 2",
          "P2",
          Icons.science,
          _mixError(Colors.deepPurpleAccent),
          unit,
        );
      case 'ec':
        return _SensorConfig(
          "Eletrocondutividade",
          "EC",
          Icons.bolt,
          _mixError(Colors.cyanAccent),
          unit,
        );
      case 'water_level':
        return _SensorConfig(
          "Nível de Água",
          "NV",
          Icons.waves,
          _mixError(Colors.blue),
          unit,
        );
      case 'battery':
        return _SensorConfig(
          "Bateria",
          "BT",
          Icons.battery_charging_full,
          _mixError(Colors.green),
          unit,
        );
      default:
        return _SensorConfig(
          "Sensor",
          "",
          Icons.sensors,
          _mixError(Colors.grey),
          unit,
        );
    }
  }

  Widget _buildInteractiveCard({
    required Widget child,
    double? height,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black26),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

class _SensorConfig {
  final String name;
  final String label;
  final IconData icon;
  final Color color;
  final String unit;
  _SensorConfig(this.name, this.label, this.icon, this.color, this.unit);
}

class _TabScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const _TabScaffold({required this.title, required this.child, this.actions});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.eco,
                color: isDark ? Colors.greenAccent : Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: actions,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: child,
      ),
    );
  }
}
