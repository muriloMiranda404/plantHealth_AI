import 'package:flutter/material.dart';
import 'package:nt4/nt4.dart';
import 'dart:async';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PlantGuardProApp());
}

class PlantGuardProApp extends StatelessWidget {
  const PlantGuardProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PlantGuard Pro Hub',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.greenAccent,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      home: const MainTabController(),
    );
  }
}

class MainTabController extends StatefulWidget {
  const MainTabController({super.key});

  @override
  State<MainTabController> createState() => _MainTabControllerState();
}

class _MainTabControllerState extends State<MainTabController> {
  int _selectedIndex = 0;
  late NT4Client client;
  bool isConnected = false;
  String raspIP = "127.0.0.1";

  NT4Topic? pumpPub;
  NT4Topic? phPub;

  // IA Data
  String plantStatus = "Iniciando...";
  bool hasDisease = false;
  double confidence = 0.0;

  // Sensor Data (8 Sensores)
  Map<String, double> sensorData = {
    'u1': 0, 'u2': 0, 'l1': 0, 'l2': 0, 
    't1': 0, 't2': 0, 'p1': 0, 'p2': 0
  };
  
  // Histórico de 8 Sensores para Gráficos
  Map<String, List<FlSpot>> histories = {
    'u1': [], 'u2': [], 'l1': [], 'l2': [], 
    't1': [], 't2': [], 'p1': [], 'p2': []
  };
  int timerCount = 0;
  String activeGraphKey = 'u1'; // Sensor selecionado para o gráfico

