import 'package:plant_health/core/data/datasources/local_database.dart';
import 'package:plant_health/features/diary/data/datasources/diary_local_data_source.dart';
import 'package:plant_health/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:plant_health/features/diary/domain/repositories/diary_repository.dart';
import 'package:plant_health/features/diary/domain/usecases/add_diary_note.dart';
import 'package:plant_health/features/diary/domain/usecases/delete_diary_note.dart';
import 'package:plant_health/features/diary/domain/usecases/get_diary_notes.dart';
import 'package:plant_health/features/diary/presentation/providers/diary_provider.dart';
import 'package:plant_health/features/monitoring/data/datasources/monitoring_local_data_source.dart';
import 'package:plant_health/features/monitoring/data/repositories/monitoring_repository_impl.dart';
import 'package:plant_health/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:plant_health/features/monitoring/domain/usecases/get_sensor_data.dart';
import 'package:plant_health/features/monitoring/domain/usecases/update_sensor_value.dart';
import 'package:plant_health/features/monitoring/presentation/providers/monitoring_provider.dart';

import 'package:plant_health/core/services/weather_service.dart';
import 'package:http/http.dart' as http;

import 'package:plant_health/features/monitoring/domain/usecases/get_smart_irrigation_recommendation.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final LocalDatabase localDatabase;
  late final WeatherService weatherService;

  late final DiaryLocalDataSource diaryLocalDataSource;
  late final DiaryRepository diaryRepository;
  late final GetDiaryNotes getDiaryNotes;
  late final AddDiaryNote addDiaryNote;
  late final DeleteDiaryNote deleteDiaryNote;

  late final MonitoringLocalDataSource monitoringLocalDataSource;
  late final MonitoringRepository monitoringRepository;
  late final GetSensorData getSensorData;
  late final UpdateSensorValue updateSensorValue;
  late final GetSmartIrrigationRecommendation getSmartIrrigationRecommendation;

  Future<void> init() async {
    localDatabase = LocalDatabase();
    weatherService = WeatherService(client: http.Client());

    diaryLocalDataSource = DiaryLocalDataSourceImpl(localDatabase);
    diaryRepository = DiaryRepositoryImpl(diaryLocalDataSource);
    getDiaryNotes = GetDiaryNotes(diaryRepository);
    addDiaryNote = AddDiaryNote(diaryRepository);
    deleteDiaryNote = DeleteDiaryNote(diaryRepository);

    monitoringLocalDataSource = MonitoringLocalDataSourceImpl(localDatabase);
    monitoringRepository = MonitoringRepositoryImpl(monitoringLocalDataSource);
    await monitoringRepository.loadInitialData();
    getSensorData = GetSensorData(monitoringRepository);
    updateSensorValue = UpdateSensorValue(monitoringRepository);
    getSmartIrrigationRecommendation = GetSmartIrrigationRecommendation(
      weatherService,
    );
  }

  DiaryProvider provideDiaryProvider() => DiaryProvider(
    getDiaryNotes: getDiaryNotes,
    addDiaryNote: addDiaryNote,
    deleteDiaryNote: deleteDiaryNote,
  );

  MonitoringProvider provideMonitoringProvider() => MonitoringProvider(
    getSensorData: getSensorData,
    updateSensorValue: updateSensorValue,
    getSmartIrrigationRecommendation: getSmartIrrigationRecommendation,
  );
}

final sl = ServiceLocator();
