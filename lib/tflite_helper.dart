import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteHelper {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _modelLoaded = false;

  Future<void> loadModel() async {
    try {
      // Load the model
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      
      await loadLabels();
      
      _modelLoaded = true;
      print('TFLite model loaded successfully with ${_labels.length} labels');
    } catch (e) {
      print('Error loading model: $e');
    }
  }
  Future<void> loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData.split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      print('Loaded ${_labels.length} labels');
    } catch (e) {
      print('Error loading labels: $e');
      _labels = [
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
        'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
        'U', 'V', 'W', 'X', 'Y', 'Z'
      ];
      print('Using default alphabet labels');
    }
  }
  Future<String> recognizeSignLanguage(File imageFile) async {
    if (!_modelLoaded) {
      await loadModel();
    }

    if (_interpreter == null) {
      return 'Model not loaded';
    }

    // Read the image file
    img.Image? image = img.decodeImage(await imageFile.readAsBytes());
    if (image == null) return 'Failed to decode image';

    // Convert to grayscale
    img.Image grayscale = img.grayscale(image);

    // Resize to 64x64
    img.Image resized = img.copyResize(grayscale, width: 64, height: 64);

    // Save the resised image
    Directory tempDir = await getTemporaryDirectory();
    String resizedImagePath = path.join(tempDir.path, 'resized_image.png');
    File resizedFile = File(resizedImagePath);
    resizedFile.writeAsBytesSync(img.encodePng(resized));
    print('Resised image saved to $resizedImagePath');

    // Convert image to input tensor format [1, 64, 64, 1]
    // The model expects 4D input with shape [1, 64, 64, 1]
    var input = List.generate(
      1,
      (_) => List.generate(
        64,
        (y) => List.generate(
          64,
          (x) => List.generate(
            1,
            (_) => img.getLuminance(resized.getPixel(x, y)) / 255.0,
          ),
        ),
      ),
    );

    // output tensor
    var output = List.filled(1 * 26, 0.0).reshape([1, 26]);

    // Run model
    _interpreter!.run(input, output);

    // Find class with highest probability
    int maxIndex = 0;
    double maxProb = output[0][0];
    
    for (int i = 1; i < output[0].length; i++) {
      if (output[0][i] > maxProb) {
        maxProb = output[0][i];
        maxIndex = i;
      }
    }

    // Debug logging
    print('Raw output: ${output[0]}');
    print('Predicted class index: $maxIndex with confidence: $maxProb');

    // Return predicted label
    if (maxIndex >= 0 && maxIndex < _labels.length) {
      return _labels[maxIndex];
    } else {
      return 'Unknown (index $maxIndex)';
    }
  }

  // Dispose of the interpreter when done
  void dispose() {
    _interpreter?.close();
  }
}