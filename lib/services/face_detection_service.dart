import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart'; // THÊM DÒNG NÀY

class FaceDetectionService {
  static final FaceDetectionService _instance =
      FaceDetectionService._internal();
  factory FaceDetectionService() => _instance;
  FaceDetectionService._internal();

  late CameraController _cameraController;
  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector();
  Timer? _detectionTimer;
  bool _isDetecting = false;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Biến đếm số lần phát hiện khuôn mặt liên tiếp
  int _faceDetectionCount = 0;
  static const int _warningThreshold = 2;
  DateTime? _lastFaceDetectionTime;

  // Biến để tránh cảnh báo liên tục sau khi đã cảnh báo
  DateTime? _lastWarningTime;
  static const Duration _warningCooldown = Duration(seconds: 30);

  // Biến lưu trạng thái app
  AppLifecycleState _currentAppState = AppLifecycleState.resumed; // ĐÃ SỬA
  bool _lastFaceDetectedState = false;
  DateTime? _lastForegroundDetectionTime;

  Function(bool)? onFaceDetected;

  Future<void> initialize() async {
    await _setupCamera();
    await _setupNotifications();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController.initialize();
    } catch (e) {
      print('Camera setup error: $e');
    }
  }

  Future<void> _setupNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'driving_safety_channel',
            'Cảnh báo an toàn lái xe',
            importance: Importance.high,
            playSound: true,
          ),
        );
  }

  // Phương thức mới: Cập nhật trạng thái app
  void updateAppState(AppLifecycleState state) {
    // ĐÃ SỬA
    _currentAppState = state;
    print('🔄 App state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      // ĐÃ SỬA
      print('🎯 App resumed - Camera ready for detection');
      // Khởi tạo lại camera khi app trở lại foreground
      _initializeCameraIfNeeded();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // ĐÃ SỬA
      print('⏸️ App in background - Disposing camera');
      _disposeCamera();
    }
  }

  Future<void> _initializeCameraIfNeeded() async {
    if (!_cameraController.value.isInitialized && _isDetecting) {
      await _setupCamera();
    }
  }

  Future<void> _disposeCamera() async {
    try {
      if (_cameraController.value.isInitialized) {
        await _cameraController.dispose();
        print('📷 Camera disposed');
      }
    } catch (e) {
      print('Error disposing camera: $e');
    }
  }

  Future<void> startFaceDetection() async {
    if (_isDetecting) return;

    _isDetecting = true;
    _resetDetectionCount();

    // Bắt đầu detection mỗi 5 giây
    _detectionTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await _performFaceDetection();
    });

    print('Face detection started');
  }

  Future<void> stopFaceDetection() async {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _isDetecting = false;
    _resetDetectionCount();
    await _disposeCamera();

    print('Face detection stopped');
  }

  void _resetDetectionCount() {
    _faceDetectionCount = 0;
    _lastFaceDetectionTime = null;
    print('Reset face detection count to 0');
  }

  Future<void> _performFaceDetection() async {
    try {
      // KIỂM TRA APP STATE - QUAN TRỌNG
      if (_currentAppState != AppLifecycleState.resumed) {
        // ĐÃ SỬA
        print('📱 App in background - Using background detection logic');
        await _backgroundDetectionLogic();
        return;
      }

      // APP ĐANG Ở FOREGROUND - CHẠY DETECTION THẬT
      if (!_cameraController.value.isInitialized) {
        await _setupCamera();
        if (!_cameraController.value.isInitialized) {
          return;
        }
      }

      print('🔍 Performing REAL face detection in foreground');
      final XFile imageFile = await _cameraController.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);

      final List<Face> faces = await _faceDetector.processImage(inputImage);
      final faceDetected = faces.isNotEmpty;

      // Lưu trạng thái cho background detection
      _lastFaceDetectedState = faceDetected;
      _lastForegroundDetectionTime = DateTime.now();

      // Gọi callback
      onFaceDetected?.call(faceDetected);

      if (faceDetected) {
        await _handleFaceDetected();
      } else {
        _resetDetectionCount();
      }

      // Xóa file ảnh tạm
      try {
        await File(imageFile.path).delete();
      } catch (e) {
        print('Error deleting temp file: $e');
      }
    } catch (e) {
      print('❌ Error in face detection: $e');
      // Nếu lỗi camera, dispose và thử lại sau
      if (e is CameraException) {
        await _disposeCamera();
      }
    }
  }

  // LOGIC DETECTION TRONG BACKGROUND
  Future<void> _backgroundDetectionLogic() async {
    final now = DateTime.now();

    // Nếu vừa mới có face detected ở foreground, tiếp tục đếm
    if (_lastFaceDetectedState &&
        _lastForegroundDetectionTime != null &&
        now.difference(_lastForegroundDetectionTime!) < Duration(seconds: 10)) {
      _faceDetectionCount++;
      print('🔮 Background detection - Predictive count: $_faceDetectionCount');

      if (_faceDetectionCount >= _warningThreshold) {
        await _triggerWarning();
      }
    } else {
      // Reset nếu đã lâu không có detection
      _resetDetectionCount();
    }
  }

  Future<void> _handleFaceDetected() async {
    final now = DateTime.now();

    // Kiểm tra nếu đã quá lâu kể từ lần phát hiện cuối (quá 10 giây)
    if (_lastFaceDetectionTime != null &&
        now.difference(_lastFaceDetectionTime!) > Duration(seconds: 10)) {
      _resetDetectionCount();
    }

    // Tăng biến đếm
    _faceDetectionCount++;
    _lastFaceDetectionTime = now;

    print('👁️ Face detected! Count: $_faceDetectionCount/$_warningThreshold');

    // Kiểm tra nếu đạt ngưỡng cảnh báo
    if (_faceDetectionCount >= _warningThreshold) {
      await _triggerWarning();
    }
  }

  Future<void> _triggerWarning() async {
    final now = DateTime.now();

    // Kiểm tra cooldown để tránh cảnh báo liên tục
    if (_lastWarningTime != null &&
        now.difference(_lastWarningTime!) < _warningCooldown) {
      print('⏳ Warning cooldown active, skipping warning');
      return;
    }

    _lastWarningTime = now;

    print('🚨 WARNING TRIGGERED - User continuously using phone while driving');

    // Gửi notification cảnh báo
    await _sendWarningNotification();

    // Log sự kiện
    await _logDrivingEvent();

    // Reset biến đếm sau khi cảnh báo
    _resetDetectionCount();
  }

  Future<void> _sendWarningNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'driving_safety_channel',
          'Cảnh báo an toàn lái xe',
          channelDescription:
              'Thông báo khi phát hiện sử dụng điện thoại khi lái xe',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      '🚨 CẢNH BÁO AN TOÀN',
      'PHÁT HIỆN SỬ DỤNG ĐIỆN THOẠI LIÊN TỤC KHI ĐANG LÁI XE!\nVui lòng tập trung vào việc lái xe.',
      details,
    );

    print('⚠️ Warning notification sent');
  }

  Future<void> _logDrivingEvent() async {
    final event = {
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'continuous_face_detected_while_driving',
      'detection_count': _faceDetectionCount,
      'warning_sent': true,
      'app_state': _currentAppState.toString(),
    };

    print('📝 Driving warning event logged: $event');
  }

  void dispose() {
    _detectionTimer?.cancel();
    _disposeCamera();
    _faceDetector.close();
  }
}
