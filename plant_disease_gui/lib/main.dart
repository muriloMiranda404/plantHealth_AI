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
  String status = "Desconectado";
  bool hasDisease = false;
  double confidence = 0.0;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    // IP do servidor Python. Se rodar no Windows para Windows, usar 127.0.0.1.
    // Se rodar no Android para Windows, usar o IP do seu PC (ex: 192.168.1.5).
    client = NT4Client(
      serverBaseAddress: '127.0.0.1', 
      onConnect: () => setState(() => isConnected = true),
      onDisconnect: () => setState(() => isConnected = false),
    );

    const options = NT4SubscriptionOptions();
    
    // Subscrições com tratamento de erro e reconexão automática
    client.subscribe('/SmartDashboard/PlantStatus', options).stream().listen((val) {
      if (val != null) setState(() => status = val.toString());
    });

    client.subscribe('/SmartDashboard/DiseaseDetected', options).stream().listen((val) {
      if (val != null) setState(() => hasDisease = val as bool);
    });

    client.subscribe('/SmartDashboard/Confidence', options).stream().listen((val) {
      if (val != null) setState(() => confidence = (val as num).toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo com Gradiente Animado
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
          // Círculos de brilho para efeito visual
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (hasDisease ? Colors.red : Colors.greenAccent).withOpacity(0.2),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildMainStatus(),
                  const SizedBox(height: 30),
                  _buildMetrics(),
                  const Spacer(),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PlantGuard AI",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            Text(
              "Monitoramento em tempo real",
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            hasDisease ? Icons.warning_amber_rounded : Icons.eco_rounded,
            color: hasDisease ? Colors.orangeAccent : Colors.greenAccent,
            size: 30,
          ),
        ),
      ],
    );
  }

  Widget _buildMainStatus() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Text(
                hasDisease ? "DOENÇA DETECTADA" : "SISTEMA OPERANTE",
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasDisease ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                status.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassCard(
            "Confiança",
            "${(confidence * 100).toStringAsFixed(1)}%",
            Icons.analytics_outlined,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildGlassCard(
            "Saúde",
            hasDisease ? "Alerta" : "Excelente",
            Icons.favorite_border_rounded,
          ),
        ),
      ],
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
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
              const SizedBox(height: 15),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isConnected ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isConnected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.3)
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isConnected ? "LINK ATIVO: PYTHON SERVER" : "ERRO DE CONEXÃO",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
