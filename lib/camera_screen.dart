import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tflite_helper.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _detectedLetter = "";
  final TFLiteHelper _tfLiteHelper = TFLiteHelper();

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _initializeCamera();
    _tfLiteHelper.loadModel();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required')),
      );
    }
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    }
  }

  Future<void> _processFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      File tempFile = File(tempPath);
      await tempFile.writeAsBytes(await File(imageFile.path).readAsBytes());
      
      // Process with TFLite
      final result = await _tfLiteHelper.recognizeSignLanguage(tempFile);
      
      // Update UI
      if (mounted) {
        setState(() {
          _detectedLetter = result;
          _isProcessing = false;
        });
      }
      
      // Clean up temp file
      await tempFile.delete();
    } catch (e) {
      print('Error processing frame: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tfLiteHelper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Language Recognition'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _isCameraInitialized
                ? CameraPreview(_cameraController!)
                : const Center(child: CircularProgressIndicator()),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Detected Letter:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _detectedLetter,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _processFrame,
                    child: const Text('Capture and Process Image'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}