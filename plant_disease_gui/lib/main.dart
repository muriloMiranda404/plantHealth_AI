import 'package:flutter/material.dart';
import 'package:nt4/nt4.dart';
import 'dart:ui';

void main() {
  runApp(const PlantHealthApp());
}

class PlantHealthApp extends StatelessWidget {
  const PlantHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PlantGuard AI Pro',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.greenAccent,
      ),
      home: const GlassDashboard(),
    );
  }
}

class GlassDashboard extends StatefulWidget {
  const GlassDashboard({super.key});

  @override
  State<GlassDashboard> createState() => _GlassDashboardState();
}

class _GlassDashboardState extends State<GlassDashboard> {
  late NT4Client client;
  
  // Dados IA
  String status = "Iniciando...";
  bool hasDisease = false;
  double confidence = 0.0;
  
  // Dados Sensores (8 Sensores)
  double u1 = 0, u2 = 0;
  double l1 = 0, l2 = 0;
  double t1 = 0, t2 = 0;
  double p1 = 0, p2 = 0;
  
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    // Mude para o IP da sua Raspberry Pi!
    client = NT4Client(
      serverBaseAddress: '127.0.0.1', 
      onConnect: () => setState(() => isConnected = true),
      onDisconnect: () => setState(() => isConnected = false),
    );

    const options = NT4SubscriptionOptions();
    
    // IA Subscriptions
    client.subscribe('/SmartDashboard/PlantStatus', options).stream().listen((val) {
      if (val != null) setState(() => status = val.toString());
    });
    client.subscribe('/SmartDashboard/DiseaseDetected', options).stream().listen((val) {
      if (val != null) setState(() => hasDisease = val as bool);
    });
    client.subscribe('/SmartDashboard/Confidence', options).stream().listen((val) {
      if (val != null) setState(() => confidence = (val as num).toDouble());
    });

    // Arduino Subscriptions (8 Sensores)
    client.subscribe('/SmartDashboard/Umid1', options).stream().listen((val) => setState(() => u1 = (val as num?)?.toDouble() ?? 0));
    client.subscribe('/SmartDashboard/Umid2', options).stream().listen((val) => setState(() => u2 = (val as num?)?.toDouble() ?? 0));
    client.subscribe('/SmartDashboard/Luz1', options).stream().listen((val) => setState(() => l1 = (val as num?)?.toDouble() ?? 0));
    client.subscribe('/SmartDashboard/Luz2', options).stream().listen((val) => setState(() => l2 = (val as num?)?.toDouble() ?? 0));
    client.subscribe('/SmartDashboard/Temp1', options).stream().listen((val) => setState(() => t1 = (val as num?)?.toDouble() ?? 0));
    client.subscribe('/SmartDashboard/Temp2', options).stream().listen((val) => setState(() => t2 = (val as num?)?.toDouble() ?? 0));
    client.subscribe('/SmartDashboard/PH1', options).stream().listen((val) => setState(() => p1 = (val as num?)?.toDouble() ?? 0));
    client.subscribe('/SmartDashboard/PH2', options).stream().listen((val) => setState(() => p2 = (val as num?)?.toDouble() ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildMainStatusDisplay(),
                const SizedBox(height: 20),
                Expanded(child: _buildSensorGrid()),
                _buildConnectionStatus(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasDisease ? [Colors.red.shade900, Colors.black] : [Colors.green.shade900, Colors.black],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("PlantGuard AI", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              Text("Monitoramento Avançado (8 Sensores)", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Icon(hasDisease ? Icons.warning_amber : Icons.eco, color: hasDisease ? Colors.orange : Colors.greenAccent, size: 35),
        ],
      ),
    );
  }

  Widget _buildMainStatusDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(status.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 10),
          Text(hasDisease ? "DOENÇA DETECTADA" : "SAÚDE DA PLANTA EXCELENTE", 
            style: TextStyle(color: hasDisease ? Colors.redAccent : Colors.greenAccent, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSensorGrid() {
    return GridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      children: [
        _buildSensorCard("Umid. Solo 1", "${u1.toInt()}%", Icons.water_drop, Colors.blue),
        _buildSensorCard("Umid. Solo 2", "${u2.toInt()}%", Icons.water_drop, Colors.blue),
        _buildSensorCard("Luz 1", "${l1.toInt()}%", Icons.wb_sunny, Colors.orange),
        _buildSensorCard("Luz 2", "${l2.toInt()}%", Icons.wb_sunny, Colors.orange),
        _buildSensorCard("Temp. 1", "${t1.toStringAsFixed(1)}°C", Icons.thermostat, Colors.redAccent),
        _buildSensorCard("Temp. 2", "${t2.toStringAsFixed(1)}°C", Icons.thermostat, Colors.redAccent),
        _buildSensorCard("Nível pH 1", p1.toStringAsFixed(1), Icons.science, Colors.purpleAccent),
        _buildSensorCard("Nível pH 2", p2.toStringAsFixed(1), Icons.science, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: isConnected ? Colors.greenAccent : Colors.redAccent),
          const SizedBox(width: 10),
          Text(isConnected ? "PYTHON HUB CONECTADO" : "ERRO DE CONEXÃO", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
