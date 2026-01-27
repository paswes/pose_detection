import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Erzwinge Hochformat
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: PoseDetectionScreen(cameras: cameras),
    );
  }
}

class PoseDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const PoseDetectionScreen({Key? key, required this.cameras})
    : super(key: key);

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isDetecting = false;
  List<Pose> _poses = [];
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializePoseDetector();
  }

  Future<void> _initializeCamera() async {
    // Nutze nur die Hauptkamera (Rückkamera)
    final camera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();

    if (!mounted) return;

    await _cameraController!.startImageStream(_processCameraImage);
    setState(() {});
  }

  void _initializePoseDetector() {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    );
    _poseDetector = PoseDetector(options: options);
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isDetecting) return;
    _isDetecting = true;

    final inputImage = _convertCameraImage(cameraImage);
    if (inputImage == null) {
      _isDetecting = false;
      return;
    }

    final poses = await _poseDetector!.processImage(inputImage);

    if (mounted) {
      setState(() {
        _poses = poses;
        _imageSize = Size(
          cameraImage.width.toDouble(),
          cameraImage.height.toDouble(),
        );
      });
    }

    _isDetecting = false;
  }

  InputImage? _convertCameraImage(CameraImage cameraImage) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      // Für Rückkamera
      var rotationCompensation = (sensorOrientation - 90 + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
    if (format == null) return null;

    final plane = cameraImage.planes.first;
    final inputImageMetadata = InputImageMetadata(
      size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: inputImageMetadata,
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final size = MediaQuery.of(context).size;
    final cameraAspectRatio = _cameraController!.value.aspectRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Kamera Preview
          Center(
            child: AspectRatio(
              aspectRatio: 1 / cameraAspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),

          // Pose Overlay
          if (_poses.isNotEmpty && _imageSize != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / cameraAspectRatio,
                child: CustomPaint(
                  painter: PosePainter(
                    poses: _poses,
                    imageSize: _imageSize!,
                  ),
                ),
              ),
            ),

          // UI Header
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pose Detection',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _poses.isEmpty ? Colors.red : Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _poses.isEmpty
                              ? 'Keine Pose'
                              : '${_poses.length} Pose(n)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;

  PosePainter({
    required this.poses,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint landmarkPaint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 4
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..color = Colors.cyan.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final Paint confidencePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    for (final pose in poses) {
      // Zeichne Verbindungen zwischen Landmarks
      _drawConnections(canvas, size, pose, linePaint);

      // Zeichne Landmarks
      for (final landmark in pose.landmarks.values) {
        final point = _translatePoint(
          landmark.x,
          landmark.y,
          imageSize,
          size,
        );

        // Zeichne Konfidenzkreis (größer = höhere Konfidenz)
        final confidence = landmark.likelihood;
        canvas.drawCircle(
          point,
          8 + (confidence * 4),
          confidencePaint..color = Colors.yellow.withOpacity(confidence),
        );

        // Zeichne Landmark-Punkt
        canvas.drawCircle(point, 6, landmarkPaint);
      }
    }
  }

  void _drawConnections(Canvas canvas, Size size, Pose pose, Paint paint) {
    // Definiere Verbindungen zwischen Landmarks für ein Skelett
    final connections = [
      // Körper
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],

      // Linker Arm
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],

      // Rechter Arm
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],

      // Linkes Bein
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],

      // Rechtes Bein
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],

      // Kopf
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftEar],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightEar],
      [PoseLandmarkType.leftEar, PoseLandmarkType.leftEye],
      [PoseLandmarkType.rightEar, PoseLandmarkType.rightEye],
      [PoseLandmarkType.leftEye, PoseLandmarkType.nose],
      [PoseLandmarkType.rightEye, PoseLandmarkType.nose],
    ];

    for (final connection in connections) {
      final landmark1 = pose.landmarks[connection[0]];
      final landmark2 = pose.landmarks[connection[1]];

      if (landmark1 != null && landmark2 != null) {
        final point1 = _translatePoint(
          landmark1.x,
          landmark1.y,
          imageSize,
          size,
        );
        final point2 = _translatePoint(
          landmark2.x,
          landmark2.y,
          imageSize,
          size,
        );

        // Färbe Linien basierend auf durchschnittlicher Konfidenz
        final avgConfidence = (landmark1.likelihood + landmark2.likelihood) / 2;
        final linePaint = Paint()
          ..color = Colors.cyan.withOpacity(avgConfidence)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

        canvas.drawLine(point1, point2, linePaint);
      }
    }
  }

  Offset _translatePoint(
    double x,
    double y,
    Size imageSize,
    Size widgetSize,
  ) {
    // Skalierung für Rückkamera (keine Spiegelung nötig)
    final scaleX = widgetSize.width / imageSize.width;
    final scaleY = widgetSize.height / imageSize.height;

    final translatedX = x * scaleX;
    final translatedY = y * scaleY;

    return Offset(translatedX, translatedY);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses || oldDelegate.imageSize != imageSize;
  }
}
