import 'package:nt4/nt4.dart';
import 'dart:io';

void main() async {
  print('--- Iniciando Cliente Dart (NT4) ---');

  // Conectar ao servidor Python
  final client = NT4Client(serverBaseAddress: '127.0.0.1');

  const options = NT4SubscriptionOptions();

  final statusSub = client.subscribe('/SmartDashboard/PlantStatus', options);
  final confSub = client.subscribe('/SmartDashboard/Confidence', options);

  print('Aguardando dados do Python...');

  statusSub.stream().listen((value) {
    if (value != null) {
      print('\x1B[2J\x1B[0;0H'); // Limpa a tela no terminal
      print('=== STATUS DA PLANTA ===');
      print('Detectado: $value');
    }
  });

  confSub.stream().listen((value) {
    if (value != null) {
      print('Confiança: ${(value as num).toDouble() * 100}%');
    }
  });

  // Manter o script rodando
  await ProcessSignal.sigint.watch().first;
}
