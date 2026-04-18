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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:nsd/nsd.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/app_provider.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: const PlantGuardProApp(),
    ),
  );
}
class PlantGuardProApp extends StatefulWidget {
  const PlantGuardProApp({super.key});
  @override
  State<PlantGuardProApp> createState() => _PlantGuardProAppState();
}
class _PlantGuardProAppState extends State<PlantGuardProApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _showSplash = true;
  Color _lightColor = Colors.green;
  Color _darkColor = Colors.greenAccent;
  double _cardRadius = 25.0;
  double _borderWidth = 1.5;
  bool _solidAppBar = false;
  double _fontSizeDelta = 0.0;
  bool _glassCards = true;
  bool _glowEffects = true;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _showSplash) {
        print("APP: Tempo limite da Splash atingido. Forçando entrada.");
        setState(() {
          _showSplash = false;
        });
      }
    });
    _initializeApp();
  }
  Future<void> _initializeApp() async {
    try {
      print("APP: Iniciando carregamento...");
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('is_dark_mode') ?? true;
      final savedLightColor = prefs.getInt('light_theme_color');
      final savedDarkColor = prefs.getInt('dark_theme_color');
      final savedRadius = prefs.getDouble('card_border_radius');
      final savedBorderWidth = prefs.getDouble('card_border_width');
      final savedSolidAppBar = prefs.getBool('solid_app_bar') ?? false;
      final savedFontSize = prefs.getDouble('font_size_delta') ?? 0.0;
      final savedGlassCards = prefs.getBool('glass_cards') ?? true;
      final savedGlowEffects = prefs.getBool('glow_effects') ?? true;
      if (mounted) {
        setState(() {
          _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
          if (savedLightColor != null) _lightColor = Color(savedLightColor);
          if (savedDarkColor != null) _darkColor = Color(savedDarkColor);
          if (savedRadius != null) _cardRadius = savedRadius;
          if (savedBorderWidth != null) _borderWidth = savedBorderWidth;
          _solidAppBar = savedSolidAppBar;
          _fontSizeDelta = savedFontSize;
          _glassCards = savedGlassCards;
          _glowEffects = savedGlowEffects;
        });
      }
      print("APP: Configurações carregadas");
      await Future.delayed(const Duration(milliseconds: 3500));
    } catch (e) {
      print("APP: Erro na inicialização: $e");
    } finally {
      print("APP: Finalizando Splash Screen");
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    }
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
  void _updateThemeSettings({
    Color? lightColor,
    Color? darkColor,
    double? radius,
    double? borderWidth,
    bool? solidAppBar,
    double? fontSize,
    bool? glassCards,
    bool? glowEffects,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (lightColor != null) {
        _lightColor = lightColor;
        prefs.setInt('light_theme_color', lightColor.value);
      }
      if (darkColor != null) {
        _darkColor = darkColor;
        prefs.setInt('dark_theme_color', darkColor.value);
      }
      if (radius != null) {
        _cardRadius = radius;
        prefs.setDouble('card_border_radius', radius);
      }
      if (borderWidth != null) {
        _borderWidth = borderWidth;
        prefs.setDouble('card_border_width', borderWidth);
      }
      if (solidAppBar != null) {
        _solidAppBar = solidAppBar;
        prefs.setBool('solid_app_bar', solidAppBar);
      }
      if (fontSize != null) {
        _fontSizeDelta = fontSize;
        prefs.setDouble('font_size_delta', fontSize);
      }
      if (glassCards != null) {
        _glassCards = glassCards;
        prefs.setBool('glass_cards', glassCards);
      }
      if (glowEffects != null) {
        _glowEffects = glowEffects;
        prefs.setBool('glow_effects', glowEffects);
      }
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
        colorSchemeSeed: _lightColor,
        scaffoldBackgroundColor: const Color(0xFFF5F1E8),
        appBarTheme: AppBarTheme(
          backgroundColor: _solidAppBar ? _lightColor : Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: _glassCards
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.white,
          elevation: _glassCards ? 0 : 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius),
            side: BorderSide(color: Colors.black26, width: _borderWidth),
          ),
        ),
        dividerTheme: BorderSide.none == true
            ? null
            : DividerThemeData(color: Colors.black26, thickness: _borderWidth),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: _darkColor,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        appBarTheme: AppBarTheme(
          backgroundColor: _solidAppBar ? _darkColor : Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: _glassCards
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius),
            side: BorderSide(color: Colors.white10, width: _borderWidth),
          ),
        ),
      ),
      themeMode: _themeMode,
      home: _showSplash
          ? SplashScreen(isDarkMode: _themeMode == ThemeMode.dark)
          : MainTabController(
              onThemeToggle: _toggleTheme,
              isDarkMode: _themeMode == ThemeMode.dark,
              lightColor: _lightColor,
              darkColor: _darkColor,
              cardRadius: _cardRadius,
              borderWidth: _borderWidth,
              solidAppBar: _solidAppBar,
              fontSizeDelta: _fontSizeDelta,
              glassCards: _glassCards,
              glowEffects: _glowEffects,
              onSettingsChange: _updateThemeSettings,
            ),
    );
  }
}
class MainTabController extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final Color lightColor;
  final Color darkColor;
  final double cardRadius;
  final double borderWidth;
  final bool solidAppBar;
  final double fontSizeDelta;
  final bool glassCards;
  final bool glowEffects;
  final Function({
    Color? lightColor,
    Color? darkColor,
    double? radius,
    double? borderWidth,
    bool? solidAppBar,
    double? fontSize,
    bool? glassCards,
    bool? glowEffects,
  })
  onSettingsChange;
  const MainTabController({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.lightColor,
    required this.darkColor,
    required this.cardRadius,
    required this.borderWidth,
    required this.solidAppBar,
    required this.fontSizeDelta,
    required this.glassCards,
    required this.glowEffects,
    required this.onSettingsChange,
  });
  @override
  State<MainTabController> createState() => _MainTabControllerState();
}
class _MainTabControllerState extends State<MainTabController> {
  int _selectedIndex = 0;
  late NT4Client client;
  late final TextEditingController _ipController;
  late final TextEditingController _remoteHostController;
  bool isConnected = false;
  String raspIP = "127.0.0.1";
  String remoteHost = "";
  int videoPort = 5000;
  int wsPort = 8765;
  bool useRemoteSsl = false;
  String _stripProtocol(String input) {
    String stripped = input.trim();
    if (stripped.startsWith('http:
    if (stripped.startsWith('https:
    if (stripped.startsWith('ws:
    if (stripped.startsWith('wss:
    if (stripped.endsWith('/')) {
      stripped = stripped.substring(0, stripped.length - 1);
    }
    return stripped;
  }
  String get _effectiveHost => (isCloudMode && remoteHost.isNotEmpty)
      ? _stripProtocol(remoteHost)
      : _stripProtocol(raspIP);
  String get _videoUrl {
    final host = _effectiveHost;
    if (host.isEmpty) return "";
    if (host.contains(':')) {
      final protocol = isCloudMode && useRemoteSsl ? "https" : "http";
      return "$protocol:
    }
    if (isCloudMode) {
      final protocol = useRemoteSsl ? "https" : "http";
      bool isDomain =
          host.contains('.') && !RegExp(r'^[0-9.]+$').hasMatch(host);
      if (isDomain) {
        return "$protocol:
      }
      return "$protocol:
    }
    return "http:
  }
  String get _captureUrl {
    final host = _effectiveHost;
    if (host.isEmpty) return "";
    if (host.contains(':')) {
      final protocol = isCloudMode && useRemoteSsl ? "https" : "http";
      return "$protocol:
    }
    if (isCloudMode) {
      final protocol = useRemoteSsl ? "https" : "http";
      bool isDomain =
          host.contains('.') && !RegExp(r'^[0-9.]+$').hasMatch(host);
      if (isDomain) {
        return "$protocol:
      }
      return "$protocol:
    }
    return "http:
  }
  String get _wsUrl {
    final host = _effectiveHost;
    if (host.isEmpty) return "";
    if (host.contains(':')) {
      final protocol = isCloudMode && useRemoteSsl ? "wss" : "ws";
      return "$protocol:
    }
    if (isCloudMode) {
      final protocol = useRemoteSsl ? "wss" : "ws";
      bool isDomain =
          host.contains('.') && !RegExp(r'^[0-9.]+$').hasMatch(host);
      if (isDomain) {
        return "$protocol:
      }
      return "$protocol:
    }
    return "ws:
  }
  bool isAiEnabled = true;
  bool isSimulationMode = false;
  bool isTrainingAi = false;
  double aiTrainingProgress = 0.0;
  String aiTrainingStatus = "";
  Process? _aiTrainingProcess;
  bool isVacationMode = false;
  bool isEcoModeEnabled = false;
  bool _ecoModeManualOverride = false;
  Timer? _simulationTimer;
  Timer? _voiceTimer;
  bool isCloudMode = false;
  MqttServerClient? mqttClient;
  String mqttBroker = "broker.hivemq.com";
  int mqttPort = 1883;
  String mqttTopicPrefix = "plantguard_pro/device_ref_9921";
  WebSocketChannel? _wsChannel;
  bool isWebSocketConnected = false;
  NT4Topic? pumpPub;
  NT4Topic? phPub;
  NT4Topic? brightnessPub;
  NT4Topic? targetFpsPub;
  NT4Topic? aiEnablePub;
  NT4Topic? ecoModePub;
  NT4Topic? configPub;
  NT4Topic? cmdPub;
  String plantStatus = "Iniciando...";
  bool hasDisease = false;
  double confidence = 0.0;
  bool isAccessGranted = false;
  int currentLightIntensity = 0;
  bool arduinoBoardConnected = false;
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
  Map<String, Map<String, dynamic>> sensorConfigs = {};
  final Map<String, List<String>> _sensorSlotKeys = {
    'luminosidade': ['l1', 'l2'],
    'temperatura': ['t1', 't2'],
    'umidade': ['u1', 'u2'],
    'ph': ['p1', 'p2'],
    'eletrocondutividade': ['ec'],
    'nivel_agua': ['water_level'],
    'bateria': ['battery'],
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
  final Map<String, double> _lastRawValues = {};
  final Map<String, DateTime> _lastNoiseNotification = {};
  final List<List<double>> _irrigationHistory = [];
  bool isFirstAidMode = false;
  bool _isCapturingPhoto = false;
  bool _isNotificationsExpanded = true;
  final List<Map<String, String>> _logs = [];
  String _systemState = "ESTÁVEL";
  final Map<String, DateTime> _lastObstructedNotification = {};
  String activeGraphKey = 'u1';
  bool pumpState = false;
  double phCalibration = 0.5;
  bool isAutoPumpEnabled = false;
  String autoPumpMode = "Timer";
  double moistureThreshold = 30.0;
  int autoPumpInterval = 3600;
  int autoPumpDuration = 10;
  List<String> dashboardOrder = [
    'video',
    'health',
    'events',
    'hardware',
    'fps',
    'telemetry',
    'brightness',
    'plant3d',
  ];
  List<String> analyticsOrder = ['chart', 'sensor_selector'];
  List<String> controlOrder = [
    'diagnosis',
    'irrigation_history',
    'irrigation_control',
    'maintenance',
    'camera',
    'diary',
  ];
  List<String> settingsOrder = [
    'personalizacao',
    'funcionalidades',
    'conexao',
    'simulacao',
  ];
  List<String> personalizacaoOrder = ['graphic_elements', 'font_style'];
  List<String> funcionalidadesOrder = [
    'notifications',
    'night_mode',
    'voice_assistant',
    'auto_irrigation',
    'hud_sensors',
    'vacation_mode',
    'event_recording',
    'ai_enabled',
    'treinar_ia',
  ];
  List<String> conexaoOrder = [
    'access_guide',
    'rasp_ip',
    'remote_host',
    'remote_ports',
    'cloud_mode',
    'link_status',
    'websocket_status',
    'reset_db',
  ];
  List<String> simulacaoOrder = ['general_simulation', 'failure_simulator'];
  Timer? _autoPumpTimer;
  Timer? _autoPumpOffTimer;
  bool isEventRecordingEnabled = false;
  bool isNotificationsEnabled = true;
  Map<String, Map<String, bool>> notificationSettings = {
    'sensor_noise': {'push': true, 'log': true},
    'sensor_error': {'push': true, 'log': true},
    'connectivity': {'push': true, 'log': true},
    'plant_health': {'push': true, 'log': true},
    'gamification': {'push': false, 'log': true},
    'actions': {'push': false, 'log': true},
    'system': {'push': false, 'log': true},
    'sensor_replacement': {'push': true, 'log': true},
  };
  bool isDndEnabled = false;
  TimeOfDay dndStartTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay dndEndTime = const TimeOfDay(hour: 7, minute: 0);
  bool bypassDndForCritical = true;
  Map<String, String> categoryNames = {
    'sensor_noise': 'Ruído e Auto-correção',
    'sensor_error': 'Erros de Sensor',
    'connectivity': 'Conectividade e Servidor',
    'plant_health': 'Saúde e Alertas Críticos',
    'gamification': 'Conquistas e Nível',
    'actions': 'Ações de Hardware (Bomba/Foto)',
    'system': 'Sistema e Manutenção',
    'sensor_replacement': 'Troca de Sensor Necessária',
  };
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
  int healthScore = 100;
  int plantStreak = 0;
  int plantExp = 0;
  int plantLevel = 1;
  List<String> badges = [];
  String aiRecommendation = "Aguardando dados para análise...";
  String aiPriority = "BAIXO";
  Color aiPriorityColor = Colors.greenAccent;
  final List<Map<String, String>> _alerts = [];
  final bool _isStreamActive = true;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _uiRefreshTimer;
  static const Duration _uiRefreshInterval = Duration(milliseconds: 120);
  List<String> hudSensors = ['t1', 'u1', 'battery'];
  List<Map<String, dynamic>> eventGallery = [];
  List<Map<String, dynamic>> diaryNotes = [];
  List<String> comparisonSensors = [];
  Map<String, bool> simulatedFailures = {};
  final Set<String> _sentNotifications = {};
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _lastWords = "";
  bool isVoiceAssistantEnabled = false;
  bool isVoiceAudioResponseEnabled = true;
  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initDatabase().then((_) {
      _startDiscovery();
      _ipController = TextEditingController(text: raspIP);
      _remoteHostController = TextEditingController(text: remoteHost);
      _loadSettings().then((_) {
        _reconnect();
        try {
          final provider = Provider.of<AppProvider>(context, listen: false);
          provider.loadFromDb();
        } catch (e) {
          debugPrint("Provider: Erro na sincronização inicial: $e");
        }
      });
    });
  }
  Database? _database;
  Future<void> _initDatabase() async {
    try {
      print("DB: Migrando para DatabaseService unificado...");
      _database = await DatabaseService().database;
      print("DB: Banco de dados unificado e inicializado com sucesso!");
      await _loadHistoryFromDb();
      await _loadDiaryFromDb();
      await _loadEventsFromDb();
    } catch (e) {
      print("DB ERROR: Falha na inicialização unificada: $e");
      _addAlert("Erro ao iniciar banco de dados: $e");
    }
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
    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'diary',
        orderBy: 'timestamp DESC',
      );
      print("DB: Carregadas ${maps.length} notas");
      setState(() {
        diaryNotes = List.from(maps);
      });
      try {
        final provider = Provider.of<AppProvider>(context, listen: false);
        provider.setDiaryNotes(maps);
      } catch (e) {
      }
    } catch (e) {
      print("DB: Erro ao carregar diário: $e");
      _addAlert("Erro ao carregar diário: $e");
    }
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
  Future<void> _addDiaryNote(
    String note, {
    bool isReminder = false,
    DateTime? reminderTime,
    String? imagePath,
  }) async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.addDiaryNote(
        note,
        isReminder: isReminder,
        reminderTime: reminderTime,
        imagePath: imagePath,
      );
      await _loadDiaryFromDb();
      _addAlert(
        isReminder
            ? "Lembrete salvo com sucesso"
            : (imagePath != null
                  ? "Foto salva no diário"
                  : "Anotação salva com sucesso"),
      );
    } catch (e) {
      debugPrint("DIARIO: Erro fatal ao salvar: $e");
      _addAlert("Erro ao salvar no diário: $e");
    }
  }
  Future<void> _scheduleReminderNotification(
    int id,
    String note,
    DateTime time,
  ) async {
    final now = DateTime.now();
    if (time.isAfter(now)) {
      final delay = time.difference(now);
      Timer(delay, () async {
        if (!isNotificationsEnabled) {
          debugPrint("LEMBRETE: Bloqueado (Notificações Desativadas)");
          return;
        }
        if (isDndEnabled && _isCurrentTimeInDndRange()) {
          debugPrint("LEMBRETE: Bloqueado (Modo Não Perturbe Ativo)");
          return;
        }
        await NotificationService().showNotification(
          id: id,
          title: "Lembrete de Cultivo",
          body: note,
          channelId: 'plant_reminders',
          channelName: 'Lembretes de Cultivo',
        );
      });
    }
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
    try {
      await _database!.delete('history');
      await _database!.delete('diary');
      await _database!.delete('events');
      _resetHistories();
      await _loadDiaryFromDb();
      await _loadEventsFromDb();
      _addAlert("Banco de dados local totalmente limpo");
      print("DB: Banco de dados limpo");
    } catch (e) {
      _addAlert("Erro ao limpar banco: $e");
    }
  }
  Future<void> _startDiscovery() async {
    final discovery = await startDiscovery('_http._tcp');
    discovery.addListener(() {
      for (final service in discovery.services) {
        if (service.name != null &&
            (service.name!.toLowerCase().contains('raspberry') ||
                service.name!.toLowerCase().contains('plantguard'))) {
          final host = service.host;
          if (host != null && host != raspIP) {
            _addAlert(
              "Raspberry encontrada: $host (Porta: ${service.port})",
              category: 'connectivity',
            );
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
  Future<void> _showNotification(
    String title,
    String body, {
    String category = 'system',
    bool isCritical = false,
  }) async {
    if (!isNotificationsEnabled && !isCritical) {
      debugPrint("NOTIF: Bloqueada (Configuração Global Desativada)");
      return;
    }
    final pushEnabled = notificationSettings[category]?['push'] ?? true;
    if (!pushEnabled && !isCritical) {
      debugPrint(
        "NOTIF: Bloqueada pelo filtro do usuário (Categoria: $category, Push: $pushEnabled)",
      );
      return;
    }
    if (isDndEnabled && _isCurrentTimeInDndRange()) {
      if (isCritical && bypassDndForCritical) {
        debugPrint("NOTIF: Permitida (Crítica ignorando DND)");
      } else {
        debugPrint("NOTIF: Bloqueada (Modo Não Perturbe Ativo)");
        return;
      }
    }
    final notificationService = NotificationService();
    String channelId = 'plant_health_alerts';
    String channelName = 'Alertas de Saúde';
    Importance importance = Importance.max;
    Priority priority = Priority.high;
    if (title.contains("Treinando") ||
        title.contains("Treinamento IA iniciado")) {
      channelId = 'ai_training_channel';
      channelName = 'Treinamento de IA';
      importance = Importance.low;
      priority = Priority.low;
    }
    await notificationService.showNotification(
      id: title.contains("Treinando") ? 999 : math.Random().nextInt(1000),
      title: title,
      body: body,
      channelId: channelId,
      channelName: channelName,
      importance: importance,
      priority: priority,
      showProgress: title.contains("Treinando"),
      maxProgress: 100,
      progress: (aiTrainingProgress * 100).toInt(),
      onlyAlertOnce: title.contains("Treinando"),
    );
  }
  bool _isCurrentTimeInDndRange() {
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    final double current = currentTime.hour + currentTime.minute / 60.0;
    final double start = dndStartTime.hour + dndStartTime.minute / 60.0;
    final double end = dndEndTime.hour + dndEndTime.minute / 60.0;
    if (start <= end) {
      return current >= start && current <= end;
    } else {
      return current >= start || current <= end;
    }
  }
  void _reconnect() {
    print("APP: Tentando reconectar ao Host: $_effectiveHost");
    _addAlert("Tentando reconectar ao sistema...", category: 'connectivity');
    _setupWebSockets();
    if (isCloudMode) {
      _setupMQTT();
    } else {
      _setupNT4();
    }
  }
  void _setupWebSockets() {
    _wsChannel?.sink.close();
    if (_effectiveHost == "127.0.0.1" && !isSimulationMode) return;
    try {
      final wsUrl = _wsUrl;
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel!.stream.listen(
        (message) {
          if (!mounted) return;
          try {
            final data = jsonDecode(message);
            setState(() {
              isWebSocketConnected = true;
              data.forEach((key, val) {
                if (sensorData.containsKey(key)) {
                  _updateSensor(key, (val as num).toDouble());
                  _updateHistory(key, (val).toDouble());
                }
              });
            });
            _runAiRecommendation();
            _checkMoistureIrrigation();
            _scheduleUiRefresh();
          } catch (e) {
            debugPrint("WS Decode Error: $e");
          }
        },
        onDone: () {
          if (mounted) setState(() => isWebSocketConnected = false);
        },
        onError: (e) {
          if (mounted) setState(() => isWebSocketConnected = false);
          String errorMsg = e.toString();
          if (errorMsg.contains("errno = 1225")) {
            errorMsg =
                "Conexão Recusada pela Raspberry em $wsUrl. Verifique se o script Python está rodando na Pi.";
          }
          debugPrint("WS Stream Error: $errorMsg");
          if (isCloudMode) {
            _addAlert(
              "Dica: WebSockets podem falhar no 4G/Tunnels. Use o MQTT para dados.",
              category: 'connectivity',
            );
          } else {
            _addAlert(
              "Erro de Dados (Local): $errorMsg",
              category: 'connectivity',
            );
          }
        },
      );
    } catch (e) {
      debugPrint("WS Connection Error: $e");
      if (isCloudMode) {
        _addAlert(
          "WebSocket Remoto falhou. Verifique se o Host Remoto suporta portas extras.",
          category: 'connectivity',
        );
      }
    }
  }
  void _updateSensor(String key, double val) {
    if (!mounted) return;
    setState(() {
      final processed = _processSensorValue(key, val);
      sensorData[key] = processed;
      lastSensorUpdate[key] = DateTime.now();
      if (key == 'battery' &&
          val <= 10.0 &&
          !isEcoModeEnabled &&
          !_ecoModeManualOverride) {
        isEcoModeEnabled = true;
        _sendCommand('eco_mode', true);
        _addAlert(
          "BATERIA CRÍTICA: Modo Econômico ativado automaticamente.",
          category: 'system',
        );
      }
      if (key == 'battery' && val > 10.0) {
        _ecoModeManualOverride = false;
      }
    });
  }
  double _processSensorValue(String key, double newValue) {
    final String peerKey = _getPeerSensorKey(key);
    double correctedValue = newValue;
    if (peerKey.isNotEmpty && sensorData.containsKey(peerKey)) {
      final double peerValue = sensorData[peerKey]!;
      final double diff = (newValue - peerValue).abs();
      double tolerance = 15.0;
      if (key.startsWith('t')) tolerance = 4.0;
      if (key.startsWith('p')) tolerance = 0.8;
      if (diff > tolerance) {
        if (newValue <= 0.1 && peerValue > 0.1) {
          correctedValue = peerValue;
        } else if (peerValue <= 0.1 && newValue > 0.1) {
          correctedValue = newValue;
        } else {
          correctedValue = (newValue + peerValue) / 2;
        }
      }
    }
    if (_lastRawValues.containsKey(key)) {
      final lastVal = _lastRawValues[key]!;
      final diff = (correctedValue - lastVal).abs();
      double noiseThreshold = 15.0;
      if (key.startsWith('t')) noiseThreshold = 5.0;
      if (key.startsWith('p')) noiseThreshold = 1.0;
      if (diff > noiseThreshold) {
        final now = DateTime.now();
        final String notifKey = "noise_$key";
        if (!_sentNotifications.contains(notifKey)) {
          _lastNoiseNotification[key] = now;
          _showNotification(
            "Auto-Correção Ativa",
            "Ruído no sensor ${_getSensorConfig(key).name} corrigido via software.",
            category: 'sensor_noise',
          );
          _addAlert(
            "AUTO-CORREÇÃO: Ruído suavizado no sensor ${_getSensorConfig(key).name}",
            category: 'sensor_noise',
          );
          _sentNotifications.add(notifKey);
        }
        correctedValue = (lastVal * 0.7) + (correctedValue * 0.3);
      } else {
        _sentNotifications.remove("noise_$key");
      }
    }
    _lastRawValues[key] = correctedValue;
    return correctedValue;
  }
  String _getPeerSensorKey(String key) {
    switch (key) {
      case 'u1':
        return 'u2';
      case 'u2':
        return 'u1';
      case 't1':
        return 't2';
      case 't2':
        return 't1';
      case 'l1':
        return 'l2';
      case 'l2':
        return 'l1';
      case 'p1':
        return 'p2';
      case 'p2':
        return 'p1';
      default:
        return "";
    }
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
  void _updateHealthScore() {
    int score = 100;
    if (hasDisease) score -= 40;
    double water = sensorData['water_level'] ?? 100.0;
    if (water < 20) {
      score -= 20;
    } else if (water < 50) {
      score -= 5;
    }
    double battery = sensorData['battery'] ?? 100.0;
    if (battery < 15) score -= 10;
    sensorIntegrity.forEach((k, v) {
      if (!v) score -= 5;
    });
    double ph = sensorData['p1'] ?? 6.0;
    if (ph < 5.5 || ph > 6.5) score -= 10;
    if (score < 0) score = 0;
    setState(() {
      healthScore = score;
      plantExp += 1;
      if (score >= 80) {
        _checkAndIncrementStreak();
      }
      if (plantExp >= plantLevel * 100) {
        plantLevel++;
        plantExp = 0;
        _addAlert(
          "PARABÉNS! Nível $plantLevel alcançado!",
          category: 'gamification',
        );
      }
      if (plantLevel >= 2 && !badges.contains("🌱 Iniciante")) {
        badges.add("🌱 Iniciante");
        _addAlert("Badge Desbloqueada: Iniciante", category: 'gamification');
      }
      if (plantStreak >= 3 && !badges.contains("🔥 Constante")) {
        badges.add("🔥 Constante");
        _addAlert("Badge Desbloqueada: Constante", category: 'gamification');
      }
      if (healthScore == 100 && !badges.contains("⭐ Perfeita")) {
        badges.add("⭐ Perfeita");
        _addAlert(
          "Badge Desbloqueada: Saúde Perfeita",
          category: 'gamification',
        );
      }
    });
    _saveGamificationData();
  }
  void _checkAndIncrementStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString('last_perfect_health_date') ?? "";
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    if (lastDateStr != todayStr) {
      DateTime? lastDate;
      try {
        lastDate = lastDateStr.isEmpty ? null : DateTime.parse(lastDateStr);
      } catch (e) {
        print("Erro ao parsear data salva: $lastDateStr. Resetando.");
        lastDate = null;
      }
      if (lastDate != null) {
        final difference = today.difference(lastDate).inDays;
        if (difference == 1) {
          plantStreak++;
        } else if (difference > 1) {
          plantStreak = 1;
        }
      } else {
        plantStreak = 1;
      }
      await prefs.setString('last_perfect_health_date', todayStr);
      await prefs.setInt('plant_streak', plantStreak);
    }
  }
  Future<void> _saveGamificationData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('plant_streak', plantStreak);
    await prefs.setInt('plant_exp', plantExp);
    await prefs.setInt('plant_level', plantLevel);
    await prefs.setStringList('plant_badges', badges);
  }
  void _showHealthDiagnosis() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status da Planta",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Nível $plantLevel",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (healthScore > 80 ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "$healthScore",
                    style: TextStyle(
                      color: healthScore > 80
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: plantExp / (plantLevel * 100),
              backgroundColor: Colors.white10,
              color: Colors.greenAccent,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHealthMetric(
                "Estado Vital",
                hasDisease ? "Anomalia Detectada" : "Excelente",
                hasDisease ? Icons.warning_amber : Icons.check_circle,
                hasDisease ? Colors.redAccent : Colors.greenAccent,
              ),
              const SizedBox(height: 15),
              Text(
                "INSIGHTS DA IA",
                style: TextStyle(
                  fontSize: 10,
                  color: subTextColor,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  aiRecommendation,
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge(
                    Icons.local_fire_department,
                    "$plantStreak dias",
                    "Streak",
                  ),
                  _buildStatBadge(
                    Icons.auto_awesome,
                    "${badges.length}",
                    "Badges",
                  ),
                  _buildStatBadge(
                    Icons.psychology,
                    "${(confidence * 100).toStringAsFixed(0)}%",
                    "IA Conf.",
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("FECHAR", style: TextStyle(color: subTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _generateReport();
            },
            child: const Text("RELATÓRIO CSV"),
          ),
        ],
      ),
    );
  }
  Widget _buildHealthMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _buildStatBadge(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.amberAccent, size: 24),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }
  void _toggleMaintenanceMode(bool enable, {int minutes = 30}) {
    _maintenanceTimer?.cancel();
    if (enable) {
      setState(() {
        isMaintenanceMode = true;
        maintenanceRemainingSeconds = minutes * 60;
      });
      _addAlert(
        "Modo Manutenção: Ativado por $minutes minutos",
        category: 'system',
      );
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
      _addAlert("Modo Manutenção: Desativado", category: 'system');
    }
  }
  void _sendCommand(String topicSuffix, dynamic value) {
    dynamic payload = value;
    if (value is bool) {
      payload = value ? "1" : "0";
    }
    if (isCloudMode) {
      if (mqttClient?.connectionStatus?.state ==
          MqttConnectionState.connected) {
        final builder = MqttClientPayloadBuilder();
        builder.addString(payload.toString());
        mqttClient!.publishMessage(
          "$mqttTopicPrefix/cmd/$topicSuffix",
          MqttQos.atLeastOnce,
          builder.payload!,
        );
      }
    } else {
      if (topicSuffix == 'pump' && pumpPub != null) {
        client.addSample(pumpPub!, payload);
      } else if (topicSuffix == 'ph' && phPub != null) {
        client.addSample(phPub!, payload);
      } else if (topicSuffix == 'brightness' && brightnessPub != null) {
        client.addSample(brightnessPub!, payload);
      } else if (topicSuffix == 'fps' && targetFpsPub != null) {
        client.addSample(targetFpsPub!, payload);
      } else if (topicSuffix == 'ai_enable' && aiEnablePub != null) {
        client.addSample(aiEnablePub!, payload);
      } else if (topicSuffix == 'eco_mode' && ecoModePub != null) {
        client.addSample(ecoModePub!, payload);
      } else if (topicSuffix == 'config' && configPub != null) {
        client.addSample(configPub!, payload);
      } else if (topicSuffix == 'cmd' && cmdPub != null) {
        client.addSample(cmdPub!, payload);
      }
    }
  }
  Future<void> _saveToGallery(File file, String filename) async {
    try {
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Pictures/PlantGuard');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        final path = p.join(directory.path, filename);
        await file.copy(path);
        _addAlert("FOTO SALVA NA GALERIA: $filename", category: 'actions');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Foto salva em: Pictures/PlantGuard/$filename"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: "COMPARTILHAR",
              onPressed: () =>
                  Share.shareXFiles([XFile(path)], text: "Minha Planta"),
            ),
          ),
        );
      } else {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Minha Planta - $filename');
      }
    } catch (e) {
      print("Erro ao salvar na galeria: $e");
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Minha Planta - $filename');
    }
  }
  void _captureManualPhoto() async {
    if (_isCapturingPhoto) return;
    setState(() => _isCapturingPhoto = true);
    _addAlert("Iniciando captura de imagem...", category: 'actions');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Capturando imagem...")));
    try {
      final response = await http
          .get(
            Uri.parse(_captureUrl),
            headers: {
              "ngrok-skip-browser-warning": "true",
              "User-Agent": "PlantGuardApp/1.0",
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filename = 'plant_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = p.join(directory.path, filename);
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);
        await _saveToGallery(file, filename);
      } else {
        _addAlert(
          "Erro ao baixar foto: ${response.statusCode}. Tentando comando via MQTT...",
          category: 'actions',
        );
        _sendCommand('take_photo', 'now');
      }
    } catch (e) {
      _addAlert(
        "Erro de conexão HTTP. Tentando comando via MQTT...",
        category: 'actions',
      );
      _sendCommand('take_photo', 'now');
    } finally {
      if (mounted) setState(() => _isCapturingPhoto = false);
    }
  }
  void _runConsensusCalibration() {
    final List<List<String>> pairs = [
      ['u1', 'u2'],
      ['l1', 'l2'],
      ['t1', 't2'],
      ['p1', 'p2'],
    ];
    for (var pair in pairs) {
      final v1 = sensorData[pair[0]] ?? 0.0;
      final v2 = sensorData[pair[1]] ?? 0.0;
      final diff = (v1 - v2).abs();
      double threshold = 20.0;
      if (pair[0].startsWith('t')) threshold = 5.0;
      if (pair[0].startsWith('p')) threshold = 1.0;
      if (diff > threshold) {
        final key = "consensus_${pair[0]}";
        if (!_sentNotifications.contains(key)) {
          _showNotification(
            "Desvio de Sensor",
            "Diferença alta entre ${pair[0]} e ${pair[1]}. Verifique calibração.",
            category: 'sensor_error',
          );
          _addAlert(
            "CONSENSO: Desvio detectado entre ${pair[0]} e ${pair[1]}",
            category: 'sensor_error',
          );
          _sentNotifications.add(key);
        }
      } else {
        _sentNotifications.remove("consensus_${pair[0]}");
      }
    }
  }
  void _runFirstAidCheck() {
    bool hasRecentUpdate = false;
    final now = DateTime.now();
    lastSensorUpdate.forEach((key, lastUpdate) {
      if (now.difference(lastUpdate).inMinutes < 5) {
        hasRecentUpdate = true;
      }
    });
    if (!hasRecentUpdate && isConnected && !isSimulationMode) {
      if (!isFirstAidMode) {
        setState(() => isFirstAidMode = true);
        _showNotification(
          "Modo Primeiros Socorros",
          "Conexão instável. Exibindo últimos dados em cache.",
          category: 'connectivity',
        );
        _addAlert(
          "SISTEMA: Modo Primeiros Socorros Ativado",
          category: 'connectivity',
        );
      }
    } else {
      if (isFirstAidMode) {
        setState(() => isFirstAidMode = false);
        _addAlert(
          "SISTEMA: Conexão restaurada. Modo Primeiros Socorros Desativado",
        );
      }
    }
  }
  void _runObstructedSensorCheck() {
    final now = DateTime.now();
    if (now.hour >= 8 && now.hour <= 17) {
      final l1 = sensorData['l1'] ?? 0.0;
      final l2 = sensorData['l2'] ?? 0.0;
      if (l1 < 1.0 || l2 < 1.0) {
        final key = l1 < 1.0 ? 'l1' : 'l2';
        final lastNotif = _lastObstructedNotification[key];
        if (lastNotif == null || now.difference(lastNotif).inHours >= 2) {
          _lastObstructedNotification[key] = now;
          _showNotification(
            "Sensor Obstruído",
            "O sensor ${_getSensorConfig(key).name} parece estar coberto. Verifique a limpeza.",
            category: 'sensor_error',
          );
          _addAlert(
            "ALERTA: Possível obstrução no sensor ${_getSensorConfig(key).name}",
            category: 'sensor_error',
          );
        }
      }
    }
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
          if (!_sentNotifications.contains("sim_anomaly")) {
            _showNotification(
              "Alerta de Simulação",
              "Anomalia detectada nos sensores simulados.",
              category: 'plant_health',
            );
            _sentNotifications.add("sim_anomaly");
          }
        } else {
          _sentNotifications.remove("sim_anomaly");
        }
      });
    });
  }
  @override
  void dispose() {
    _wsChannel?.sink.close();
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
  void _addAlert(String message, {String category = 'system'}) {
    if (!isNotificationsEnabled) return;
    final bool isLogEnabled = notificationSettings[category]?['log'] ?? true;
    if (!isLogEnabled) return;
    final now = DateTime.now();
    final timestamp =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    setState(() {
      _alerts.insert(0, {
        'message': message,
        'timestamp': timestamp,
        'category': category,
      });
      if (_alerts.length > 50) _alerts.removeLast();
      _logs.insert(0, {
        'msg': message,
        'time': timestamp,
        'category': category,
      });
      if (_logs.length > 100) _logs.removeLast();
      if (category == 'plant_health' || category == 'sensor_error') {
        _systemState = "ATENÇÃO";
      } else if (message.toUpperCase().contains("ERRO") ||
          message.toLowerCase().contains("falhou") ||
          message.toLowerCase().contains("desconectado")) {
        _systemState = "ERRO";
      } else {
        _systemState = "ESTÁVEL";
      }
    });
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.addLog(message, category: category);
    } catch (e) {
    }
    _scheduleUiRefresh(visibleTabs: {0});
  }
  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_notifications_enabled', isNotificationsEnabled);
    await prefs.setBool('is_voice_assistant_enabled', isVoiceAssistantEnabled);
    await prefs.setBool('is_voice_audio_response', isVoiceAudioResponseEnabled);
    await prefs.setString(
      'notification_settings_v1',
      jsonEncode(notificationSettings),
    );
    await prefs.setBool('is_dnd_enabled', isDndEnabled);
    await prefs.setString(
      'dnd_start_time',
      "${dndStartTime.hour}:${dndStartTime.minute}",
    );
    await prefs.setString(
      'dnd_end_time',
      "${dndEndTime.hour}:${dndEndTime.minute}",
    );
    await prefs.setBool('bypass_dnd_critical', bypassDndForCritical);
  }
  String _defaultSensorNameForKey(String key) {
    switch (key) {
      case 'u1':
        return "Umidade Solo 1";
      case 'u2':
        return "Umidade Solo 2";
      case 'l1':
        return "Luz Ambiente 1";
      case 'l2':
        return "Luz Ambiente 2";
      case 't1':
        return "Temperatura 1";
      case 't2':
        return "Temperatura 2";
      case 'p1':
        return "Nível pH 1";
      case 'p2':
        return "Nível pH 2";
      case 'ec':
        return "Eletrocondutividade";
      case 'water_level':
        return "Nível de Água";
      case 'battery':
        return "Bateria";
      default:
        return "Sensor";
    }
  }
  String _sensorTypeForKey(String key) {
    if (key.startsWith('l')) return 'luminosidade';
    if (key.startsWith('t')) return 'temperatura';
    if (key.startsWith('u')) return 'umidade';
    if (key.startsWith('p')) return 'ph';
    if (key == 'ec') return 'eletrocondutividade';
    if (key == 'water_level') return 'nivel_agua';
    if (key == 'battery') return 'bateria';
    return 'desconhecido';
  }
  String? _normalizeArduinoPin(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    final up = raw.toUpperCase();
    final numMatch = RegExp(r'^\d{1,3}$').firstMatch(up);
    if (numMatch != null) {
      final n = int.tryParse(up);
      if (n == null) return null;
      if (n < 0 || n > 69) return null;
      return n.toString();
    }
    final aMatch = RegExp(r'^A(\d{1,2})$').firstMatch(up);
    if (aMatch != null) {
      final n = int.tryParse(aMatch.group(1)!);
      if (n == null) return null;
      if (n < 0 || n > 15) return null;
      return "A$n";
    }
    return null;
  }
  Map<String, Map<String, dynamic>> _buildDefaultSensorConfigs() {
    final Map<String, Map<String, dynamic>> cfg = {};
    for (final entry in _sensorSlotKeys.entries) {
      for (final key in entry.value) {
        cfg[key] = {
          'enabled': false,
          'name': _defaultSensorNameForKey(key),
          'unit': sensorUnits[key] ?? "",
          'type': entry.key,
          'channel': null,
        };
      }
    }
    return cfg;
  }
  List<String> _enabledSensorKeys() {
    final keys = sensorConfigs.entries
        .where((e) => e.value['enabled'] == true)
        .map((e) => e.key)
        .where((k) => sensorData.containsKey(k))
        .toList();
    keys.sort();
    return keys;
  }
  Future<void> _saveSensorConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sensor_configs_v1', jsonEncode(sensorConfigs));
    _syncSensorConfigsWithArduino();
  }
  void _syncSensorConfigsWithArduino() {
    sensorConfigs.forEach((key, config) {
      if (config['enabled'] == true && config['channel'] != null) {
        final Map<String, dynamic> cfgMsg = {
          'cfg': {'id': key, 'pin': config['channel'], 'enabled': true},
        };
        _sendCommand('config', jsonEncode(cfgMsg));
      }
    });
  }
  void _applySensorUnitsFromConfigs() {
    for (final key in sensorUnits.keys) {
      final unit = sensorConfigs[key]?['unit'];
      if (unit is String) {
        sensorUnits[key] = unit;
      }
    }
  }
  Future<void> _showSensorManager() async {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final enabledKeys = _enabledSensorKeys();
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.sensors, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Text("Configurar Sensores", style: TextStyle(color: textColor)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enabledKeys.isEmpty
                        ? "Nenhum sensor configurado."
                        : "${enabledKeys.length} sensores configurados.",
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: enabledKeys.map((key) {
                        final cfg = sensorConfigs[key] ?? {};
                        final name = (cfg['name'] as String?) ?? key;
                        final unit = (cfg['unit'] as String?) ?? "";
                        final type =
                            (cfg['type'] as String?) ?? _sensorTypeForKey(key);
                        final channel = cfg['channel'];
                        return ListTile(
                          leading: Icon(
                            _getSensorConfig(key).icon,
                            color: _getSensorConfig(key).color,
                          ),
                          title: Text(name, style: TextStyle(color: textColor)),
                          subtitle: Text(
                            "Tipo: $type | Unidade: $unit | Canal: ${channel ?? '-'} | ID: $key",
                            style: TextStyle(color: subTextColor, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () async {
                                  await _showSensorEditor(existingKey: key);
                                  setDialogState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () async {
                                  if (!mounted) return;
                                  setState(() {
                                    sensorConfigs[key]?['enabled'] = false;
                                  });
                                  _applySensorUnitsFromConfigs();
                                  await _saveSensorConfigs();
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("FECHAR"),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _showSensorEditor();
                  setDialogState(() {});
                },
                icon: const Icon(Icons.add),
                label: const Text("ADICIONAR"),
              ),
            ],
          );
        },
      ),
    );
  }
  Future<void> _showSensorEditor({String? existingKey}) async {
    final isEditing = existingKey != null;
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    String selectedType = isEditing
        ? ((sensorConfigs[existingKey]!['type'] as String?) ??
              _sensorTypeForKey(existingKey))
        : _sensorSlotKeys.keys.first;
    List<String> availableSlots(String type) {
      final slots = _sensorSlotKeys[type] ?? [];
      if (isEditing) return [existingKey];
      return slots.where((k) => sensorConfigs[k]?['enabled'] != true).toList();
    }
    String? selectedKey = isEditing
        ? existingKey
        : (availableSlots(selectedType).isNotEmpty
              ? availableSlots(selectedType).first
              : null);
    final cfg = selectedKey != null ? (sensorConfigs[selectedKey] ?? {}) : {};
    final nameController = TextEditingController(
      text: (cfg['name'] as String?) ?? "",
    );
    final unitController = TextEditingController(
      text: (cfg['unit'] as String?) ?? "",
    );
    final channelController = TextEditingController(
      text: cfg['channel'] != null ? cfg['channel'].toString() : "",
    );
    String? pinErrorText;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final slots = availableSlots(selectedType);
          if (!isEditing && selectedKey == null && slots.isNotEmpty) {
            selectedKey = slots.first;
          }
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            title: Text(
              isEditing ? "Editar Sensor" : "Adicionar Sensor",
              style: TextStyle(color: textColor),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: "Tipo",
                      border: OutlineInputBorder(),
                    ),
                    items: _sensorSlotKeys.keys
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: isEditing
                        ? null
                        : (v) {
                            if (v == null) return;
                            setDialogState(() {
                              selectedType = v;
                              final newSlots = availableSlots(selectedType);
                              selectedKey = newSlots.isNotEmpty
                                  ? newSlots.first
                                  : null;
                              final newCfg = selectedKey != null
                                  ? (sensorConfigs[selectedKey] ?? {})
                                  : {};
                              nameController.text =
                                  (newCfg['name'] as String?) ??
                                  (selectedKey != null
                                      ? _defaultSensorNameForKey(selectedKey!)
                                      : "");
                              unitController.text =
                                  (newCfg['unit'] as String?) ??
                                  (selectedKey != null
                                      ? (sensorUnits[selectedKey!] ?? "")
                                      : "");
                              channelController.text = newCfg['channel'] != null
                                  ? newCfg['channel'].toString()
                                  : "";
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedKey,
                    decoration: const InputDecoration(
                      labelText: "Slot",
                      border: OutlineInputBorder(),
                    ),
                    items: slots
                        .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: isEditing
                        ? null
                        : (v) {
                            if (v == null) return;
                            setDialogState(() {
                              selectedKey = v;
                              nameController.text = _defaultSensorNameForKey(v);
                              unitController.text = sensorUnits[v] ?? "";
                              channelController.text = "";
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Nome",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: "Unidade",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: channelController,
                    keyboardType: TextInputType.text,
                    onChanged: (_) {
                      if (pinErrorText != null) {
                        setDialogState(() {
                          pinErrorText = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Pino Arduino",
                      border: const OutlineInputBorder(),
                      errorText: pinErrorText,
                      helperText: "Ex: 2, 13, A0",
                    ),
                  ),
                  if (!isEditing && slots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        "Limite atingido para este tipo.",
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCELAR"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedKey == null) return;
                  final pinText = channelController.text.trim();
                  if (pinText.isEmpty) {
                    setDialogState(() {
                      pinErrorText = "Campo obrigatório";
                    });
                    return;
                  }
                  final normalizedPin = _normalizeArduinoPin(pinText);
                  if (normalizedPin == null) {
                    setDialogState(() {
                      pinErrorText = "Pino inválido";
                    });
                    return;
                  }
                  if (!mounted) return;
                  setState(() {
                    sensorConfigs[selectedKey!] = {
                      'enabled': true,
                      'name': nameController.text.trim().isEmpty
                          ? _defaultSensorNameForKey(selectedKey!)
                          : nameController.text.trim(),
                      'unit': unitController.text.trim(),
                      'type': selectedType,
                      'channel': normalizedPin,
                    };
                    _applySensorUnitsFromConfigs();
                  });
                  await _saveSensorConfigs();
                  if (_enabledSensorKeys().isNotEmpty &&
                      !_enabledSensorKeys().contains(activeGraphKey)) {
                    setState(() {
                      activeGraphKey = _enabledSensorKeys().first;
                    });
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("SALVAR"),
              ),
            ],
          );
        },
      ),
    );
  }
  Future<void> _showTrainAiDialog(BuildContext context) async {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.smart_toy, color: Colors.purpleAccent),
            const SizedBox(width: 10),
            Text("Treinar Modelo IA", style: TextStyle(color: textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.block, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Funções que serão DESABILITADAS:",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      "• Diagnóstico IA em tempo real\n"
                      "• Atualizações de telemetria em tempo real\n"
                      "• Processamento de vídeo pode ficar lento\n"
                      "• Algumas notificações podem atrasar\n"
                      "• Conexões MQTT/WebSocket instáveis",
                      style: TextStyle(color: textColor, fontSize: 12),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "O treinamento pode demorar horas dependendo do dataset e hardware.",
                      style: TextStyle(color: textColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "Pré-requisitos:",
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "• Dataset na pasta 'dataset'\n"
              "• Arquivo 'data.yaml' configurado\n"
              "• Espaço em disco suficiente",
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _confirmAndStartAiTraining();
            },
            icon: const Icon(Icons.warning),
            label: const Text("ENTENDI, INICIAR"),
          ),
        ],
      ),
    );
  }
  Future<void> _confirmAndStartAiTraining() async {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text("Confirmar Início", style: TextStyle(color: textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "O treinamento é um processo DEMORADO e IRREVERSÍVEL que afetará o modelo de IA usado pelo aplicativo.",
              style: TextStyle(color: textColor, fontSize: 13),
            ),
            const SizedBox(height: 15),
            Text(
              "Deseja realmente continuar?",
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("NÃO, CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SIM, TREINAR"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _startAiTraining();
    }
  }
  Future<void> _startAiTraining() async {
    if (isTrainingAi) return;
    setState(() {
      isTrainingAi = true;
      aiTrainingProgress = 0.0;
      aiTrainingStatus = "Iniciando treinamento...";
    });
    _showTrainingNotification(
      "Treinamento IA iniciado",
      "Preparando ambiente...",
    );
    try {
      if (raspIP.isEmpty) {
        throw Exception("Endereço IP da Raspberry não configurado.");
      }
      final trainingUrl = Uri.parse("http:
      setState(() {
        aiTrainingStatus = "Enviando comando para Raspberry...";
      });
      final response = await http
          .post(trainingUrl, headers: {"Content-Type": "application/json"})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          aiTrainingStatus = "Treinamento iniciado na Raspberry Pi!";
          aiTrainingProgress = 0.5; 
        });
        _addAlert("Sucesso: O treinamento começou na sua Raspberry Pi!");
      } else {
        throw Exception("A Raspberry retornou erro ${response.statusCode}");
      }
    } catch (e) {
      print("TRAIN ERROR: $e");
      _addAlert("Erro ao iniciar treino na Raspberry: $e");
      setState(() {
        isTrainingAi = false;
        aiTrainingStatus = "Falha na conexão";
      });
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            isTrainingAi = false;
          });
        }
      });
    }
  }
  void _showTrainingNotification(String title, String body) {
    if (!isNotificationsEnabled) return;
    _showNotification(title, body, category: 'system');
  }
  void _runAiRecommendation() {
    _updateHealthScore();
    if (isMaintenanceMode) return;
    _runConsensusCalibration();
    _runFirstAidCheck();
    _runObstructedSensorCheck();
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
      if (!_sentNotifications.contains("water_low")) {
        _showNotification(
          "Alerta de Água",
          "O nível de água está em ${water.toStringAsFixed(1)}%!",
          category: 'plant_health',
          isCritical: true,
        );
        _sentNotifications.add("water_low");
      }
      if (isEventRecordingEnabled) {
        _sendCommand('record_event', 'water_low');
      }
    } else {
      _sentNotifications.remove("water_low");
      if (ph < 5.5 || ph > 6.5) {
        problem = "pH fora do ideal ($ph)";
        cause = "Desequilíbrio químico";
        action = "Corrigir solução nutritiva";
        priority = "CRÍTICO";
        color = Colors.redAccent;
        if (!_sentNotifications.contains("ph_anomaly")) {
          _showNotification(
            "Alerta de pH",
            "O pH está fora da faixa ideal: $ph",
            category: 'plant_health',
            isCritical: true,
          );
          _sentNotifications.add("ph_anomaly");
        }
        if (isEventRecordingEnabled) {
          _sendCommand('record_event', 'ph_anomaly');
        }
      } else {
        _sentNotifications.remove("ph_anomaly");
        if (ec > 2.5) {
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
          if (!_sentNotifications.contains("battery_low")) {
            _showNotification(
              "Alerta de Bateria",
              "O sistema está com bateria baixa: ${battery.toStringAsFixed(1)}%",
              category: 'plant_health',
              isCritical: true,
            );
            _sentNotifications.add("battery_low");
          }
        } else {
          _sentNotifications.remove("battery_low");
          if (temp > 30) {
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
        }
      }
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
    final savedRemoteHost = prefs.getString('remote_host') ?? "";
    final savedVideoPort = prefs.getInt('video_port') ?? 5000;
    final savedWsPort = prefs.getInt('ws_port') ?? 8765;
    int sanitizedVideoPort = savedVideoPort;
    int sanitizedWsPort = savedWsPort;
    if (sanitizedVideoPort < 1 || sanitizedVideoPort > 65535) {
      sanitizedVideoPort = 5000;
    }
    if (sanitizedWsPort < 1 || sanitizedWsPort > 65535) sanitizedWsPort = 8765;
    final savedUseRemoteSsl = prefs.getBool('use_remote_ssl') == true;
    final savedPh = prefs.getDouble('ph_calib') ?? 0.5;
    final savedBrightness = prefs.getDouble('camera_brightness') ?? 0.0;
    final savedTargetFps = prefs.getInt('camera_target_fps') ?? 18;
    final savedAiEnabled = prefs.getBool('ai_enabled') == true;
    final savedCloudMode = prefs.getBool('cloud_mode') == true;
    final savedMqttBroker =
        prefs.getString('mqtt_broker') ?? "broker.hivemq.com";
    final savedMqttPort = prefs.getInt('mqtt_port') ?? 1883;
    final savedMqttTopic =
        prefs.getString('mqtt_topic') ?? "plantguard_pro/device_ref_9921";
    final savedAutoPumpEnabled = prefs.getBool('auto_pump_enabled') == true;
    final savedAutoPumpMode = prefs.getString('auto_pump_mode') ?? "Timer";
    final savedMoistureThreshold =
        prefs.getDouble('moisture_threshold') ?? 30.0;
    final savedAutoPumpInterval = prefs.getInt('auto_pump_interval') ?? 3600;
    final savedAutoPumpDuration = prefs.getInt('auto_pump_duration') ?? 10;
    final savedEventRecording = prefs.getBool('event_recording') == true;
    final savedVoiceAssistantEnabled =
        prefs.getBool('is_voice_assistant_enabled') == true;
    final savedVoiceAudioResponse =
        prefs.getBool('is_voice_audio_response') ?? true;
    final savedNotificationsEnabled =
        prefs.getBool('is_notifications_enabled') == true;
    final savedEcoMode = prefs.getBool('is_eco_mode_enabled') ?? false;
    final savedStreak = prefs.getInt('plant_streak') ?? 0;
    final savedExp = prefs.getInt('plant_exp') ?? 0;
    final savedLevel = prefs.getInt('plant_level') ?? 1;
    final savedBadges = prefs.getStringList('plant_badges') ?? [];
    final savedDashboardOrder =
        prefs.getStringList('dashboard_order') ??
        [
          'video',
          'health',
          'logs',
          'events',
          'hardware',
          'fps',
          'telemetry',
          'brightness',
          'plant3d',
        ];
    final savedAnalyticsOrder =
        prefs.getStringList('analytics_order') ?? ['chart', 'sensor_selector'];
    final savedControlOrder =
        prefs.getStringList('control_order') ??
        [
          'diagnosis',
          'irrigation_history',
          'irrigation_control',
          'maintenance',
          'ph_calibration',
          'camera',
          'diary',
        ];
    final savedSettingsOrder =
        prefs.getStringList('settings_order') ??
        ['personalizacao', 'funcionalidades', 'conexao', 'simulacao'];
    final savedPersonalizacaoOrder =
        prefs.getStringList('personalizacao_order') ??
        ['graphic_elements', 'font_style'];
    final savedFuncionalidadesOrder =
        prefs.getStringList('funcionalidades_order') ??
        [
          'notifications',
          'eco_mode',
          'voice_assistant',
          'auto_irrigation',
          'hud_sensors',
          'vacation_mode',
          'event_recording',
          'ai_enabled',
          'treinar_ia',
        ];
    final savedConexaoOrder =
        prefs.getStringList('conexao_order') ??
        [
          'access_guide',
          'rasp_ip',
          'remote_host',
          'remote_ports',
          'cloud_mode',
          'link_status',
          'websocket_status',
          'reset_db',
        ];
    final savedSimulacaoOrder =
        prefs.getStringList('simulacao_order') ??
        ['general_simulation', 'failure_simulator'];
    if (!savedDashboardOrder.contains('plant3d')) {
      savedDashboardOrder.add('plant3d');
    }
    final validKeys = [
      'video',
      'health',
      'logs',
      'events',
      'hardware',
      'fps',
      'telemetry',
      'brightness',
      'plant3d',
    ];
    savedDashboardOrder.removeWhere((k) => !validKeys.contains(k));
    for (var k in validKeys) {
      if (!savedDashboardOrder.contains(k)) savedDashboardOrder.add(k);
    }
    final validAnalyticsKeys = ['chart', 'sensor_selector'];
    savedAnalyticsOrder.removeWhere((k) => !validAnalyticsKeys.contains(k));
    for (var k in validAnalyticsKeys) {
      if (!savedAnalyticsOrder.contains(k)) savedAnalyticsOrder.add(k);
    }
    final validControlKeys = [
      'diagnosis',
      'irrigation_history',
      'irrigation_control',
      'maintenance',
      'ph_calibration',
      'camera',
      'diary',
    ];
    savedControlOrder.removeWhere((k) => !validControlKeys.contains(k));
    for (var k in validControlKeys) {
      if (!savedControlOrder.contains(k)) savedControlOrder.add(k);
    }
    final validSettingsKeys = [
      'personalizacao',
      'funcionalidades',
      'conexao',
      'simulacao',
    ];
    savedSettingsOrder.removeWhere((k) => !validSettingsKeys.contains(k));
    for (var k in validSettingsKeys) {
      if (!savedSettingsOrder.contains(k)) savedSettingsOrder.add(k);
    }
    final validPersonalizacaoKeys = ['graphic_elements', 'font_style'];
    savedPersonalizacaoOrder.removeWhere(
      (k) => !validPersonalizacaoKeys.contains(k),
    );
    for (var k in validPersonalizacaoKeys) {
      if (!savedPersonalizacaoOrder.contains(k)) {
        savedPersonalizacaoOrder.add(k);
      }
    }
    final validFuncionalidadesKeys = [
      'notifications',
      'eco_mode',
      'voice_assistant',
      'auto_irrigation',
      'hud_sensors',
      'vacation_mode',
      'event_recording',
      'ai_enabled',
      'treinar_ia',
    ];
    savedFuncionalidadesOrder.removeWhere(
      (k) => !validFuncionalidadesKeys.contains(k),
    );
    for (var k in validFuncionalidadesKeys) {
      if (!savedFuncionalidadesOrder.contains(k)) {
        savedFuncionalidadesOrder.add(k);
      }
    }
    final validConexaoKeys = [
      'access_guide',
      'rasp_ip',
      'remote_host',
      'remote_ports',
      'cloud_mode',
      'link_status',
      'websocket_status',
      'reset_db',
    ];
    savedConexaoOrder.removeWhere((k) => !validConexaoKeys.contains(k));
    for (var k in validConexaoKeys) {
      if (!savedConexaoOrder.contains(k)) savedConexaoOrder.add(k);
    }
    final validSimulacaoKeys = ['general_simulation', 'failure_simulator'];
    savedSimulacaoOrder.removeWhere((k) => !validSimulacaoKeys.contains(k));
    for (var k in validSimulacaoKeys) {
      if (!savedSimulacaoOrder.contains(k)) savedSimulacaoOrder.add(k);
    }
    final String? notifJson = prefs.getString('notification_settings_v1');
    if (notifJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(notifJson);
        decoded.forEach((category, settings) {
          if (notificationSettings.containsKey(category)) {
            final pushVal = settings['push'];
            final logVal = settings['log'];
            notificationSettings[category]!['push'] = (pushVal == true);
            notificationSettings[category]!['log'] = (logVal == true);
          }
        });
      } catch (e) {
        print("Erro ao carregar notificações: $e");
      }
    }
    final defaultSensorCfg = _buildDefaultSensorConfigs();
    final String? sensorCfgJson = prefs.getString('sensor_configs_v1');
    if (sensorCfgJson != null) {
      try {
        final decoded = jsonDecode(sensorCfgJson);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, val) {
            if (defaultSensorCfg.containsKey(key) && val is Map) {
              final merged = Map<String, dynamic>.from(defaultSensorCfg[key]!);
              val.forEach((k, v) {
                merged[k.toString()] = v;
              });
              if (merged['type'] == null) {
                merged['type'] = _sensorTypeForKey(key);
              }
              defaultSensorCfg[key] = merged;
            }
          });
        }
      } catch (e) {}
    }
    final savedDnd = prefs.getBool('is_dnd_enabled') == true;
    final savedDndStart = prefs.getString('dnd_start_time') ?? "22:00";
    final savedDndEnd = prefs.getString('dnd_end_time') ?? "07:00";
    final savedBypassDnd = prefs.getBool('bypass_dnd_critical') == true;
    _ipController.text = savedIp;
    _remoteHostController.text = savedRemoteHost;
    setState(() {
      raspIP = savedIp;
      remoteHost = savedRemoteHost;
      videoPort = sanitizedVideoPort;
      wsPort = sanitizedWsPort;
      useRemoteSsl = savedUseRemoteSsl;
      phCalibration = savedPh;
      cameraBrightness = savedBrightness;
      cameraTargetFps = _cameraFpsOptions.contains(savedTargetFps)
          ? savedTargetFps
          : _cameraFpsOptions.first;
      isAiEnabled = savedAiEnabled;
      isCloudMode = savedCloudMode;
      sensorConfigs = defaultSensorCfg;
      mqttBroker = savedMqttBroker;
      mqttPort = savedMqttPort;
      mqttTopicPrefix = savedMqttTopic;
      if (mqttTopicPrefix != "plantguard_pro/device_ref_9921") {
        mqttTopicPrefix = "plantguard_pro/device_ref_9921";
        prefs.setString('mqtt_topic', mqttTopicPrefix);
      }
      if (mqttBroker != "broker.hivemq.com") {
        mqttBroker = "broker.hivemq.com";
        prefs.setString('mqtt_broker', mqttBroker);
      }
      isAutoPumpEnabled = savedAutoPumpEnabled;
      autoPumpMode = savedAutoPumpMode;
      moistureThreshold = savedMoistureThreshold;
      autoPumpInterval = savedAutoPumpInterval;
      autoPumpDuration = savedAutoPumpDuration;
      isEventRecordingEnabled = savedEventRecording;
      isNotificationsEnabled = savedNotificationsEnabled;
      isVoiceAssistantEnabled = savedVoiceAssistantEnabled;
      isVoiceAudioResponseEnabled = savedVoiceAudioResponse;
      plantStreak = savedStreak;
      plantExp = savedExp;
      plantLevel = savedLevel;
      badges = savedBadges;
      dashboardOrder = savedDashboardOrder;
      analyticsOrder = savedAnalyticsOrder;
      controlOrder = savedControlOrder;
      settingsOrder = savedSettingsOrder;
      personalizacaoOrder = savedPersonalizacaoOrder;
      funcionalidadesOrder = savedFuncionalidadesOrder;
      conexaoOrder = savedConexaoOrder;
      simulacaoOrder = savedSimulacaoOrder;
      isEcoModeEnabled = savedEcoMode;
      isDndEnabled = savedDnd;
      dndStartTime = TimeOfDay(
        hour: int.parse(savedDndStart.split(":")[0]),
        minute: int.parse(savedDndStart.split(":")[1]),
      );
      dndEndTime = TimeOfDay(
        hour: int.parse(savedDndEnd.split(":")[0]),
        minute: int.parse(savedDndEnd.split(":")[1]),
      );
      bypassDndForCritical = savedBypassDnd;
      if (isAutoPumpEnabled) {
        _startAutoPump();
      }
    });
    _applySensorUnitsFromConfigs();
    if (phPub != null) {
      client.addSample(phPub!, phCalibration);
    }
    if (brightnessPub != null) {
      client.addSample(brightnessPub!, cameraBrightness);
    }
    if (targetFpsPub != null) {
      client.addSample(targetFpsPub!, cameraTargetFps);
    }
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.raspIP = raspIP;
      provider.remoteHost = remoteHost;
      provider.videoPort = videoPort;
      provider.wsPort = wsPort;
      provider.isCloudMode = isCloudMode;
      provider.useRemoteSsl = useRemoteSsl;
      provider.loadFromDb(); 
    } catch (e) {
      debugPrint("Provider: Erro na sincronização de configurações: $e");
    }
  }
  Future<void> _setupMQTT({String? manualBroker}) async {
    _clearSubscriptions();
    _setupSensorIntegrityCheck();
    final brokers = manualBroker != null
        ? [manualBroker]
        : ["test.mosquitto.org", "broker.hivemq.com", "broker.emqx.io"];
    for (var b in brokers) {
      if (!mounted) return;
      print("APP: Tentando conectar ao Broker MQTT: $b...");
      final clientId = 'PlantHealth_App_${math.Random().nextInt(100)}';
      mqttClient = MqttServerClient(b, clientId);
      mqttClient!.port = mqttPort;
      mqttClient!.keepAlivePeriod = 60;
      mqttClient!.connectTimeoutPeriod = 5000;
      mqttClient!.autoReconnect = true;
      mqttClient!.onDisconnected = () {
        if (mounted) setState(() => isConnected = false);
        _addAlert(
          "MQTT: Desconectado de $b. Tentando reconectar...",
          category: 'connectivity',
        );
      };
      mqttClient!.onConnected = () {
        if (mounted) {
          setState(() {
            isConnected = true;
            mqttBroker = b;
          });
        }
        _addAlert("MQTT: Conectado ao Broker $b", category: 'connectivity');
        for (var key in _enabledSensorKeys()) {
          mqttClient!.subscribe("$mqttTopicPrefix/$key", MqttQos.atMostOnce);
        }
        mqttClient!.subscribe("$mqttTopicPrefix/status", MqttQos.atMostOnce);
        mqttClient!.subscribe("$mqttTopicPrefix/disease", MqttQos.atMostOnce);
        mqttClient!.subscribe(
          "$mqttTopicPrefix/confidence",
          MqttQos.atMostOnce,
        );
        mqttClient!.subscribe("$mqttTopicPrefix/locked", MqttQos.atMostOnce);
        mqttClient!.subscribe("$mqttTopicPrefix/light_int", MqttQos.atMostOnce);
        mqttClient!.subscribe(
          "$mqttTopicPrefix/arduino_board",
          MqttQos.atMostOnce,
        );
        mqttClient!.subscribe(
          "$mqttTopicPrefix/camera_status",
          MqttQos.atMostOnce,
        );
        mqttClient!.subscribe(
          "$mqttTopicPrefix/camera_fps",
          MqttQos.atMostOnce,
        );
        mqttClient!.subscribe(
          "$mqttTopicPrefix/photo_saved",
          MqttQos.atMostOnce,
        );
      };
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      mqttClient!.connectionMessage = connMessage;
      try {
        await mqttClient!.connect();
        if (mqttClient!.connectionStatus!.state ==
            MqttConnectionState.connected) {
          _listenToMqttUpdates();
          return;
        }
      } catch (e) {
        print("APP: Falha no Broker $b: $e");
        _addAlert("Falha no Broker $b. Tentando próximo...");
      }
    }
    if (mounted) setState(() => isConnected = false);
    _addAlert("Erro: Nenhum Broker MQTT acessível.", category: 'connectivity');
  }
  void _listenToMqttUpdates() {
    if (mqttClient == null || mqttClient!.updates == null) return;
    mqttClient!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      final topic = c[0].topic;
      final sensorKey = topic.split('/').last;
      if (sensorData.containsKey(sensorKey)) {
        final rawVal = double.tryParse(pt) ?? 0.0;
        _updateSensor(sensorKey, rawVal);
        _updateHistory(sensorKey, rawVal);
      } else {
        if (mounted) {
          setState(() {
            if (sensorKey == "status") {
              plantStatus = pt;
            } else if (sensorKey == "disease")
              hasDisease = pt.toLowerCase() == "true";
            else if (sensorKey == "confidence")
              confidence = double.tryParse(pt) ?? 0.0;
            else if (sensorKey == "locked")
              isAccessGranted = pt.toLowerCase() != "true";
            else if (sensorKey == "light_int")
              currentLightIntensity = (double.tryParse(pt) ?? 0.0).toInt();
            else if (sensorKey == "arduino_board")
              arduinoBoardConnected = pt.toLowerCase() == "true";
            else if (sensorKey == "camera_fps")
              cameraCurrentFps = double.tryParse(pt) ?? 0.0;
            else if (sensorKey == "photo_saved") {
              _addAlert("FOTO SALVA: $pt", category: 'actions');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Foto salva na Raspberry: $pt"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          });
        }
      }
    });
  }
  void _setupSensorIntegrityCheck() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !isConnected) return;
      final now = DateTime.now();
      bool changed = false;
      sensorData.forEach((key, _) {
        if (sensorConfigs[key]?['enabled'] != true) return;
        final lastUpdate = lastSensorUpdate[key];
        final bool isHealthy =
            (lastUpdate != null && now.difference(lastUpdate).inSeconds < 10) &&
            !(simulatedFailures[key] ?? false);
        if (sensorIntegrity[key] != isHealthy) {
          sensorIntegrity[key] = isHealthy;
          changed = true;
          if (!isHealthy) {
            final config = _getSensorConfig(key);
            _addAlert(
              "ERRO: Sensor ${config.name} desconectado!",
              category: 'sensor_error',
            );
            _showNotification(
              "Troca de Sensor Necessária",
              "O sensor ${config.label} parece estar com defeito ou desconectado e precisa ser verificado/trocado.",
              category: 'sensor_replacement',
              isCritical: true,
            );
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
    if (isVacationMode) {
      if (avgMoisture < 20.0 && !pumpState) {
        _triggerPump("Segurança (Modo Férias - Solo Crítico)");
      }
      return;
    }
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
    if (isVacationMode && !reason.contains("Segurança")) {
      _addAlert("Irrigação Ignorada: Modo Férias Ativo");
      return;
    }
    if (mounted) {
      setState(() {
        pumpState = true;
        _sendCommand('pump', true);
        final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();
        final duration = autoPumpDuration.toDouble();
        _irrigationHistory.insert(0, [timestamp, duration]);
        if (_irrigationHistory.length > 5) _irrigationHistory.removeLast();
      });
      _addAlert("$reason: Bomba ligada", category: 'actions');
      _autoPumpOffTimer?.cancel();
      _autoPumpOffTimer = Timer(Duration(seconds: autoPumpDuration), () {
        if (mounted) {
          setState(() {
            pumpState = false;
            _sendCommand('pump', false);
          });
          _addAlert("$reason: Bomba desligada", category: 'actions');
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
              children: _enabledSensorKeys().map((key) {
                final cfg = _getSensorConfig(key);
                final isSelected = comparisonSensors.contains(key);
                return CheckboxListTile(
                  title: Text(cfg.name),
                  secondary: Icon(cfg.icon, color: cfg.color, size: 20),
                  value: isSelected,
                  onChanged: (val) {
                    if (val != null) {
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
                    }
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
  void _showFullscreenCamera(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text("Câmera em Tela Cheia"),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Mjpeg(
                isLive: true,
                stream: _videoUrl,
                headers: const {
                  "ngrok-skip-browser-warning": "true",
                  "User-Agent": "PlantGuardApp/1.0",
                },
                error: (context, error, stack) => const Center(
                  child: Text(
                    "Erro ao carregar stream",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
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
  Widget _buildDiaryCard(Map<String, dynamic> note, {VoidCallback? onDelete}) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    final timestamp = note['timestamp'];
    final dateMillis = (timestamp is int)
        ? timestamp
        : (int.tryParse(timestamp?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch);
    final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
    final rawIsReminder = note['is_reminder'];
    final isReminder =
        (rawIsReminder == 1 || rawIsReminder == true || rawIsReminder == "1");
    final reminderTimeMillis = note['reminder_time'] as int?;
    final reminderDate = reminderTimeMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(reminderTimeMillis)
        : null;
    final String noteText = note['note']?.toString() ?? "Nota vazia";
    final String? imagePath = note['image_path']?.toString();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isReminder
              ? Colors.blueAccent.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : Colors.black12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isReminder
                ? Colors.blueAccent.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath != null && File(imagePath).existsSync())
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(File(imagePath)),
                      ),
                    ),
                  );
                },
                child: Image.file(
                  File(imagePath),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            IntrinsicHeight(
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 6,
                        color: isReminder
                            ? Colors.blueAccent
                            : Colors.orangeAccent,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isReminder
                                        ? Icons.alarm
                                        : Icons.description_outlined,
                                    color: isReminder
                                        ? Colors.blueAccent
                                        : Colors.orangeAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isReminder
                                        ? "LEMBRETE AGENDADO"
                                        : "REGISTRO DE CULTIVO",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                      color: isReminder
                                          ? Colors.blueAccent
                                          : Colors.orangeAccent,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      color: subTextColor,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                noteText,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  height: 1.5,
                                  fontWeight: isReminder
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              if (isReminder && reminderDate != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.blueAccent.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.event_available,
                                        color: Colors.blueAccent,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Notificar em: ${reminderDate.day}/${reminderDate.month} às ${reminderDate.hour}:${reminderDate.minute.toString().padLeft(2, '0')}",
                                        style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onDelete != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onDelete,
                          child: Container(
                            width: 50,
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black12,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showDiaryListDialog() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    String filter = "Tudo";
    final provider = Provider.of<AppProvider>(context, listen: false);
    final diaryNotes = provider.diaryNotes;
    showDialog(
      context: context,
      builder: (context) => Consumer<AppProvider>(
        builder: (context, provider, child) => StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredNotes = provider.diaryNotes.where((note) {
              final isReminder = (note['is_reminder'] == 1);
              if (filter == "Lembretes") return isReminder;
              if (filter == "Recados") return !isReminder;
              return true;
            }).toList();
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: Colors.blueAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Diário (${provider.diaryNotes.length})",
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: () async {
                          await provider.loadFromDb();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ["Tudo", "Lembretes", "Recados"].map((f) {
                        final isSelected = filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              f,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.blueAccent.withOpacity(0.2),
                            onSelected: (val) {
                              if (val) setDialogState(() => filter = f);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: filteredNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              filter == "Lembretes"
                                  ? Icons.alarm_off
                                  : Icons.note_alt_outlined,
                              size: 40,
                              color: subTextColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Nenhum registro em \"$filter\"",
                              style: TextStyle(color: subTextColor),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          return _buildDiaryCard(
                            note,
                            onDelete: () async {
                              await provider.deleteDiaryNote(note['id']);
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                  ),
                  child: const Text("FECHAR"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _showAddDiaryDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("ADICIONAR"),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  Future<void> _showAddDiaryDialog() async {
    final controller = TextEditingController();
    bool isReminder = false;
    DateTime? selectedDateTime;
    String? capturedImagePath;
    bool isCapturing = false;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Nova Entrada no Diário"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (capturedImagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      File(capturedImagePath!),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: "Ex: Folhas com manchas amarelas",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 15,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 120,
                        child: ElevatedButton(
                          key: const ValueKey('btn_gallery'),
                          onPressed: isCapturing
                              ? null
                              : () async {
                                  final picker = ImagePicker();
                                  final pickedFile = await picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (pickedFile != null && mounted) {
                                    final directory =
                                        await getApplicationDocumentsDirectory();
                                    final filename =
                                        'journal_picked_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                    final path = p.join(
                                      directory.path,
                                      filename,
                                    );
                                    await File(pickedFile.path).copy(path);
                                    setDialogState(() {
                                      capturedImagePath = path;
                                    });
                                    try {
                                      final provider = Provider.of<AppProvider>(
                                        context,
                                        listen: false,
                                      );
                                      provider.loadFromDb();
                                    } catch (e) {}
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            foregroundColor: Colors.blueAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library, size: 24),
                              SizedBox(height: 4),
                              Text(
                                "GALERIA",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: ElevatedButton(
                          key: const ValueKey('btn_rasp'),
                          onPressed: isCapturing
                              ? null
                              : () async {
                                  await Future.delayed(
                                    const Duration(milliseconds: 50),
                                  );
                                  if (!mounted) return;
                                  setDialogState(() => isCapturing = true);
                                  try {
                                    final response = await http.get(
                                      Uri.parse(_captureUrl),
                                      headers: {
                                        "ngrok-skip-browser-warning": "true",
                                        "User-Agent": "PlantGuardApp/1.0",
                                      },
                                    );
                                    if (response.statusCode == 200) {
                                      final directory =
                                          await getApplicationDocumentsDirectory();
                                      final filename =
                                          'journal_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                      final path = p.join(
                                        directory.path,
                                        filename,
                                      );
                                      final file = File(path);
                                      await file.writeAsBytes(
                                        response.bodyBytes,
                                      );
                                      await _saveToGallery(file, filename);
                                      if (mounted) {
                                        setDialogState(() {
                                          capturedImagePath = path;
                                        });
                                      }
                                    } else {
                                      _addAlert(
                                        "Erro ao capturar foto da Raspberry",
                                      );
                                    }
                                  } catch (e) {
                                    _addAlert(
                                      "Erro de conexão com Raspberry: $e",
                                    );
                                    final picker = ImagePicker();
                                    final pickedFile = await picker.pickImage(
                                      source: ImageSource.camera,
                                    );
                                    if (pickedFile != null && mounted) {
                                      final directory =
                                          await getApplicationDocumentsDirectory();
                                      final filename =
                                          'journal_camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                      final path = p.join(
                                        directory.path,
                                        filename,
                                      );
                                      await File(pickedFile.path).copy(path);
                                      if (mounted) {
                                        setDialogState(() {
                                          capturedImagePath = path;
                                        });
                                      }
                                    }
                                  } finally {
                                    if (mounted) {
                                      setDialogState(() {
                                        isCapturing = false;
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            foregroundColor: Colors.blueAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              isCapturing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blueAccent,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt, size: 24),
                              const SizedBox(height: 4),
                              const Text(
                                "RASP",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  activeColor: Colors.blueAccent,
                  title: const Text("Definir Lembrete"),
                  subtitle: Text(
                    isReminder
                        ? (selectedDateTime == null
                              ? "Selecione data/hora"
                              : "${selectedDateTime!.day}/${selectedDateTime!.month} ${selectedDateTime!.hour}:${selectedDateTime!.minute.toString().padLeft(2, '0')}")
                        : "Apenas anotação",
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: isReminder,
                  onChanged: (val) async {
                    if (val) {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.blueAccent,
                                onPrimary: Colors.white,
                                surface: Color(0xFF1E1E1E),
                                onSurface: Colors.white,
                              ),
                              dialogBackgroundColor: const Color(0xFF121212),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.blueAccent,
                                  onPrimary: Colors.white,
                                  surface: Color(0xFF1E1E1E),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          setDialogState(() {
                            isReminder = true;
                            selectedDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    } else {
                      setDialogState(() {
                        isReminder = false;
                        selectedDateTime = null;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
              child: const Text("CANCELAR"),
            ),
            ElevatedButton(
              onPressed: () async {
                final noteText = controller.text.trim();
                if (noteText.isNotEmpty || capturedImagePath != null) {
                  try {
                    final provider = Provider.of<AppProvider>(
                      context,
                      listen: false,
                    );
                    Navigator.pop(context);
                    await provider.addDiaryNote(
                      noteText,
                      isReminder: isReminder,
                      reminderTime: selectedDateTime,
                      imagePath: capturedImagePath,
                    );
                  } catch (e) {
                    debugPrint("Erro ao salvar nota: $e");
                    _addAlert("Erro ao salvar no diário");
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text("SALVAR"),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _showFailureSimulatorDialog() async {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    await showDialog(
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
                    children: _enabledSensorKeys().map((key) {
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
                        activeThumbColor: Colors.red,
                        onChanged: (val) {
                          if (mounted) {
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
                          }
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
                  for (var key in _enabledSensorKeys()) {
                    final lastUpdate = lastSensorUpdate[key];
                    final bool isHealthy =
                        isSimulationMode ||
                        (lastUpdate != null &&
                            DateTime.now().difference(lastUpdate).inSeconds <
                                10);
                    sensorIntegrity[key] = isHealthy;
                  }
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
  List<Map<String, String>> _getAlerts() {
    return _alerts;
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
  void _initSpeech() async {
    if (Platform.isWindows || Platform.isLinux) {
      print(
        "Voz: O plugin speech_to_text não suporta Windows/Linux nativamente.",
      );
      return;
    }
    try {
      await _tts.setLanguage("pt-BR");
      await _tts.setSpeechRate(0.5);
    } catch (e) {
      print("Voz: Erro ao inicializar TTS: $e");
    }
  }
  void _speak(String text) async {
    if (!isVoiceAssistantEnabled) return;
    if (isVoiceAudioResponseEnabled) {
      await _tts.speak(text);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isVoiceAudioResponseEnabled
              ? Colors.blueAccent.withValues(alpha: 0.9)
              : Colors.redAccent.withValues(alpha: 0.9),
          action: SnackBarAction(
            label: "OK",
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }
  void _processVoiceCommand(String command) {
    final cmd = command.toLowerCase();
    String response = "";
    if (cmd.contains("como está") ||
        cmd.contains("status") ||
        cmd.contains("saúde")) {
      double u1 = sensorData['u1'] ?? 0;
      double t1 = sensorData['t1'] ?? 0;
      response =
          "A saúde da planta está em $healthScore%. A umidade do solo é de ${u1.toStringAsFixed(1)}% e a temperatura é de ${t1.toStringAsFixed(1)} graus.";
      if (hasDisease) {
        response += " Atenção: detectei sinais de doença nas folhas.";
      }
    } else if (cmd.contains("regar") ||
        cmd.contains("bomba") ||
        cmd.contains("água")) {
      response = "Entendido. Iniciando irrigação manual agora.";
      _sendCommand('pump', 'on');
    } else if (cmd.contains("foto") || cmd.contains("capturar")) {
      response = "Entendido. Capturando foto da planta.";
      _captureManualPhoto();
    } else if (cmd.contains("ajuda") || cmd.contains("socorro")) {
      response =
          "Eu posso te dizer o status da planta, tirar fotos ou ativar a bomba de água. Basta perguntar.";
    } else {
      response =
          "Desculpe, não entendi o comando '$command'. Tente perguntar sobre a saúde da planta.";
    }
    _speak(response);
    _voiceTimer?.cancel();
    _voiceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _lastWords = "";
        });
      }
    });
  }
  void _showVoiceCommandsHelpDialog() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.greenAccent),
            const SizedBox(width: 10),
            Text(
              "Comandos Disponíveis",
              style: TextStyle(color: textColor, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildVoiceCommandItem(
              "Saúde / Status",
              "Informa saúde, umidade e temperatura.",
              Icons.health_and_safety_outlined,
              Colors.greenAccent,
            ),
            _buildVoiceCommandItem(
              "Regar / Água / Bomba",
              "Ativa a irrigação manual imediatamente.",
              Icons.water_drop_outlined,
              Colors.blueAccent,
            ),
            _buildVoiceCommandItem(
              "Foto / Capturar",
              "Tira uma foto em tempo real da planta.",
              Icons.camera_alt_outlined,
              Colors.orangeAccent,
            ),
            _buildVoiceCommandItem(
              "Gráfico / Telemetria",
              "Abre a aba de gráficos e sensores.",
              Icons.analytics_outlined,
              Colors.purpleAccent,
            ),
            _buildVoiceCommandItem(
              "Configurações / Ajustes",
              "Navega para a aba de configurações.",
              Icons.settings_outlined,
              Colors.grey,
            ),
            _buildVoiceCommandItem(
              "Ajuda / Socorro",
              "Eu explico o que posso fazer por você.",
              Icons.info_outline,
              Colors.amberAccent,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "ENTENDI",
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildVoiceCommandItem(
    String command,
    String description,
    IconData icon,
    Color color,
  ) {
    final isDark = widget.isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  void _listen() async {
    if (!isVoiceAssistantEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "O assistente de voz está desativado nas configurações.",
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('Voz Status: $status'),
        onError: (error) => print('Voz Erro: $error'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _lastWords = val.recognizedWords;
              if (val.finalResult) {
                _isListening = false;
                _processVoiceCommand(_lastWords);
              }
            });
          },
          localeId: "pt_BR",
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }
  Future<void> _resetDiaryTable() async {
    if (_database == null) return;
    try {
      await _database!.execute('DROP TABLE IF EXISTS diary');
      await _database!.execute(
        'CREATE TABLE diary(id INTEGER PRIMARY KEY AUTOINCREMENT, note TEXT, timestamp INTEGER, is_reminder INTEGER DEFAULT 0, reminder_time INTEGER)',
      );
      await _loadDiaryFromDb();
      _addAlert("Diário resetado com sucesso");
      print("DB: Tabela diary resetada");
    } catch (e) {
      _addAlert("Erro ao resetar diário: $e");
    }
  }
  Future<void> _showMqttConfigDialog() async {
    final brokerController = TextEditingController(text: mqttBroker);
    final portController = TextEditingController(text: mqttPort.toString());
    final topicController = TextEditingController(text: mqttTopicPrefix);
    await showDialog(
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
      serverBaseAddress: _effectiveHost,
      onConnect: () {
        if (isConnected) return;
        setState(() => isConnected = true);
        pumpPub = client.publishNewTopic('/SmartDashboard/CmdPump', 'bool');
        phPub = client.publishNewTopic('/SmartDashboard/PH_Offset', 'float64');
        brightnessPub = client.publishNewTopic(
          '/SmartDashboard/CameraBrightness',
          'float64',
        );
        targetFpsPub = client.publishNewTopic(
          '/SmartDashboard/CameraTargetFPS',
          'float64',
        );
        aiEnablePub = client.publishNewTopic(
          '/SmartDashboard/AIEnable',
          'bool',
        );
        ecoModePub = client.publishNewTopic('/SmartDashboard/EcoMode', 'bool');
        configPub = client.publishNewTopic(
          '/SmartDashboard/ArduinoConfig',
          'string',
        );
        cmdPub = client.publishNewTopic('/SmartDashboard/ArduinoCmd', 'string');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (pumpPub != null) client.addSample(pumpPub!, pumpState);
          if (phPub != null) client.addSample(phPub!, phCalibration);
          if (brightnessPub != null) {
            client.addSample(brightnessPub!, cameraBrightness);
          }
          if (targetFpsPub != null) {
            client.addSample(targetFpsPub!, cameraTargetFps);
          }
          if (aiEnablePub != null) {
            client.addSample(aiEnablePub!, isAiEnabled);
          }
          if (ecoModePub != null) {
            client.addSample(ecoModePub!, isEcoModeEnabled);
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
        if (v == null) return;
        final newFps = (v as num).toDouble();
        if ((cameraCurrentFps - newFps).abs() < 0.1) return;
        setState(() {
          cameraCurrentFps = newFps;
        });
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
          final double lastVal = sensorData[key] ?? 0.0;
          final double deadband = (key.startsWith('t') || key.startsWith('u'))
              ? 0.5
              : 0.1;
          if ((val - lastVal).abs() < deadband &&
              sensorIntegrity[key] == true) {
            return;
          }
          _updateSensor(key, val);
          _updateHistory(key, val);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String title = "IA Real-Time";
    List<Widget> actions = [
      IconButton(
        icon: Icon(
          _isListening ? Icons.mic : Icons.mic_none,
          color: _isListening
              ? Colors.redAccent
              : (isDark ? Colors.white : Colors.black87),
        ),
        onPressed: _listen,
        tooltip: "Comando por Voz",
      ),
    ];
    if (_selectedIndex == 1) {
      title = "Telemetria";
      actions.addAll([
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
      ]);
    } else if (_selectedIndex == 2) {
      title = "Painel de Ação";
    } else if (_selectedIndex == 3) {
      title = "Configuração";
      actions.add(
        IconButton(
          icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: widget.onThemeToggle,
          tooltip: "Alternar Tema",
        ),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isWebSocketConnected || (isCloudMode && isConnected))
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCloudMode
                                ? "TELEMETRIA NUVEM ATIVA"
                                : "ALTA VELOCIDADE ATIVA",
                            style: const TextStyle(
                              fontSize: 7,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: actions,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
          selectedItemColor: Colors.green,
          unselectedItemColor: isDark ? Colors.white24 : Colors.black26,
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildCurrentTab(),
              ),
              if (_isListening || _lastWords.isNotEmpty)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: AnimatedOpacity(
                    opacity: (_isListening || _lastWords.isNotEmpty)
                        ? 1.0
                        : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isListening
                              ? Colors.greenAccent.withValues(alpha: 0.5)
                              : Colors.white10,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isListening)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.mic,
                                        color: Colors.redAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "OUVINDO...",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                _lastWords.isEmpty
                                    ? "Fale algo..."
                                    : _lastWords,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: _lastWords.isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                          if (!_isListening && _lastWords.isNotEmpty)
                            Positioned(
                              top: -10,
                              right: -10,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                                onPressed: () {
                                  _voiceTimer?.cancel();
                                  setState(() {
                                    _lastWords = "";
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildVideoCard(Color textColor, Color subTextColor, bool isDark) {
    return _buildInteractiveCard(
      height: 350,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Mjpeg(
                isLive: _isStreamActive,
                error: (context, error, stack) {
                  if (isSimulationMode) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Opacity(
                            opacity: 0.2,
                            child: Icon(
                              Icons.eco,
                              size: 120,
                              color: Colors.greenAccent,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.bug_report,
                                color: Colors.blueAccent,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "MODO SIMULAÇÃO ATIVO",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 2,
                                ),
                              ),
                              const Text(
                                "Câmera Real Indisponível",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  "Gerando dados randômicos...",
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Positioned(
                            top: 20,
                            left: 20,
                            child: Text(
                              "DEBUG_FEED: 127.0.0.1",
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 8,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final errorMsg = error.toString();
                  String userError = "Câmera não encontrada";
                  if (errorMsg.contains("1225")) {
                    userError = "Raspberry recusou a conexão (Script OFF?)";
                  } else if (errorMsg.contains("Timeout")) {
                    userError = "Tempo esgotado ao buscar vídeo";
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.videocam_off,
                          color: Colors.redAccent,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          userError,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            "Erro: $errorMsg",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Text(
                          "URL: $_videoUrl",
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _reconnect,
                          child: const Text(
                            "TENTAR NOVAMENTE",
                            style: TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                stream: _videoUrl,
                headers: const {
                  "ngrok-skip-browser-warning": "true",
                  "User-Agent": "PlantGuardApp/1.0",
                },
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => _showFullscreenCamera(context),
                  ),
                ),
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
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildHardwareCard(Color textColor) {
    return _buildInteractiveCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(
              arduinoBoardConnected ? Icons.developer_board : Icons.usb_off,
              color: arduinoBoardConnected ? Colors.greenAccent : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hardware: Arduino UNO",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    arduinoBoardConnected
                        ? "Placa conectada à Raspberry"
                        : "Placa não detectada",
                    style: TextStyle(
                      color: arduinoBoardConnected
                          ? Colors.greenAccent.withValues(alpha: 0.8)
                          : Colors.redAccent.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (arduinoBoardConnected)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _sendCommand('cmd', jsonEncode({'cmd': 'register_rfid'}));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Aproxime o novo cartão do sensor..."),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.add_card,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                    label: const Text(
                      "RFID",
                      style: TextStyle(fontSize: 10, color: Colors.blueAccent),
                    ),
                  ),
                  const Badge(label: Text("ON"), backgroundColor: Colors.green),
                ],
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildFpsCard(Color textColor, Color subTextColor, bool isDark) {
    return _buildInteractiveCard(
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
                  iconEnabledColor: isDark ? Colors.greenAccent : Colors.green,
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
    );
  }
  Widget _buildBrightnessCard(Color textColor, Color subTextColor) {
    return _buildInteractiveCard(
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
            const SizedBox(height: 15),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.amberAccent,
                thumbColor: Colors.amberAccent,
                overlayColor: Colors.amberAccent.withValues(alpha: 0.1),
                inactiveTrackColor: Colors.amberAccent.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: cameraBrightness,
                min: -100,
                max: 100,
                onChanged: (v) => setState(() => cameraBrightness = v),
                onChangeEnd: (v) async {
                  _sendCommand('brightness', v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('camera_brightness', v);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildPlant3DView(Color textColor, Color subTextColor, bool isDark) {
    final double healthOpacity = (healthScore / 100).clamp(0.1, 1.0);
    final double waterScale = ((sensorData['u1'] ?? 50) / 100).clamp(0.5, 1.2);
    return _buildInteractiveCard(
      height: 200,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.view_in_ar, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Text(
                    "Visualização 3D (Beta)",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    "REATIVO",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 40),
                        child: Container(
                          width: 80,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, 30),
                        child: Container(
                          width: 60,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.brown[400],
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(15),
                              bottomRight: Radius.circular(15),
                              topLeft: Radius.circular(5),
                              topRight: Radius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      AnimatedScale(
                        scale: waterScale,
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        child: AnimatedOpacity(
                          opacity: healthOpacity,
                          duration: const Duration(seconds: 1),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _build3DLeaf(true),
                                  const SizedBox(width: 4),
                                  _build3DLeaf(false),
                                ],
                              ),
                              Container(
                                width: 6,
                                height: 30,
                                color: Colors.green[800],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                "A planta reage à umidade e saúde",
                style: TextStyle(color: subTextColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _build3DLeaf(bool left) {
    return Transform.rotate(
      angle: left ? -0.4 : 0.4,
      child: Container(
        width: 30,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green[400],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(left ? 30 : 5),
            topRight: Radius.circular(left ? 5 : 30),
            bottomLeft: const Radius.circular(30),
            bottomRight: const Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInteractiveCardCard(
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    return _buildInteractiveCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: isDark ? Colors.white70 : Colors.black87,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  "CUSTOMIZAÇÃO",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              "Use a aba de personalização para ajustar o visual do aplicativo.",
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildMonitorTab(key: const PageStorageKey('monitor_tab'));
      case 1:
        return _buildAnalyticsTab(key: const PageStorageKey('analytics_tab'));
      case 2:
        return _buildControlTab(key: const PageStorageKey('control_tab'));
      case 3:
        return _buildSettingsTab(key: const PageStorageKey('settings_tab'));
      default:
        return _buildMonitorTab(key: const PageStorageKey('monitor_tab'));
    }
  }
  Widget _buildMonitorTab({Key? key}) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return ReorderableListView(
      key: key,
      buildDefaultDragHandles: false,
      header: Column(
        children: [
          if (isEcoModeEnabled)
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.eco, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "MODO ECONÔMICO ATIVO: Economizando bateria da Raspberry Pi",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (isFirstAidMode)
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.orangeAccent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "MODO PRIMEIROS SOCORROS: Dados em cache",
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      onReorder: (int oldIndex, int newIndex) async {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final String item = dashboardOrder.removeAt(oldIndex);
          dashboardOrder.insert(newIndex, item);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('dashboard_order', dashboardOrder);
      },
      children: dashboardOrder.map((key) {
        Widget card;
        switch (key) {
          case 'video':
            card = _buildVideoCard(textColor, subTextColor, isDark);
            break;
          case 'health':
            card = _buildHealthGaugeCard();
            break;
          case 'events':
            card = _buildEventGallery();
            break;
          case 'hardware':
            card = _buildHardwareCard(textColor);
            break;
          case 'fps':
            card = _buildFpsCard(textColor, subTextColor, isDark);
            break;
          case 'telemetry':
            card = _buildQuickTelemetrySection();
            break;
          case 'brightness':
            card = _buildBrightnessCard(textColor, subTextColor);
            break;
          case 'plant3d':
            card = _buildPlant3DView(textColor, subTextColor, isDark);
            break;
          default:
            return SizedBox(key: ValueKey('ghost_$key'));
        }
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              card,
              Positioned(
                top: 5,
                right: 5,
                child: ReorderableDragStartListener(
                  index: dashboardOrder.indexOf(key),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildDiaryTab() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final isDark = widget.isDarkMode;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subTextColor = isDark ? Colors.white54 : Colors.black54;
        final diaryNotes = provider.diaryNotes;
        if (diaryNotes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories,
                  size: 80,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                const SizedBox(height: 20),
                Text(
                  "Seu diário está vazio",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Comece a registrar a evolução da sua planta",
                  style: TextStyle(color: subTextColor),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showAddDiaryDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("NOVO REGISTRO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInteractiveCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              diaryNotes.length.toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.orangeAccent,
                              ),
                            ),
                            Text(
                              "REGISTROS",
                              style: TextStyle(
                                fontSize: 10,
                                color: subTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInteractiveCard(
                      onTap: _showAddDiaryDialog,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 24,
                              color: Colors.greenAccent,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "ADICIONAR",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: diaryNotes.length,
                itemBuilder: (context, index) {
                  final note = diaryNotes[index];
                  return _buildDiaryCard(
                    note,
                    onDelete: () async {
                      await provider.deleteDiaryNote(note['id']);
                      await _loadDiaryFromDb();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildAnalyticsTab({Key? key}) {
    final enabledKeys = _enabledSensorKeys();
    final graphKey = enabledKeys.contains(activeGraphKey)
        ? activeGraphKey
        : (enabledKeys.isNotEmpty ? enabledKeys.first : activeGraphKey);
    if (enabledKeys.isNotEmpty && graphKey != activeGraphKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (activeGraphKey != graphKey) {
          setState(() {
            activeGraphKey = graphKey;
          });
        }
      });
    }
    final config = _getSensorConfig(graphKey);
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return ReorderableListView(
      key: key,
      buildDefaultDragHandles: false,
      onReorder: (int oldIndex, int newIndex) async {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final String item = analyticsOrder.removeAt(oldIndex);
          analyticsOrder.insert(newIndex, item);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('analytics_order', analyticsOrder);
      },
      children: analyticsOrder.map((key) {
        Widget card;
        if (key == 'chart') {
          card = _buildInteractiveCard(
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
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: _showSensorManager,
                          ),
                          IconButton(
                            icon: const Icon(Icons.fullscreen, size: 20),
                            onPressed: () => _showFullscreenChart(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: RepaintBoundary(
                      child: enabledKeys.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sensors_off,
                                    color: subTextColor,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Sem sensores configurados",
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Toque em + para adicionar",
                                    style: TextStyle(
                                      color: subTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : LineChart(
                              _getChartData(
                                comparisonSensors.isEmpty
                                    ? [
                                        histories[graphKey]!
                                            .map(
                                              (spot) => FlSpot(
                                                spot.x,
                                                _convertValue(
                                                  graphKey,
                                                  spot.y,
                                                  sensorUnits[graphKey] ?? "",
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ]
                                    : comparisonSensors
                                          .where((k) => enabledKeys.contains(k))
                                          .map(
                                            (k) => histories[k]!
                                                .map(
                                                  (spot) => FlSpot(
                                                    spot.x,
                                                    _convertValue(
                                                      k,
                                                      spot.y,
                                                      sensorUnits[k] ?? "",
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          )
                                          .toList(),
                                comparisonSensors.isEmpty
                                    ? [config.color]
                                    : comparisonSensors
                                          .where((k) => enabledKeys.contains(k))
                                          .map((k) => _getSensorConfig(k).color)
                                          .toList(),
                                comparisonSensors.isEmpty
                                    ? [graphKey]
                                    : comparisonSensors
                                          .where((k) => enabledKeys.contains(k))
                                          .toList(),
                              ),
                            ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _generateReport,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text(
                          "Exportar Dados",
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
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
                    ],
                  ),
                ],
              ),
            ),
          );
        } else {
          card = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              enabledKeys.isEmpty
                  ? _buildInteractiveCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(Icons.add, color: subTextColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Adicionar sensores para habilitar a telemetria",
                                style: TextStyle(color: subTextColor),
                              ),
                            ),
                            TextButton(
                              onPressed: _showSensorManager,
                              child: const Text("ADICIONAR"),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.8,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: enabledKeys
                          .map((k) => _sensorActionCard(k))
                          .toList(),
                    ),
            ],
          );
        }
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              card,
              Positioned(
                top: 5,
                right: 5,
                child: ReorderableDragStartListener(
                  index: analyticsOrder.indexOf(key),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildControlTab({Key? key}) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    print(
      "UI: Renderizando aba de Ações. Notas no cache: ${diaryNotes.length}",
    );
    return ReorderableListView(
      key: key,
      buildDefaultDragHandles: false,
      onReorder: (int oldIndex, int newIndex) async {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final String item = controlOrder.removeAt(oldIndex);
          controlOrder.insert(newIndex, item);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('control_order', controlOrder);
      },
      children: controlOrder.map((key) {
        Widget card;
        switch (key) {
          case 'diagnosis':
            card = _buildInteractiveCard(
              onTap: _showHealthDiagnosis,
              child: ListTile(
                leading: const Icon(
                  Icons.health_and_safety,
                  color: Colors.greenAccent,
                  size: 30,
                ),
                title: Text(
                  "Diagnóstico de Saúde",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
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
            );
            break;
          case 'irrigation_history':
            if (_irrigationHistory.isEmpty) {
              return SizedBox(key: ValueKey('empty_$key'));
            }
            card = _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.water_drop, color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        Text(
                          "Últimas Irrigações",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._irrigationHistory.map((reg) {
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        reg[0].toInt(),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "${reg[1].toInt()} segundos",
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
            break;
          case 'maintenance':
            if (isMaintenanceMode) {
              card = _buildInteractiveCard(
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
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                              ),
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
              );
            } else {
              card = _buildInteractiveCard(
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
              );
            }
            break;
          case 'irrigation_control':
            if (!isAutoPumpEnabled) {
              card = _buildInteractiveCard(
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
              );
            } else {
              card = _buildInteractiveCard(
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
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            break;
          case 'camera':
            card = _buildInteractiveCard(
              child: ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                title: Text(
                  "Câmera",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
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
            );
            break;
          case 'diary':
            card = Consumer<AppProvider>(
              builder: (context, provider, child) {
                return _buildInteractiveCard(
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
                          "${provider.diaryNotes.length} registros no histórico",
                          style: TextStyle(color: subTextColor),
                        ),
                        onTap: _showDiaryListDialog,
                        trailing: const Icon(Icons.chevron_right, size: 16),
                      ),
                      const Divider(color: Colors.white10),
                      ListTile(
                        leading: const Icon(
                          Icons.auto_delete_outlined,
                          color: Colors.redAccent,
                        ),
                        title: Text(
                          "Limpar Apenas Diário",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          "Reconstruir tabela de notas e lembretes",
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Resetar Diário?"),
                              content: const Text(
                                "Isso apagará apenas as notas e lembretes e corrigirá possíveis erros de salvamento.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("CANCELAR"),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await _resetDiaryTable();
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    "RESETAR",
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
                );
              },
            );
            break;
          default:
            return SizedBox(key: ValueKey('ghost_$key'));
        }
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              card,
              Positioned(
                top: 5,
                right: 5,
                child: ReorderableDragStartListener(
                  index: controlOrder.indexOf(key),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildSettingsTab({Key? key}) {
    if (Platform.isAndroid) {
      return _buildAndroidSettingsList();
    }
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return DefaultTabController(
      length: settingsOrder.length,
      child: Column(
        children: [
          Stack(
            children: [
              TabBar(
                indicatorColor: Colors.greenAccent,
                labelColor: Colors.greenAccent,
                unselectedLabelColor: subTextColor,
                tabs: settingsOrder.map((key) {
                  switch (key) {
                    case 'personalizacao':
                      return const Tab(
                        text: "Personalização",
                        icon: Icon(Icons.palette, color: Colors.greenAccent),
                      );
                    case 'funcionalidades':
                      return const Tab(
                        text: "Funcionalidades",
                        icon: Icon(Icons.extension, color: Colors.greenAccent),
                      );
                    case 'conexao':
                      return const Tab(
                        text: "Conexão",
                        icon: Icon(
                          Icons.settings_ethernet,
                          color: Colors.greenAccent,
                        ),
                      );
                    case 'simulacao':
                      return const Tab(
                        text: "Simulação",
                        icon: Icon(Icons.biotech, color: Colors.greenAccent),
                      );
                    default:
                      return const Tab(text: "Desconhecido");
                  }
                }).toList(),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _showSettingsReorderDialog(context),
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: settingsOrder.map((key) {
                switch (key) {
                  case 'personalizacao':
                    return _buildPersonalizacaoSettings();
                  case 'funcionalidades':
                    return _buildFuncionalidadesSettings();
                  case 'conexao':
                    return _buildConexaoSettings();
                  case 'simulacao':
                    return _buildSimulacaoSettings();
                  default:
                    return const Center(
                      child: Text("Configuração não encontrada"),
                    );
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPersonalizacaoSettings({VoidCallback? onUpdate}) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return ReorderableListView(
      padding: const EdgeInsets.all(20),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = personalizacaoOrder.removeAt(oldIndex);
          personalizacaoOrder.insert(newIndex, item);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('personalizacao_order', personalizacaoOrder);
        if (onUpdate != null) onUpdate();
      },
      children: personalizacaoOrder.map((key) {
        Widget card;
        switch (key) {
          case 'theme_colors':
            card = _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.color_lens, color: Colors.blueAccent),
                        const SizedBox(width: 15),
                        Text(
                          "Cores dos Temas",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Cor do Tema Claro",
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      trailing: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.lightColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      onTap: () => _showColorPickerDialog(
                        "Cor do Tema Claro",
                        widget.lightColor,
                        (color) => widget.onSettingsChange(lightColor: color),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Cor do Tema Escuro",
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      trailing: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.darkColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      onTap: () => _showColorPickerDialog(
                        "Cor do Tema Escuro",
                        widget.darkColor,
                        (color) => widget.onSettingsChange(darkColor: color),
                      ),
                    ),
                  ],
                ),
              ),
            );
            break;
          case 'graphic_elements':
            card = _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.grid_view, color: Colors.greenAccent),
                        const SizedBox(width: 15),
                        Text(
                          "Elementos Gráficos",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Arredondamento dos Cards",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    Slider(
                      value: widget.cardRadius,
                      min: 0,
                      max: 40,
                      divisions: 8,
                      label: widget.cardRadius.round().toString(),
                      onChanged: (v) => widget.onSettingsChange(radius: v),
                      activeColor: Colors.greenAccent,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Espessura da Borda",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    Slider(
                      value: widget.borderWidth,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      label: widget.borderWidth.toStringAsFixed(1),
                      onChanged: (v) => widget.onSettingsChange(borderWidth: v),
                      activeColor: Colors.greenAccent,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Barra Superior Sólida",
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      value: widget.solidAppBar,
                      activeColor: Colors.greenAccent,
                      onChanged: (v) => widget.onSettingsChange(solidAppBar: v),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Cards com Transparência (Glass)",
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      value: widget.glassCards,
                      activeColor: Colors.greenAccent,
                      onChanged: (v) => widget.onSettingsChange(glassCards: v),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Efeitos de Brilho (Glow)",
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      value: widget.glowEffects,
                      activeColor: Colors.greenAccent,
                      onChanged: (v) => widget.onSettingsChange(glowEffects: v),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.greenAccent,
                      ),
                      onPressed: () => _showSettingsReorderDialog(context),
                      icon: const Icon(Icons.reorder),
                      label: const Text("Reordenar Dashboard"),
                    ),
                  ],
                ),
              ),
            );
            break;
          case 'font_style':
            card = _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.text_fields,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 15),
                        Text(
                          "Estilo da Fonte",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Tamanho Global da Fonte",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    Slider(
                      value: widget.fontSizeDelta,
                      min: -4,
                      max: 8,
                      divisions: 12,
                      label:
                          (widget.fontSizeDelta > 0 ? "+" : "") +
                          widget.fontSizeDelta.round().toString(),
                      onChanged: (v) => widget.onSettingsChange(fontSize: v),
                      activeColor: Colors.greenAccent,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Exemplo de Texto do Aplicativo",
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
            break;
          default:
            return SizedBox(key: ValueKey('ghost_$key'));
        }
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              card,
              Positioned(
                top: 5,
                right: 5,
                child: ReorderableDragStartListener(
                  index: personalizacaoOrder.indexOf(key),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  void _showColorPickerDialog(
    String title,
    Color currentColor,
    Function(Color) onColorSelected,
  ) {
    final colors = [
      Colors.green,
      Colors.greenAccent,
      Colors.blue,
      Colors.blueAccent,
      Colors.red,
      Colors.redAccent,
      Colors.orange,
      Colors.orangeAccent,
      Colors.purple,
      Colors.purpleAccent,
      Colors.teal,
      Colors.tealAccent,
      Colors.amber,
      Colors.amberAccent,
      Colors.indigo,
      Colors.indigoAccent,
      Colors.pink,
      Colors.pinkAccent,
      Colors.brown,
      Colors.grey,
      Colors.deepOrange,
      Colors.deepOrangeAccent,
      Colors.deepPurple,
      Colors.deepPurpleAccent,
      Colors.lightBlue,
      Colors.lightBlueAccent,
      Colors.lightGreen,
      Colors.lightGreenAccent,
      Colors.lime,
      Colors.limeAccent,
      Colors.yellow,
      Colors.yellowAccent,
      Colors.cyan,
      Colors.cyanAccent,
      Colors.blueGrey,
      Colors.black,
      Colors.white,
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: colors.length,
            itemBuilder: (context, index) {
              final color = colors[index];
              return InkWell(
                onTap: () {
                  onColorSelected(color);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: currentColor == color
                          ? Colors.white
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      if (currentColor == color)
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
        ],
      ),
    );
  }
  Widget _buildAndroidSettingsList() {
    return ReorderableListView(
      padding: const EdgeInsets.all(15),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = settingsOrder.removeAt(oldIndex);
          settingsOrder.insert(newIndex, item);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('settings_order', settingsOrder);
      },
      children: settingsOrder.map((key) {
        Widget card;
        switch (key) {
          case 'personalizacao':
            card = _buildAndroidSettingsItem(
              icon: Icons.palette,
              title: "Personalização",
              subtitle: "Cores dos Temas e Elementos Gráficos",
              onTap: () => _navigateToAndroidSettingsPage(
                "Personalização",
                (onUpdate) => _buildPersonalizacaoSettings(onUpdate: onUpdate),
              ),
            );
            break;
          case 'funcionalidades':
            card = _buildAndroidSettingsItem(
              icon: Icons.extension,
              title: "Funcionalidades",
              subtitle: "Notificações, IA, Voz e Irrigação",
              onTap: () => _navigateToAndroidSettingsPage(
                "Funcionalidades",
                (onUpdate) => _buildFuncionalidadesSettings(onUpdate: onUpdate),
              ),
            );
            break;
          case 'conexao':
            card = _buildAndroidSettingsItem(
              icon: Icons.settings_ethernet,
              title: "Conexão",
              subtitle: "IP, Cloud MQTT e Banco de Dados",
              onTap: () => _navigateToAndroidSettingsPage(
                "Conexão",
                (onUpdate) => _buildConexaoSettings(onUpdate: onUpdate),
              ),
            );
            break;
          case 'simulacao':
            card = _buildAndroidSettingsItem(
              icon: Icons.biotech,
              title: "Simulação",
              subtitle: "Modo de Teste e Simulador de Falhas",
              onTap: () => _navigateToAndroidSettingsPage(
                "Simulação",
                (onUpdate) => _buildSimulacaoSettings(onUpdate: onUpdate),
              ),
            );
            break;
          default:
            return SizedBox(key: ValueKey('ghost_$key'));
        }
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              card,
              Positioned(
                top: 5,
                right: 5,
                child: ReorderableDragStartListener(
                  index: settingsOrder.indexOf(key),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: widget.isDarkMode
                          ? Colors.white24
                          : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildAndroidSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return _buildInteractiveCard(
      onTap: onTap,
      child: ListTile(
        leading: Icon(icon, color: Colors.greenAccent),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: subTextColor, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
  void _navigateToAndroidSettingsPage(
    String title,
    Widget Function(VoidCallback onUpdate) contentBuilder,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setSubPageState) {
            return Scaffold(
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isWebSocketConnected || (isCloudMode && isConnected))
                      Text(
                        isCloudMode ? "NUVEM ATIVA" : "LOCAL ATIVO",
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              extendBodyBehindAppBar: true,
              body: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isDarkMode
                        ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                        : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                  ),
                ),
                child: SafeArea(
                  child: contentBuilder(() {
                    if (mounted) {
                      setState(() {});
                    }
                    setSubPageState(() {});
                  }),
                ),
              ),
            );
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
  void _showSettingsReorderDialog(BuildContext context) {
    final isDark = widget.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            "Personalizar Abas",
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: SizedBox(
            width: 400,
            height: 350,
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setDialogState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = settingsOrder.removeAt(oldIndex);
                  settingsOrder.insert(newIndex, item);
                });
                setState(() {});
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setStringList('settings_order', settingsOrder);
                });
              },
              children: settingsOrder.map((key) {
                String label;
                IconData icon;
                String subtitle;
                switch (key) {
                  case 'funcionalidades':
                    label = "Funcionalidades";
                    icon = Icons.extension;
                    subtitle = "Notificações, IA e Voz";
                    break;
                  case 'conexao':
                    label = "Conexão";
                    icon = Icons.settings_ethernet;
                    subtitle = "IP, MQTT e Database";
                    break;
                  case 'simulacao':
                    label = "Simulação";
                    icon = Icons.biotech;
                    subtitle = "Testes e Falhas";
                    break;
                  default:
                    label = "Desconhecido";
                    icon = Icons.help;
                    subtitle = "";
                }
                return Padding(
                  key: ValueKey(key),
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Stack(
                    children: [
                      _buildInteractiveCard(
                        child: ListTile(
                          leading: Icon(icon, color: Colors.greenAccent),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: ReorderableDragStartListener(
                          index: settingsOrder.indexOf(key),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.drag_indicator,
                              size: 14,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                        ),
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
              child: const Text("FECHAR"),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildFuncionalidadesSettings({VoidCallback? onUpdate}) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return ReorderableListView(
      padding: const EdgeInsets.all(15),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = funcionalidadesOrder.removeAt(oldIndex);
          funcionalidadesOrder.insert(newIndex, item);
        });
        if (onUpdate != null) onUpdate();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          'funcionalidades_order',
          funcionalidadesOrder,
        );
      },
      children: funcionalidadesOrder.map((key) {
        Widget card;
        switch (key) {
          case 'notifications':
            card = _buildNotificationSettingsCard(onUpdate: onUpdate);
            break;
          case 'eco_mode':
            card = _buildInteractiveCard(
              child: SwitchListTile(
                secondary: Icon(
                  Icons.eco,
                  color: isEcoModeEnabled ? Colors.greenAccent : Colors.grey,
                ),
                title: Text(
                  "Modo Econômico Manual",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  isEcoModeEnabled
                      ? "Ativo: IA e sensores em baixo consumo"
                      : "Desativado",
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                value: isEcoModeEnabled,
                activeThumbColor: Colors.greenAccent,
                onChanged: (v) async {
                  if (mounted) {
                    setState(() {
                      isEcoModeEnabled = v;
                      if (!v && (sensorData['battery'] ?? 100.0) <= 10.0) {
                        _ecoModeManualOverride = true;
                      }
                      if (v) {
                        _ecoModeManualOverride = false;
                      }
                    });
                  }
                  if (onUpdate != null) onUpdate();
                  _sendCommand('eco_mode', v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_eco_mode_enabled', v);
                },
              ),
            );
            break;
          case 'voice_assistant':
            card = _buildInteractiveCard(
              child: ExpansionTile(
                leading: Icon(
                  isVoiceAssistantEnabled ? Icons.mic : Icons.mic_off,
                  color: isVoiceAssistantEnabled
                      ? Colors.blueAccent
                      : Colors.grey,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Assistente de Voz",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isVoiceAssistantEnabled,
                        activeThumbColor: Colors.blueAccent,
                        onChanged: (val) async {
                          if (mounted) {
                            setState(() {
                              isVoiceAssistantEnabled = val;
                            });
                          }
                          if (onUpdate != null) onUpdate();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(
                            'is_voice_assistant_enabled',
                            val,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                children: [
                  Opacity(
                    opacity: isVoiceAssistantEnabled ? 1.0 : 0.4,
                    child: AbsorbPointer(
                      absorbing: !isVoiceAssistantEnabled,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 20,
                        ),
                        child: Column(
                          children: [
                            const Divider(color: Colors.white10),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                "Comandos de Voz",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                "Veja a lista de comandos suportados",
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.help_outline,
                                size: 20,
                                color: Colors.blueAccent,
                              ),
                              onTap: _showVoiceCommandsHelpDialog,
                            ),
                            const Divider(color: Colors.white10),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                "Tipo de Resposta",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                isVoiceAudioResponseEnabled
                                    ? "O app falará a resposta"
                                    : "A resposta aparecerá apenas como texto",
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.text_snippet_outlined,
                                    size: 18,
                                    color: !isVoiceAudioResponseEnabled
                                        ? Colors.blueAccent
                                        : Colors.grey,
                                  ),
                                  Switch(
                                    value: isVoiceAudioResponseEnabled,
                                    activeThumbColor: Colors.blueAccent,
                                    inactiveThumbColor: Colors.blueAccent,
                                    inactiveTrackColor: Colors.blueAccent
                                        .withValues(alpha: 0.5),
                                    onChanged: (val) async {
                                      if (mounted) {
                                        setState(() {
                                          isVoiceAudioResponseEnabled = val;
                                        });
                                      }
                                      if (onUpdate != null) onUpdate();
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setBool(
                                        'is_voice_audio_response',
                                        val,
                                      );
                                    },
                                  ),
                                  Icon(
                                    Icons.volume_up_outlined,
                                    size: 18,
                                    color: isVoiceAudioResponseEnabled
                                        ? Colors.blueAccent
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
            break;
          case 'auto_irrigation':
            card = _buildInteractiveCard(
              child: Column(
                children: [
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
                      if (mounted) setState(() => isAutoPumpEnabled = v);
                      if (onUpdate != null) onUpdate();
                      _startAutoPump();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('auto_pump_enabled', v);
                    },
                  ),
                  if (isAutoPumpEnabled)
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
                                  if (val != null && mounted) {
                                    setState(() => autoPumpMode = val);
                                    if (onUpdate != null) onUpdate();
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
                                      if (mounted) {
                                        setState(
                                          () => autoPumpInterval = v.toInt(),
                                        );
                                      }
                                      if (onUpdate != null) onUpdate();
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
                                    activeColor: Colors.blueAccent,
                                    onChanged: (v) {
                                      if (mounted) {
                                        setState(() => moistureThreshold = v);
                                      }
                                      if (onUpdate != null) onUpdate();
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
                                    if (mounted) {
                                      setState(
                                        () => autoPumpDuration = v.toInt(),
                                      );
                                    }
                                    if (onUpdate != null) onUpdate();
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
              ),
            );
            break;
          case 'hud_sensors':
            card = _buildInteractiveCard(
              child: ListTile(
                leading: const Icon(
                  Icons.screenshot_monitor,
                  color: Colors.blueAccent,
                ),
                title: Text(
                  "Sensores no HUD (Vídeo)",
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                subtitle: Text(
                  _enabledSensorKeys().isEmpty
                      ? "Nenhum sensor configurado"
                      : "${hudSensors.length} sensores selecionados",
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
                            children: _enabledSensorKeys().map((key) {
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
                                  if (val != null) {
                                    setDialogState(() {
                                      setState(() {
                                        if (val == true) {
                                          if (!hudSensors.contains(key)) {
                                            hudSensors.add(key);
                                          }
                                        } else {
                                          hudSensors.remove(key);
                                        }
                                      });
                                    });
                                  }
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
            );
            break;
          case 'vacation_mode':
            card = _buildInteractiveCard(
              child: SwitchListTile(
                title: Text(
                  "Modo Férias (Econômico)",
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                subtitle: Text(
                  isVacationMode
                      ? "Ativado (Rega mínima de segurança)"
                      : "Desativado",
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                value: isVacationMode,
                secondary: Icon(
                  Icons.beach_access,
                  color: isVacationMode ? Colors.blueAccent : Colors.grey,
                ),
                activeThumbColor: Colors.blueAccent,
                onChanged: (v) {
                  setState(() => isVacationMode = v);
                  if (onUpdate != null) onUpdate();
                  _addAlert(
                    v ? "Modo Férias ATIVADO" : "Modo Férias DESATIVADO",
                  );
                },
              ),
            );
            break;
          case 'event_recording':
            card = _buildInteractiveCard(
              child: SwitchListTile(
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
                secondary: Icon(
                  Icons.video_call,
                  color: isEventRecordingEnabled
                      ? Colors.redAccent
                      : Colors.grey,
                ),
                activeThumbColor: Colors.redAccent,
                onChanged: (v) async {
                  setState(() => isEventRecordingEnabled = v);
                  if (onUpdate != null) onUpdate();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('event_recording', v);
                },
              ),
            );
            break;
          case 'ai_enabled':
            card = _buildInteractiveCard(
              child: SwitchListTile(
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
                secondary: Icon(
                  Icons.psychology,
                  color: isAiEnabled ? Colors.purpleAccent : Colors.grey,
                ),
                activeThumbColor: Colors.purpleAccent,
                onChanged: (v) async {
                  setState(() => isAiEnabled = v);
                  if (onUpdate != null) onUpdate();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('ai_enabled', v);
                  _sendCommand('ai_enable', v);
                },
              ),
            );
            break;
          case 'treinar_ia':
            card = _buildInteractiveCard(
              child: ListTile(
                leading: Icon(
                  isTrainingAi ? Icons.hourglass_top : Icons.smart_toy,
                  color: isTrainingAi
                      ? Colors.purpleAccent
                      : Colors.purpleAccent,
                ),
                title: Text(
                  "Treinar Modelo IA",
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                subtitle: Text(
                  isTrainingAi
                      ? aiTrainingStatus.isNotEmpty
                            ? aiTrainingStatus
                            : "Treinando... ${(aiTrainingProgress * 100).toStringAsFixed(0)}%"
                      : "Treinar com seu próprio dataset",
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                trailing: isTrainingAi
                    ? SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: aiTrainingProgress,
                          backgroundColor: Colors.grey,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.purpleAccent,
                          ),
                        ),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: isTrainingAi ? null : () => _showTrainAiDialog(context),
              ),
            );
            break;
          default:
            return SizedBox(key: ValueKey('ghost_$key'));
        }
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              card,
              Positioned(
                top: 5,
                right: 5,
                child: ReorderableDragStartListener(
                  index: funcionalidadesOrder.indexOf(key),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildConexaoSettings({VoidCallback? onUpdate}) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return ReorderableListView(
      padding: const EdgeInsets.all(15),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = conexaoOrder.removeAt(oldIndex);
          conexaoOrder.insert(newIndex, item);
        });
        if (onUpdate != null) onUpdate();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('conexao_order', conexaoOrder);
      },
      children: conexaoOrder.map((key) {
        Widget card;
        switch (key) {
          case 'access_guide':
            card = _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.public, color: Colors.blueAccent),
                        const SizedBox(width: 10),
                        Text(
                          "GUIA DE ACESSO GLOBAL",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Para acessar de qualquer lugar (4G/Outros Wi-Fis) sem configurar o roteador:",
                      style: TextStyle(color: subTextColor, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    _guideStep(
                      "1. Instale o Tailscale na Raspberry e no Celular.",
                    ),
                    _guideStep(
                      "2. Use o IP do Tailscale (100.x.x.x) no campo IP Local.",
                    ),
                    _guideStep(
                      "3. Ou use um Túnel (Cloudflare/Ngrok) e cole a URL no Host Remoto.",
                    ),
                  ],
                ),
              ),
            );
            break;
          case 'rasp_ip':
            card = _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    TextField(
                      controller: _ipController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        icon: const Icon(
                          Icons.router,
                          color: Colors.greenAccent,
                        ),
                        labelText: "Endereço IP Local (Wi-Fi)",
                        labelStyle: TextStyle(color: subTextColor),
                        border: InputBorder.none,
                        hintText: "Ex: 192.168.1.15",
                      ),
                      onSubmitted: (v) async {
                        final newIp = v.trim();
                        if (newIp.isEmpty || newIp == raspIP) return;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('rasp_ip', newIp);
                        if (!mounted) return;
                        setState(() => raspIP = newIp);
                        if (onUpdate != null) onUpdate();
                        _reconnect();
                      },
                    ),
                  ],
                ),
              ),
            );
            break;
          case 'remote_host':
            card = _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    TextField(
                      controller: _remoteHostController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        icon: const Icon(
                          Icons.cloud_sync,
                          color: Colors.blueAccent,
                        ),
                        labelText: "Host/IP Remoto (4G/Externo)",
                        labelStyle: TextStyle(color: subTextColor),
                        border: InputBorder.none,
                        hintText: "Ex: meu-plant.ddns.net ou URL de Túnel",
                        hintStyle: TextStyle(
                          color: subTextColor.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                      onSubmitted: (v) async {
                        final newHost = v.trim();
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('remote_host', newHost);
                        if (!mounted) return;
                        setState(() => remoteHost = newHost);
                        if (onUpdate != null) onUpdate();
                        _reconnect();
                      },
                    ),
                  ],
                ),
              ),
            );
            break;
          case 'remote_ports':
            card = _buildInteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.settings_input_component,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(width: 15),
                        Text(
                          "Portas e Segurança",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPortField("Vídeo", videoPort, (v) {
                            setState(() => videoPort = v);
                            if (onUpdate != null) onUpdate();
                            SharedPreferences.getInstance().then(
                              (p) => p.setInt('video_port', v),
                            );
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPortField("WebSocket", wsPort, (v) {
                            setState(() => wsPort = v);
                            if (onUpdate != null) onUpdate();
                            SharedPreferences.getInstance().then(
                              (p) => p.setInt('ws_port', v),
                            );
                          }),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: Text(
                        "Usar SSL (HTTPS/WSS)",
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                      subtitle: Text(
                        "Necessário para Tunnels/Cloudflare",
                        style: TextStyle(color: subTextColor, fontSize: 10),
                      ),
                      value: useRemoteSsl,
                      activeThumbColor: Colors.blueAccent,
                      onChanged: (v) {
                        setState(() => useRemoteSsl = v);
                        if (onUpdate != null) onUpdate();
                        SharedPreferences.getInstance().then(
                          (p) => p.setBool('use_remote_ssl', v),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
            break;
          case 'cloud_mode':
            card = _buildInteractiveCard(
              child: Column(
                children: [
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
                    secondary: Icon(
                      Icons.cloud,
                      color: isCloudMode ? Colors.orangeAccent : Colors.grey,
                    ),
                    activeThumbColor: Colors.orangeAccent,
                    onChanged: (v) async {
                      setState(() => isCloudMode = v);
                      if (onUpdate != null) onUpdate();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('cloud_mode', v);
                      _reconnect();
                    },
                  ),
                  if (isCloudMode)
                    ListTile(
                      leading: const Icon(
                        Icons.settings,
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
                      onTap: () async {
                        await _showMqttConfigDialog();
                        if (onUpdate != null) onUpdate();
                      },
                      trailing: const Icon(Icons.edit, size: 16),
                    ),
                  if (isCloudMode)
                    ListTile(
                      leading: const Icon(
                        Icons.network_check,
                        color: Colors.blueAccent,
                      ),
                      title: Text(
                        "Testar Túnel (Vídeo)",
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        "Verificar se a URL do Ngrok está acessível",
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                      onTap: () async {
                        try {
                          final res = await http
                              .get(
                                Uri.parse(_videoUrl),
                                headers: {"ngrok-skip-browser-warning": "true"},
                              )
                              .timeout(const Duration(seconds: 5));
                          _addAlert("Túnel OK: Status ${res.statusCode}");
                        } catch (e) {
                          _addAlert("Erro no Túnel: $e");
                        }
                      },
                    ),
                ],
              ),
            );
            break;
          case 'link_status':
            card = _buildInteractiveCard(
              onTap: () async {
                _reconnect();
                if (onUpdate != null) onUpdate();
              },
              child: ListTile(
                leading: Icon(
                  isConnected ? Icons.check_circle : Icons.error,
                  color: isConnected ? Colors.greenAccent : Colors.greenAccent,
                  size: 30,
                ),
                title: Text(
                  isConnected ? "LINK ESTÁVEL" : "DESCONECTADO",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
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
            );
            break;
          case 'websocket_status':
            card = _buildInteractiveCard(
              onTap: () async {
                _reconnect();
                if (onUpdate != null) onUpdate();
              },
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isCloudMode
                          ? (isConnected ? Icons.cloud_done : Icons.cloud_off)
                          : (isWebSocketConnected
                                ? Icons.bolt
                                : Icons.bolt_outlined),
                      color: isCloudMode
                          ? (isConnected ? Colors.blueAccent : Colors.grey)
                          : (isWebSocketConnected
                                ? Colors.blueAccent
                                : Colors.grey),
                      size: 30,
                    ),
                    title: Text(
                      isCloudMode
                          ? "Telemetria via MQTT"
                          : "Protocolo de Alta Velocidade",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      isCloudMode
                          ? (isConnected
                                ? "Nuvem: ATIVA (Dados OK)"
                                : "Nuvem: DESCONECTADA")
                          : (isWebSocketConnected
                                ? "WebSockets: FLUXO CONTÍNUO"
                                : "WebSockets: DESCONECTADO"),
                      style: TextStyle(color: subTextColor),
                    ),
                    trailing: Icon(
                      Icons.refresh,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "DEBUG URLs:",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "VIDEO: $_videoUrl",
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white54,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            "DATA: $_wsUrl",
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white54,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
            break;
          case 'reset_db':
            card = _buildInteractiveCard(
              child: ListTile(
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
                            if (onUpdate != null) onUpdate();
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
            );
            break;
          default:
            return SizedBox(key: ValueKey('ghost_$key'));
        }
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              card,
              Positioned(
                top: 5,
                right: 5,
                child: ReorderableDragStartListener(
                  index: conexaoOrder.indexOf(key),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildSimulacaoSettings({VoidCallback? onUpdate}) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return ReorderableListView(
      padding: const EdgeInsets.all(15),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = simulacaoOrder.removeAt(oldIndex);
          simulacaoOrder.insert(newIndex, item);
        });
        if (onUpdate != null) onUpdate();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('simulacao_order', simulacaoOrder);
      },
      children: simulacaoOrder.map((key) {
        Widget card;
        switch (key) {
          case 'general_simulation':
            card = _buildInteractiveCard(
              child: SwitchListTile(
                title: Text(
                  "Simulação Geral",
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                subtitle: Text(
                  isSimulationMode
                      ? "Gerando dados aleatórios"
                      : "Usando dados reais (Raspberry/Arduino)",
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                value: isSimulationMode,
                secondary: Icon(
                  Icons.bug_report,
                  color: isSimulationMode ? Colors.greenAccent : Colors.grey,
                ),
                activeThumbColor: Colors.greenAccent,
                onChanged: (v) {
                  setState(() {
                    isSimulationMode = v;
                    if (v) _startSimulation();
                  });
                  if (onUpdate != null) onUpdate();
                },
              ),
            );
            break;
          case 'failure_simulator':
            card = _buildInteractiveCard(
              child: ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.redAccent),
                title: Text(
                  "Simular Falhas",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  "Simular erros para testar a IA",
                  style: TextStyle(color: subTextColor),
                ),
                onTap: () async {
                  await _showFailureSimulatorDialog();
                  if (onUpdate != null) onUpdate();
                },
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white24,
                ),
              ),
            );
            break;
          default:
            return SizedBox(key: ValueKey('ghost_$key'));
        }
        return Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              card,
              Positioned(
                top: 5,
                right: 5,
                child: ReorderableDragStartListener(
                  index: simulacaoOrder.indexOf(key),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  Widget _buildHealthGaugeCard() {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    Color scoreColor = Colors.greenAccent;
    String statusText = "Excelente";
    IconData statusIcon = Icons.check_circle;
    if (healthScore < 40) {
      scoreColor = Colors.redAccent;
      statusText = "Crítico";
      statusIcon = Icons.warning_rounded;
    } else if (healthScore < 75) {
      scoreColor = Colors.orangeAccent;
      statusText = "Atenção";
      statusIcon = Icons.info_outline;
    }
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ÍNDICE DE SAÚDE VITAL",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: subTextColor.withValues(alpha: 0.6),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildInteractiveCard(
              onTap: _showHealthDiagnosis,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: healthScore / 100,
                            strokeWidth: 8,
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.black12,
                            color: scoreColor,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$healthScore",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            Text(
                              "pts",
                              style: TextStyle(
                                fontSize: 10,
                                color: subTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 25),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: scoreColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasDisease
                                ? "Anomalia detectada pela IA"
                                : "Planta em condições ideais",
                            style: TextStyle(fontSize: 12, color: subTextColor),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildMiniStatusChip(
                                Icons.local_fire_department,
                                "$plantStreak d",
                                Colors.orangeAccent,
                              ),
                              const SizedBox(width: 8),
                              _buildMiniStatusChip(
                                Icons.trending_up,
                                "Nível $plantLevel",
                                Colors.blueAccent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: subTextColor.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildMiniStatusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
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
    final enabledKeys = _enabledSensorKeys();
    final visibleKeys = hudSensors
        .where((k) => enabledKeys.contains(k))
        .toList();
    if (visibleKeys.isEmpty) {
      return _buildInteractiveCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Telemetria Rápida",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors_off, color: subTextColor, size: 32),
                    const SizedBox(height: 10),
                    Text(
                      "Nenhum sensor foi configurado",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Acesse 'Gerenciar Sensores' para adicionar",
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
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
              children: visibleKeys.map((key) {
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
    String configuredName(String fallback) {
      final n = sensorConfigs[key]?['name'];
      if (n is String && n.trim().isNotEmpty) return n.trim();
      return fallback;
    }
    Color mixError(Color themeColor) {
      if (isHealthy) return themeColor;
      return Color.lerp(themeColor, Colors.redAccent, 0.5) ?? Colors.redAccent;
    }
    switch (key) {
      case 'u1':
        return _SensorConfig(
          configuredName("Umidade Solo 1"),
          "U1",
          Icons.water_drop,
          mixError(Colors.blueAccent),
          unit,
        );
      case 'u2':
        return _SensorConfig(
          configuredName("Umidade Solo 2"),
          "U2",
          Icons.water_drop,
          mixError(Colors.blue),
          unit,
        );
      case 'l1':
        return _SensorConfig(
          configuredName("Luz Ambiente 1"),
          "L1",
          Icons.wb_sunny,
          mixError(Colors.yellowAccent),
          unit,
        );
      case 'l2':
        return _SensorConfig(
          configuredName("Luz Ambiente 2"),
          "L2",
          Icons.wb_sunny,
          mixError(Colors.orangeAccent),
          unit,
        );
      case 't1':
        return _SensorConfig(
          configuredName("Temperatura 1"),
          "T1",
          Icons.thermostat,
          mixError(Colors.redAccent),
          unit,
        );
      case 't2':
        return _SensorConfig(
          configuredName("Temperatura 2"),
          "T2",
          Icons.thermostat,
          mixError(Colors.deepOrange),
          unit,
        );
      case 'p1':
        return _SensorConfig(
          configuredName("Nível pH 1"),
          "P1",
          Icons.science,
          mixError(Colors.purpleAccent),
          unit,
        );
      case 'p2':
        return _SensorConfig(
          configuredName("Nível pH 2"),
          "P2",
          Icons.science,
          mixError(Colors.deepPurpleAccent),
          unit,
        );
      case 'ec':
        return _SensorConfig(
          configuredName("Eletrocondutividade"),
          "EC",
          Icons.bolt,
          mixError(Colors.cyanAccent),
          unit,
        );
      case 'water_level':
        return _SensorConfig(
          configuredName("Nível de Água"),
          "NV",
          Icons.waves,
          mixError(Colors.blue),
          unit,
        );
      case 'battery':
        return _SensorConfig(
          configuredName("Bateria"),
          "BT",
          Icons.battery_charging_full,
          mixError(Colors.green),
          unit,
        );
      default:
        return _SensorConfig(
          "Sensor",
          "",
          Icons.sensors,
          mixError(Colors.grey),
          unit,
        );
    }
  }
  Widget _buildNotificationSettingsCard({VoidCallback? onUpdate}) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    final bool expanded = isNotificationsEnabled && _isNotificationsExpanded;
    return _buildInteractiveCard(
      key: ValueKey('notif_card_$expanded'),
      child: Column(
        children: [
          ListTile(
            onTap: isNotificationsEnabled
                ? () {
                    if (!mounted) return;
                    setState(() {
                      _isNotificationsExpanded = !_isNotificationsExpanded;
                    });
                    if (onUpdate != null) onUpdate();
                  }
                : null,
            leading: Icon(
              isNotificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: isNotificationsEnabled ? Colors.orangeAccent : Colors.grey,
            ),
            title: Text(
              "Notificações",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isNotificationsEnabled,
                    activeThumbColor: Colors.orangeAccent,
                    onChanged: (val) {
                      if (!mounted) return;
                      setState(() {
                        isNotificationsEnabled = val;
                        _isNotificationsExpanded = val;
                      });
                      if (onUpdate != null) onUpdate();
                      _saveNotificationSettings();
                    },
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: isNotificationsEnabled ? subTextColor : Colors.grey,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white10),
                  ...notificationSettings.keys.map((category) {
                    return Column(
                      key: ValueKey('notif_category_$category'),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                categoryNames[category] ?? category,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                const Text(
                                  "Push",
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey,
                                  ),
                                ),
                                Checkbox(
                                  value:
                                      notificationSettings[category]!['push'],
                                  activeColor: Colors.orangeAccent,
                                  onChanged: (val) {
                                    if (!mounted) return;
                                    setState(() {
                                      notificationSettings[category]!['push'] =
                                          val ?? false;
                                    });
                                    if (onUpdate != null) onUpdate();
                                    _saveNotificationSettings();
                                  },
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text(
                                  "Log",
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey,
                                  ),
                                ),
                                Checkbox(
                                  value: notificationSettings[category]!['log'],
                                  activeColor: Colors.blueAccent,
                                  onChanged: (val) {
                                    if (!mounted) return;
                                    setState(() {
                                      notificationSettings[category]!['log'] =
                                          val ?? false;
                                    });
                                    if (onUpdate != null) onUpdate();
                                    _saveNotificationSettings();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10),
                      ],
                    );
                  }),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            "Modo Não Perturbe (DND)",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            "Silenciar push entre ${dndStartTime.format(context)} e ${dndEndTime.format(context)}",
                            style: TextStyle(fontSize: 11, color: subTextColor),
                          ),
                          value: isDndEnabled,
                          activeThumbColor: Colors.purpleAccent,
                          onChanged: (val) {
                            if (!mounted) return;
                            setState(() {
                              isDndEnabled = val;
                            });
                            if (onUpdate != null) onUpdate();
                            _saveNotificationSettings();
                          },
                        ),
                        if (isDndEnabled) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: dndStartTime,
                                  );
                                  if (time != null && mounted) {
                                    setState(() {
                                      dndStartTime = time;
                                    });
                                    if (onUpdate != null) onUpdate();
                                    _saveNotificationSettings();
                                  }
                                },
                                child: Text(
                                  "Início: ${dndStartTime.format(context)}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: dndEndTime,
                                  );
                                  if (time != null && mounted) {
                                    setState(() {
                                      dndEndTime = time;
                                    });
                                    if (onUpdate != null) onUpdate();
                                    _saveNotificationSettings();
                                  }
                                },
                                child: Text(
                                  "Fim: ${dndEndTime.format(context)}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              "Ignorar DND para alertas críticos",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            value: bypassDndForCritical,
                            activeColor: Colors.greenAccent,
                            onChanged: (val) {
                              if (!mounted) return;
                              setState(() {
                                bypassDndForCritical = val ?? true;
                              });
                              if (onUpdate != null) onUpdate();
                              _saveNotificationSettings();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
  Widget _guideStep(String text) {
    final isDark = widget.isDarkMode;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: TextStyle(color: subTextColor, fontSize: 11)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: subTextColor, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPortField(String label, int value, Function(int) onChanged) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return TextField(
      keyboardType: TextInputType.number,
      style: TextStyle(color: textColor, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontSize: 10),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      controller: TextEditingController(text: value.toString()),
      onSubmitted: (v) {
        final newVal = int.tryParse(v);
        if (newVal != null) onChanged(newVal);
      },
    );
  }
  Widget _buildInteractiveCard({
    Key? key,
    required Widget child,
    double? height,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = widget.cardRadius;
    final borderWidth = widget.borderWidth;
    final isGlass = widget.glassCards;
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            width: borderWidth,
          ),
          boxShadow: [
            if (widget.glowEffects)
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isGlass ? 10 : 0,
              sigmaY: isGlass ? 10 : 0,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isGlass
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.4))
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(radius),
                gradient: isGlass
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.6),
                          isDark
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.white.withValues(alpha: 0.2),
                        ],
                      )
                    : null,
              ),
              child: child,
            ),
          ),
        ),
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