  bool pumpState = false;
  double phCalibration = 0.5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupNT4();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      raspIP = prefs.getString('rasp_ip') ?? "127.0.0.1";
      phCalibration = prefs.getDouble('ph_calib') ?? 0.5;
    });
  }

  void _setupNT4() {
    // Fecha cliente antigo se existir para evitar vazamento de memória
    if (isConnected) {
    }

    client = NT4Client(
      serverBaseAddress: raspIP,
      onConnect: () {
        setState(() => isConnected = true);
        pumpPub = client.publishNewTopic('/SmartDashboard/CmdPump', NT4TypeStr.typeBool);
        phPub = client.publishNewTopic('/SmartDashboard/PH_Offset', NT4TypeStr.typeFloat64);
        
        // Sincroniza valores iniciais após a conexão
        Future.delayed(const Duration(milliseconds: 500), () {
          if (pumpPub != null) client.addSample(pumpPub!, pumpState);
          if (phPub != null) client.addSample(phPub!, phCalibration);
        });
      },
      onDisconnect: () => setState(() => isConnected = false),
    );

    const opt = NT4SubscriptionOptions();
    
    // IA
    client.subscribe('/SmartDashboard/PlantStatus', opt).stream().listen((v) => setState(() => plantStatus = v.toString()));
    client.subscribe('/SmartDashboard/DiseaseDetected', opt).stream().listen((v) => setState(() => hasDisease = v as bool));
    client.subscribe('/SmartDashboard/Confidence', opt).stream().listen((v) => setState(() => confidence = (v as num).toDouble()));

    // Configuração Dinâmica dos 8 Sensores
    final List<Map<String, String>> sensorConfigs = [
      {'topic': 'Umid1', 'key': 'u1'}, {'topic': 'Umid2', 'key': 'u2'},
      {'topic': 'Luz1', 'key': 'l1'}, {'topic': 'Luz2', 'key': 'l2'},
      {'topic': 'Temp1', 'key': 't1'}, {'topic': 'Temp2', 'key': 't2'},
      {'topic': 'PH1', 'key': 'p1'}, {'topic': 'PH2', 'key': 'p2'},
    ];

    for (var s in sensorConfigs) {
      client.subscribe('/SmartDashboard/${s['topic']}', opt).stream().listen((v) {
        if (v != null) {
          setState(() {
            double val = (v as num).toDouble();
            sensorData[s['key']!] = val;
            histories[s['key']!]!.add(FlSpot(timerCount.toDouble(), val));
            if (histories[s['key']!]!.length > 40) histories[s['key']!]!.removeAt(0);
            if (s['key'] == 'u1') timerCount++;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF0A0A0A),
          selectedItemColor: Colors.greenAccent,
          unselectedItemColor: Colors.white24,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.remove_red_eye_outlined), activeIcon: Icon(Icons.remove_red_eye), label: 'Visão'),
            BottomNavigationBarItem(icon: Icon(Icons.query_stats), activeIcon: Icon(Icons.insights), label: 'Gráficos'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_input_component), activeIcon: Icon(Icons.settings_input_component), label: 'Ações'),
            BottomNavigationBarItem(icon: Icon(Icons.tune), activeIcon: Icon(Icons.tune), label: 'Ajustes'),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildCurrentTab(),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0: return _buildMonitorTab();
      case 1: return _buildAnalyticsTab();
      case 2: return _buildControlTab();
      case 3: return _buildSettingsTab();
      default: return Container();
    }
  }

  // --- TAB 1: MONITOR IA ---
  Widget _buildMonitorTab() {
    return _TabScaffold(
      title: "IA Real-Time",
      child: Column(
        children: [
          _buildInteractiveCard(
            height: 280,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGlowIcon(),
                const SizedBox(height: 25),
                Text(plantStatus.toUpperCase(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _buildStatusBadge(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildInteractiveCard(
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Confiança do Modelo", style: TextStyle(color: Colors.white54)),
                      Text("${(confidence * 100).toInt()}%", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(value: confidence, minHeight: 12, backgroundColor: Colors.white10, color: Colors.greenAccent),
                  ),
                ],
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
                  Text(config.name, style: TextStyle(color: config.color, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Expanded(child: LineChart(_getChartData(histories[activeGraphKey]!, config.color))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text("SELECIONE UM SENSOR PARA ANALISAR", style: TextStyle(fontSize: 10, color: Colors.white24, letterSpacing: 1.2)),
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
    return _TabScaffold(
      title: "Painel de Ação",
      child: Column(
        children: [
          _buildInteractiveCard(
            child: SwitchListTile(
              secondary: Icon(Icons.water_drop, color: pumpState ? Colors.blue : Colors.white24, size: 30),
              title: const Text("Sistema de Irrigação", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(pumpState ? "BOMBA ATIVA" : "AGUARDANDO COMANDO"),
              value: pumpState,
              activeThumbColor: Colors.blueAccent,
              onChanged: (v) {
                setState(() => pumpState = v);
                if (pumpPub != null) client.addSample(pumpPub!, v);
              },
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
                      const Text("Calibração pH", style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(phCalibration.toStringAsFixed(2), style: const TextStyle(fontSize: 18, color: Colors.purpleAccent)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: phCalibration,
                    activeColor: Colors.purpleAccent,
                    onChanged: (v) => setState(() => phCalibration = v),
                    onChangeEnd: (v) {
                      if (phPub != null) client.addSample(phPub!, v);
                      SharedPreferences.getInstance().then((p) => p.setDouble('ph_calib', v));
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
    return _TabScaffold(
      title: "Configuração",
      child: Column(
        children: [
          _buildInteractiveCard(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: TextField(
                decoration: const InputDecoration(
                  icon: Icon(Icons.router, color: Colors.greenAccent),
                  labelText: "Endereço IP da Raspberry Pi",
                  border: InputBorder.none,
                ),
                controller: TextEditingController(text: raspIP),
                onSubmitted: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('rasp_ip', v);
                  setState(() => raspIP = v);
                  _setupNT4();
                },
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildInteractiveCard(
            onTap: () => _setupNT4(),
            child: ListTile(
              leading: Icon(isConnected ? Icons.check_circle : Icons.error, color: isConnected ? Colors.greenAccent : Colors.redAccent),
              title: Text(isConnected ? "LINK ESTÁVEL" : "DESCONECTADO"),
              subtitle: Text("IP ATUAL: $raspIP"),
              trailing: const Icon(Icons.refresh),
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
            color: (hasDisease ? Colors.redAccent : Colors.greenAccent).withOpacity(0.2),
            blurRadius: 40, spreadRadius: 10,
          )
        ],
      ),
      child: Icon(
        hasDisease ? Icons.warning_rounded : Icons.check_circle_rounded,
        size: 100, color: hasDisease ? Colors.redAccent : Colors.greenAccent,
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: (hasDisease ? Colors.redAccent : Colors.greenAccent).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: (hasDisease ? Colors.redAccent : Colors.greenAccent).withOpacity(0.3)),
      ),
      child: Text(
        hasDisease ? "ANOMALIA DETECTADA" : "SAÚDE EXCELENTE",
        style: TextStyle(color: hasDisease ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
      ),
    );
  }

  Widget _sensorActionCard(String key) {
    final cfg = _getSensorConfig(key);
    bool isActive = activeGraphKey == key;
    return GestureDetector(
      onTap: () => setState(() => activeGraphKey = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive ? cfg.color.withOpacity(0.15) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? cfg.color : Colors.white10, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(cfg.icon, color: cfg.color, size: 20),
            const SizedBox(height: 4),
            Text(cfg.label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
            Text("${sensorData[key]?.toStringAsFixed(1)}${cfg.unit}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  LineChartData _getChartData(List<FlSpot> spots, Color color) {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
          isCurved: true, color: color, barWidth: 4, isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
        ),
      ],
    );
  }

  _SensorConfig _getSensorConfig(String key) {
    switch (key) {
      case 'u1': return _SensorConfig("Umidade Solo 1", "U1", Icons.water_drop, Colors.blueAccent, "%");
      case 'u2': return _SensorConfig("Umidade Solo 2", "U2", Icons.water_drop, Colors.blue, "%");
      case 'l1': return _SensorConfig("Luz Ambiente 1", "L1", Icons.wb_sunny, Colors.yellowAccent, "%");
      case 'l2': return _SensorConfig("Luz Ambiente 2", "L2", Icons.wb_sunny, Colors.orangeAccent, "%");
      case 't1': return _SensorConfig("Temperatura 1", "T1", Icons.thermostat, Colors.redAccent, "°C");
      case 't2': return _SensorConfig("Temperatura 2", "T2", Icons.thermostat, Colors.deepOrange, "°C");
      case 'p1': return _SensorConfig("Nível pH 1", "P1", Icons.science, Colors.purpleAccent, "");
      case 'p2': return _SensorConfig("Nível pH 2", "P2", Icons.science, Colors.deepPurpleAccent, "");
      default: return _SensorConfig("Sensor", "", Icons.sensors, Colors.grey, "");
    }
  }

  Widget _buildInteractiveCard({required Widget child, double? height, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height, width: double.infinity,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white10)),
        child: child,
      ),
    );
  }
}

class _SensorConfig {
  final String name; final String label; final IconData icon; final Color color; final String unit;
  _SensorConfig(this.name, this.label, this.icon, this.color, this.unit);
}

class _TabScaffold extends StatelessWidget {
  final String title; final Widget child;
  const _TabScaffold({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
            const SizedBox(height: 25),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
