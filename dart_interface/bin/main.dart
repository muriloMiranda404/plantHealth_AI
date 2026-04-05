import 'package:nt4/nt4.dart';
import 'dart:io';

void main() async {
  print('--- Iniciando Cliente Dart (NT4) ---');

  // Conectar ao servidor Python (que está rodando na mesma máquina)
  final client = NT4Client(serverBaseAddress: '127.0.0.1');

  // Assinar os tópicos (Sintaxe para nt4 1.3.3+)
  // A versão 1.3.3 exige NT4SubscriptionOptions como segundo argumento posicional.
  const options = NT4SubscriptionOptions();

  final statusSub = client.subscribe('/SmartDashboard/PlantStatus', options);
  final confSub = client.subscribe('/SmartDashboard/Confidence', options);

  print('Aguardando dados do Python...');

  // No nt4 1.3.3, 'stream' é um método que retorna o Stream, então usamos stream()
  statusSub.stream().listen((value) {
    if (value != null) {
      print('\x1B[2J\x1B[0;0H'); // Limpa a tela no terminal
      print('=== STATUS DA PLANTA ===');
      print('Detectado: $value');
    }
  });

  // Escutar confiança
  confSub.stream().listen((value) {
    if (value != null) {
      print('Confiança: ${(value as num).toDouble() * 100}%');
    }
  });

  // Manter o script rodando
  await ProcessSignal.sigint.watch().first;
}
