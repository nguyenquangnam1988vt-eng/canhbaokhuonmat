import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/audio_background_service.dart';
import 'services/face_detection_service.dart';
import 'services/background_fetch_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DrivingSafetyApp());
}

class DrivingSafetyApp extends StatelessWidget {
  const DrivingSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driving Safety Detector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final AudioBackgroundService _audioService = AudioBackgroundService();
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final BackgroundFetchService _backgroundFetchService =
      BackgroundFetchService();

  bool _isMonitoring = false;
  bool _faceDetected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceDetectionService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 App lifecycle state: $state');

    // QUAN TRỌNG: Cập nhật app state cho face detection service
    _faceDetectionService.updateAppState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeServices() async {
    await _requestPermissions();
    await _audioService.initialize();
    await _faceDetectionService.initialize();
    await _backgroundFetchService.initialize();

    _setupFaceDetectionHandler();
  }

  Future<void> _requestPermissions() async {
    final permissions = await [
      Permission.camera,
      Permission.notification,
      Permission.microphone,
    ].request();

    if (permissions[Permission.camera]!.isGranted) {
      print('Camera permission granted');
    }
  }

  void _setupFaceDetectionHandler() {
    _faceDetectionService.onFaceDetected = (bool detected) {
      setState(() {
        _faceDetected = detected;
      });

      if (detected) {
        _showWarningDialog();
      }
    };
  }

  void _onAppResumed() {
    if (_isMonitoring) {
      print('🔄 App resumed - Restarting face detection');
      _faceDetectionService.startFaceDetection();
    }
  }

  void _onAppPaused() {
    if (_isMonitoring) {
      print('⏸️ App paused - Keeping audio service running');
      _audioService.startSilentAudio();
      // Face detection vẫn chạy với background logic
    }
  }

  Future<void> _startMonitoring() async {
    setState(() {
      _isMonitoring = true;
    });

    await _audioService.startSilentAudio();
    await _faceDetectionService.startFaceDetection();
    await _backgroundFetchService.startBackgroundFetch();
    await WakelockPlus.enable();

    print('Monitoring started - Will work in background');
  }

  Future<void> _stopMonitoring() async {
    setState(() {
      _isMonitoring = false;
      _faceDetected = false;
    });

    await _audioService.stopSilentAudio();
    await _faceDetectionService.stopFaceDetection();
    await _backgroundFetchService.stopBackgroundFetch();
    await WakelockPlus.disable();

    print('Monitoring stopped');
  }

  void _showWarningDialog() {
    // Chỉ hiển thị khi app ở foreground
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cảnh báo an toàn'),
        content: Text(
          'Phát hiện sử dụng điện thoại khi đang lái xe. Vui lòng tập trung vào việc lái xe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tôi hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driving Safety Detector'),
        backgroundColor: _faceDetected ? Colors.red : Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _faceDetected ? Icons.warning : Icons.safety_check,
              size: 100,
              color: _faceDetected ? Colors.red : Colors.green,
            ),
            SizedBox(height: 20),
            Text(
              _faceDetected
                  ? '⚠️ PHÁT HIỆN SỬ DỤNG ĐIỆN THOẠI'
                  : _isMonitoring
                      ? '🔍 Đang giám sát...'
                      : '🚗 Sẵn sàng giám sát',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _faceDetected ? Colors.red : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isMonitoring ? null : _startMonitoring,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('BẮT ĐẦU'),
                ),
                ElevatedButton(
                  onPressed: _isMonitoring ? _stopMonitoring : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('DỪNG LẠI'),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (_isMonitoring) ...[
              LinearProgressIndicator(),
              SizedBox(height: 10),
              Text(
                'App đang chạy ẩn trong nền\nFace detection hoạt động khi có thể',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
