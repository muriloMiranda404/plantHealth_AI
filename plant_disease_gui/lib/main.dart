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
        scaffoldBackgroundColor: const Color(
          0xFFF0F2F5,
        ), // Cor de fundo levemente mais escura para contraste
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2, // Adicionado elevação para destaque no tema claro
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(
              color: Colors.black26, // Borda mais visível
              width: 1.5,
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Colors.black26, // Divisória mais visível
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
  bool isRaspberryEnabled = true;
  bool isSimulationMode = false;
  Timer? _simulationTimer;

  // --- MQTT / CLOUD MODE ---
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

  // IA Data
  String plantStatus = "Iniciando...";
  bool hasDisease = false;
  double confidence = 0.0;

  // Sensor Data (8 Sensores)
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

  // Configuração de Unidades (Novo)
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

  // Histórico de 11 Sensores para Gráficos
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
  String activeGraphKey = 'u1'; // Sensor selecionado para o gráfico

  bool pumpState = false;
  bool lightState = false; // Novo: Status da iluminação
  double phCalibration = 0.5;
  double cameraBrightness = 0.0;
  double cameraCurrentFps = 0.0;
  int cameraTargetFps = 18;
  static const List<int> _cameraFpsOptions = [10, 15, 18, 24, 30];

  // Controle Físico (RFID + Potenciômetro)
  bool isSystemLocked = true;
  double physicalLightIntensity = 0.0;

  // Status da integridade dos sensores
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

  // --- IA RECOMENDAÇÃO ---
  String aiRecommendation = "Aguardando dados para análise...";
  String aiPriority = "BAIXO";
  Color aiPriorityColor = Colors.greenAccent;

  // --- NOVAS VARIÁVEIS PARA ALERTAS E RELATÓRIO ---
  final List<String> _alerts = [];
  final bool _isStreamActive = true;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _uiRefreshTimer;
  static const Duration _uiRefreshInterval = Duration(milliseconds: 120);

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _ipController = TextEditingController(text: raspIP);
    _loadSettings().then((_) {
      if (isCloudMode) {
        _setupMQTT();
      } else {
        _setupNT4();
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
              newVal = 60.0 + random.nextDouble() * 20.0; // 60-80
              break;
            case 'u2':
              newVal = 55.0 + random.nextDouble() * 20.0; // 55-75
              break;
            case 'l1':
              newVal = 300.0 + random.nextDouble() * 100.0; // 300-400
              break;
            case 'l2':
              newVal = 310.0 + random.nextDouble() * 100.0; // 310-410
              break;
            case 't1':
              newVal = 24.0 + random.nextDouble() * 4.0; // 24-28
              break;
            case 't2':
              newVal = 23.0 + random.nextDouble() * 4.0; // 23-27
              break;
            case 'p1':
              newVal = 6.2 + random.nextDouble() * 0.6; // 6.2-6.8
              break;
            case 'p2':
              newVal = 6.1 + random.nextDouble() * 0.6; // 6.1-6.7
              break;
            case 'ec':
              newVal = 1.2 + random.nextDouble() * 0.6; // 1.2-1.8
              break;
            case 'water_level':
              newVal = 85.0 + random.nextDouble() * 10.0; // 85-95
              break;
            case 'battery':
              newVal = 92.0 + random.nextDouble() * 8.0; // 92-100
              break;
            default:
              newVal = random.nextDouble() * 100.0;
          }
          sensorData[key] = newVal;
          _updateHistory(key, newVal);
        });

        // Simular problemas aleatórios para notificações (menos frequentes)
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
    String problem = "";
    String cause = "";
    String action = "";
    String priority = "BAIXO";
    Color color = Colors.greenAccent;

    // Lógica baseada no prompt enxuto
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
    } else if (ph < 5.5 || ph > 6.5) {
      problem = "pH fora do ideal ($ph)";
      cause = "Desequilíbrio químico";
      action = "Corrigir solução nutritiva";
      priority = "CRÍTICO";
      color = Colors.redAccent;
      _showNotification("Alerta de pH", "O pH está fora da faixa ideal: $ph");
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
    final savedRaspEnabled = prefs.getBool('rasp_enabled') ?? true;
    final savedCloudMode = prefs.getBool('cloud_mode') ?? false;
    final savedMqttBroker = prefs.getString('mqtt_broker') ?? "broker.emqx.io";
    final savedMqttPort = prefs.getInt('mqtt_port') ?? 1883;
    final savedMqttTopic =
        prefs.getString('mqtt_topic') ?? "planthealth/sensor";

    _ipController.text = savedIp;
    setState(() {
      raspIP = savedIp;
      phCalibration = savedPh;
      cameraBrightness = savedBrightness;
      cameraTargetFps = _cameraFpsOptions.contains(savedTargetFps)
          ? savedTargetFps
          : _cameraFpsOptions.first;
      isRaspberryEnabled = savedRaspEnabled;
      isCloudMode = savedCloudMode;
      mqttBroker = savedMqttBroker;
      mqttPort = savedMqttPort;
      mqttTopicPrefix = savedMqttTopic;

      // Carregar unidades salvas
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
    mqttClient!.onDisconnected = () {
      if (mounted) setState(() => isConnected = false);
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    mqttClient!.connectionMessage = connMessage;

    try {
      await mqttClient!.connect();
      if (mounted) setState(() => isConnected = true);

      // Subscrever a todos os tópicos de sensores
      sensorData.keys.forEach((key) {
        final topic = "$mqttTopicPrefix/$key";
        mqttClient!.subscribe(topic, MqttQos.atMostOnce);
      });

      mqttClient!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        final topic = c[0].topic;
        final sensorKey = topic.split('/').last;

        if (sensorData.containsKey(sensorKey)) {
          final val = double.tryParse(pt) ?? 0.0;
          if (mounted) {
            setState(() {
              sensorData[sensorKey] = val;
              lastSensorUpdate[sensorKey] = DateTime.now();
              _updateHistory(sensorKey, val);
            });
            _runAiRecommendation();
            _scheduleUiRefresh(visibleTabs: {1});
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
        // Se o sensor não atualiza há mais de 10 segundos, marcamos como falha
        final bool isHealthy =
            lastUpdate != null && now.difference(lastUpdate).inSeconds < 10;

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
        _scheduleUiRefresh(visibleTabs: {1});
      }
    });
  }

  void _updateHistory(String key, double val) {
    if (!histories.containsKey(key)) return;
    final history = histories[key]!;

    // Usamos um contador de tempo global para todos os sensores ficarem alinhados no eixo X
    history.add(FlSpot(timerCount.toDouble(), val));

    if (history.length > 50) {
      history.removeAt(0);
    }

    // Incrementamos o contador global a cada atualização de qualquer sensor
    // mas apenas se o sensor ativo for atualizado, para não correr demais o gráfico
    if (key == activeGraphKey) {
      timerCount++;
    }
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
    _setupSensorIntegrityCheck(); // Inicia monitoramento de integridade

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

        // Sincroniza valores iniciais após a conexão
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

    // Configuração Dinâmica de todos os 11 Sensores
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

          _runAiRecommendation();
          _scheduleUiRefresh(visibleTabs: {1});
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

    return _TabScaffold(
      title: "IA Real-Time",
      child: ListView(
        children: [
          // 1. STREAM DA CÂMERA
          _buildInteractiveCard(
            height: isRaspberryEnabled ? 250 : 350,
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Mjpeg(
                      isLive: _isStreamActive,
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
          const SizedBox(height: 15),

          // CONTROLES DE CÂMERA (Sempre Visíveis)
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
                        value: cameraTargetFps,
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
                          if (targetFpsPub != null) {
                            client.addSample(targetFpsPub!, value);
                          }
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
                      if (brightnessPub != null) {
                        client.addSample(brightnessPub!, value);
                      }
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

          // SEÇÃO DE DIAGNÓSTICO (Dinâmica entre IA e Arduino)
          Text(
            isRaspberryEnabled
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

  // --- TAB 2: ANALYTICS (8 SENSORES + GRÁFICOS) ---
  Widget _buildAnalyticsTab() {
    final config = _getSensorConfig(activeGraphKey);
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return _TabScaffold(
      title: "Telemetria",
      child: ListView(
        children: [
          _buildInteractiveCard(
            height: 240,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.name,
                    style: TextStyle(
                      color: config.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: RepaintBoundary(
                      child: LineChart(
                        _getChartData(histories[activeGraphKey]!, config.color),
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

  // --- TAB 3: CONTROLE ---
  Widget _buildControlTab() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return _TabScaffold(
      title: "Painel de Ação",
      child: ListView(
        children: [
          // 1. GERAÇÃO DE RELATÓRIO (Novo)
          _buildInteractiveCard(
            onTap: _generateReport,
            child: ListTile(
              leading: const Icon(
                Icons.description,
                color: Colors.greenAccent,
                size: 30,
              ),
              title: Text(
                "Gerar Relatório de Saúde",
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              subtitle: Text(
                "Exportar dados dos sensores para CSV",
                style: TextStyle(color: subTextColor),
              ),
              trailing: Icon(
                Icons.share,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ),
          const SizedBox(height: 15),

          // 2. BOMBA
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
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              subtitle: Text(
                pumpState ? "BOMBA ATIVA" : "AGUARDANDO COMANDO",
                style: TextStyle(color: subTextColor),
              ),
              value: pumpState,
              activeThumbColor: Colors.blueAccent,
              onChanged: (v) {
                setState(() => pumpState = v);
                if (pumpPub != null) client.addSample(pumpPub!, v);
              },
            ),
          ),
          const SizedBox(height: 15),

          // 3. CALIBRAÇÃO
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
                      if (phPub != null) client.addSample(phPub!, v);
                      SharedPreferences.getInstance().then(
                        (p) => p.setDouble('ph_calib', v),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: AJUSTES ---
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
      child: Column(
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
                      _setupNT4();
                    },
                  ),
                  const Divider(color: Colors.white10),
                  SwitchListTile(
                    title: Text(
                      "Habilitar Raspberry Pi",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    subtitle: Text(
                      isRaspberryEnabled
                          ? "Modo Completo (IA + Sensores)"
                          : "Modo Câmera (Apenas Vídeo)",
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    value: isRaspberryEnabled,
                    activeThumbColor: Colors.greenAccent,
                    onChanged: (v) async {
                      setState(() => isRaspberryEnabled = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('rasp_enabled', v);
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
                      if (v) {
                        _setupMQTT();
                      } else {
                        _setupNT4();
                      }
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
          if (isRaspberryEnabled)
            _buildInteractiveCard(
              onTap: () => _setupNT4(),
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
                  "IP ATUAL: $raspIP",
                  style: TextStyle(color: subTextColor),
                ),
                trailing: Icon(
                  Icons.refresh,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
            ),
          const SizedBox(height: 25),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "UNIDADES DOS SENSORES",
              style: TextStyle(
                fontSize: 10,
                color: subTextColor.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: sensorUnits.keys.map((key) {
                final cfg = _getSensorConfig(key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildInteractiveCard(
                    child: ListTile(
                      leading: Icon(cfg.icon, color: cfg.color, size: 20),
                      title: Text(
                        cfg.name,
                        style: TextStyle(fontSize: 13, color: textColor),
                      ),
                      trailing: SizedBox(
                        width: 100,
                        child: TextField(
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.greenAccent,
                          ),
                          decoration: InputDecoration(
                            hintText: "Unidade",
                            hintStyle: TextStyle(
                              color: subTextColor.withValues(alpha: 0.2),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            suffixIcon: Icon(
                              Icons.edit,
                              size: 12,
                              color: textColor.withValues(alpha: 0.2),
                            ),
                          ),
                          controller:
                              TextEditingController(text: sensorUnits[key])
                                ..selection = TextSelection.fromPosition(
                                  TextPosition(
                                    offset: sensorUnits[key]!.length,
                                  ),
                                ),
                          onSubmitted: (newUnit) async {
                            setState(() {
                              sensorUnits[key] = newUnit;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('unit_$key', newUnit);
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES AUXILIARES ---

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

  // --- MÉTODOS DE DIAGNÓSTICO DINÂMICO (IA vs ARDUINO) ---

  Widget _buildDynamicGlowIcon() {
    bool hasIssue = isRaspberryEnabled
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
    if (isRaspberryEnabled) return plantStatus;

    if (!isConnected) return "Arduino Offline";
    if (sensorIntegrity.values.any((v) => v == false)) return "Erro de Sensor";
    return "Arduino Online";
  }

  Widget _buildDynamicStatusBadge() {
    bool hasIssue = isRaspberryEnabled
        ? hasDisease
        : sensorIntegrity.values.any((v) => v == false) || !isConnected;

    String text = "";
    if (isRaspberryEnabled) {
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
    if (isRaspberryEnabled) return aiPriorityColor;
    return (sensorIntegrity.values.any((v) => v == false) || !isConnected)
        ? Colors.redAccent
        : Colors.greenAccent;
  }

  String _getDynamicPriority() {
    if (isRaspberryEnabled) return aiPriority;
    return (sensorIntegrity.values.any((v) => v == false) || !isConnected)
        ? "CRÍTICO"
        : "NORMAL";
  }

  String _getDynamicRecommendation() {
    if (isRaspberryEnabled) return aiRecommendation;

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
    if (isRaspberryEnabled) return _alerts;

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
                        ? "${sensorData[key]?.toStringAsFixed(1)}${cfg.unit}"
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
            // Indicador de status de conexão no topo direito
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

  LineChartData _getChartData(List<FlSpot> spots, Color color) {
    if (spots.isEmpty) {
      spots = [const FlSpot(0, 0)];
    }

    double minY = 0;
    double maxY = 100;

    // Ajustar escala Y baseada nos dados se necessário (ex: Temperatura ou pH)
    if (spots.length > 1) {
      final values = spots.map((e) => e.y).toList();
      double currentMin = values.reduce(math.min);
      double currentMax = values.reduce(math.max);

      // Margem de 10%
      minY = (currentMin * 0.9).floorToDouble();
      maxY = (currentMax * 1.1).ceilToDouble();

      // Garantir um range mínimo
      if (maxY - minY < 5) {
        maxY = minY + 5;
      }
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: color.withValues(alpha: 0.05), strokeWidth: 1),
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
                color: color.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => color.withValues(alpha: 0.8),
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
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  _SensorConfig _getSensorConfig(String key) {
    String unit = sensorUnits[key] ?? "";
    switch (key) {
      case 'u1':
        return _SensorConfig(
          "Umidade Solo 1",
          "U1",
          Icons.water_drop,
          Colors.blueAccent,
          unit,
        );
      case 'u2':
        return _SensorConfig(
          "Umidade Solo 2",
          "U2",
          Icons.water_drop,
          Colors.blue,
          unit,
        );
      case 'l1':
        return _SensorConfig(
          "Luz Ambiente 1",
          "L1",
          Icons.wb_sunny,
          Colors.yellowAccent,
          unit,
        );
      case 'l2':
        return _SensorConfig(
          "Luz Ambiente 2",
          "L2",
          Icons.wb_sunny,
          Colors.orangeAccent,
          unit,
        );
      case 't1':
        return _SensorConfig(
          "Temperatura 1",
          "T1",
          Icons.thermostat,
          Colors.redAccent,
          unit,
        );
      case 't2':
        return _SensorConfig(
          "Temperatura 2",
          "T2",
          Icons.thermostat,
          Colors.deepOrange,
          unit,
        );
      case 'p1':
        return _SensorConfig(
          "Nível pH 1",
          "P1",
          Icons.science,
          Colors.purpleAccent,
          unit,
        );
      case 'p2':
        return _SensorConfig(
          "Nível pH 2",
          "P2",
          Icons.science,
          Colors.deepPurpleAccent,
          unit,
        );
      case 'ec':
        return _SensorConfig(
          "Eletrocondutividade",
          "EC",
          Icons.bolt,
          Colors.cyanAccent,
          unit,
        );
      case 'water_level':
        return _SensorConfig(
          "Nível de Água",
          "NV",
          Icons.waves,
          Colors.blue,
          unit,
        );
      case 'battery':
        return _SensorConfig(
          "Bateria",
          "BT",
          Icons.battery_charging_full,
          Colors.green,
          unit,
        );
      default:
        return _SensorConfig("Sensor", "", Icons.sensors, Colors.grey, unit);
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
