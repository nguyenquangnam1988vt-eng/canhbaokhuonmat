import 'package:background_fetch/background_fetch.dart';
import 'face_detection_service.dart';
import 'audio_background_service.dart';

class BackgroundFetchService {
  static final BackgroundFetchService _instance =
      BackgroundFetchService._internal();
  factory BackgroundFetchService() => _instance;
  BackgroundFetchService._internal();

  static const String _taskId = 'driving_safety_fetch';

  Future<void> initialize() async {
    await _configureBackgroundFetch();
  }

  Future<void> _configureBackgroundFetch() async {
    await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15, // 15 phút
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.NONE,
      ),
      _onBackgroundFetch,
      _onBackgroundFetchTimeout,
    );
  }

  Future<void> _onBackgroundFetch(String taskId) async {
    print('[BackgroundFetch] Event received: $taskId');

    try {
      // Khởi động face detection tạm thời
      await FaceDetectionService().startFaceDetection();

      // Chờ 10 giây để detection hoạt động
      await Future.delayed(Duration(seconds: 10));

      // Dừng detection để tiết kiệm pin
      await FaceDetectionService().stopFaceDetection();

      BackgroundFetch.finish(taskId);
    } catch (e) {
      print('[BackgroundFetch] Error: $e');
      BackgroundFetch.finish(taskId);
    }
  }

  void _onBackgroundFetchTimeout(String taskId) {
    print('[BackgroundFetch] TIMEOUT: $taskId');
    BackgroundFetch.finish(taskId);
  }

  Future<void> startBackgroundFetch() async {
    await BackgroundFetch.start();
    print('Background fetch started');
  }

  Future<void> stopBackgroundFetch() async {
    await BackgroundFetch.stop();
    print('Background fetch stopped');
  }

  Future<void> scheduleBackgroundFetch() async {
    await BackgroundFetch.scheduleTask(
      TaskConfig(
        taskId: _taskId,
        delay: 300000, // 5 phút
        periodic: true,
        forceAlarmManager: true,
      ),
    );
  }
}
