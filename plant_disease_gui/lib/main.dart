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
      title: 'PlantGuard AI',
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
  
  // Dados da IA
  String status = "Iniciando...";
  bool hasDisease = false;
  double confidence = 0.0;
  
  // Dados do Arduino
  double umidade = 0.0;
  double luz = 0.0;
  
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    // IMPORTANTE: Mude para o IP da sua Raspberry Pi na rede Wi-Fi!
    client = NT4Client(
      serverBaseAddress: '127.0.0.1', 
      onConnect: () => setState(() => isConnected = true),
      onDisconnect: () => setState(() => isConnected = false),
    );

    const options = NT4SubscriptionOptions();
    
    // IA
    client.subscribe('/SmartDashboard/PlantStatus', options).stream().listen((val) {
      if (val != null) setState(() => status = val.toString());
    });
    client.subscribe('/SmartDashboard/DiseaseDetected', options).stream().listen((val) {
      if (val != null) setState(() => hasDisease = val as bool);
    });
    client.subscribe('/SmartDashboard/Confidence', options).stream().listen((val) {
      if (val != null) setState(() => confidence = (val as num).toDouble());
    });

    // Arduino (Novos tópicos)
    client.subscribe('/SmartDashboard/UmidadeSolo', options).stream().listen((val) {
      if (val != null) setState(() => umidade = (val as num).toDouble());
    });
    client.subscribe('/SmartDashboard/LuzAmbiente', options).stream().listen((val) {
      if (val != null) setState(() => luz = (val as num).toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: hasDisease 
                  ? [Colors.red.shade900, Colors.black] 
                  : [Colors.green.shade900, Colors.black],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildMainStatus(),
                  const SizedBox(height: 20),
                  // Grade de métricas (IA + Arduino)
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      children: [
                        _buildGlassCard("Confiança", "${(confidence * 100).toInt()}%", Icons.analytics),
                        _buildGlassCard("Umidade", "${umidade.toInt()}%", Icons.water_drop),
                        _buildGlassCard("Luz", "${luz.toInt()}%", Icons.wb_sunny),
                        _buildGlassCard("Status", hasDisease ? "Alerta" : "OK", Icons.health_and_safety),
                      ],
                    ),
                  ),
                  _buildConnectionBadge(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("PlantGuard AI", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Raspberry Pi + Arduino", style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        Icon(hasDisease ? Icons.warning_amber : Icons.eco, color: hasDisease ? Colors.orange : Colors.greenAccent, size: 32),
      ],
    );
  }

  Widget _buildMainStatus() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Text(status.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 5),
              Text(hasDisease ? "FOI DETECTADO UM PROBLEMA" : "PLANTA SAUDÁVEL", style: TextStyle(color: hasDisease ? Colors.redAccent : Colors.greenAccent, letterSpacing: 1.2, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(String title, String value, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.greenAccent, size: 24),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: isConnected ? Colors.greenAccent : Colors.redAccent),
          const SizedBox(width: 8),
          Text(isConnected ? "SISTEMA ONLINE" : "OFFLINE", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
