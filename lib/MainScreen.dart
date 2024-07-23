import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  MainScreen({required this.cameras});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  double focalLengthMm = 4.3;
  double sensorHeightMm = 5.76;
  double horizontalFOV = 62.2; // Camera's horizontal field of view in degrees
  double verticalFOV = 48.8;

  late CameraController _controller;
  bool isModelLoaded = false;
  List<dynamic>? recognitions;
  int imageHeight = 0;
  int imageWidth = 0;
  bool isProcessingFrame = false;


  double calculateDistance(double objectHeightMm, double boundingBoxHeightPixels) {
    double distanceMm = (focalLengthMm * objectHeightMm * imageHeight) /
        (boundingBoxHeightPixels * sensorHeightMm);
    return distanceMm / 1000;
  }

  double calculateHorizontalDistance(double boundingBoxX) {
    double screenCenterX = imageWidth / 2;
    double objectCenterX = boundingBoxX + (imageWidth * 0.5);
    return (objectCenterX - screenCenterX) / screenCenterX;
  }

  String getObjectDirection(double horizontalDistance) {
    if (horizontalDistance < -0.33) {
      return "left";
    } else if (horizontalDistance > 0.33) {
      return "right";
    } else {
      return "center";
    }
  }

  double getObjectKnownHeight(String label) {
    // Existing switch case
    switch (label) {
      case "person":
        return 1700.0;
      case "bicycle":
        return 1100.0;
      case "car":
        return 1500.0;
    // Add all other cases as needed
      default:
        return 1000.0;
    }
  }

  @override
  void initState() {
    super.initState();
    loadModel();
    initializeCamera();
  }



  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }


  Future<void> loadModel() async {
    String? res = await Tflite.loadModel(
      model: 'assets/detect.tflite',
      labels: 'assets/labelmap.txt',
    );
    setState(() {
      isModelLoaded = res != null;
    });
  }

  void initializeCamera() async {
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller.initialize();

    if (!mounted) {
      return;
    }

    setState(() {
      imageHeight = _controller.value.previewSize!.height.toInt();
      imageWidth = _controller.value.previewSize!.width.toInt();
    });

    _controller.startImageStream((CameraImage image) {
      if (isModelLoaded && !isProcessingFrame) {
        isProcessingFrame = true;
        runModel(image).then((_) {
          isProcessingFrame = false;
        });
      }
    });
  }

  Future<void> runModel(CameraImage image) async {
    if (image.planes.isEmpty) return;

    var recognitions = await Tflite.detectObjectOnFrame(
      bytesList: image.planes.map((plane) => plane.bytes).toList(),
      model: 'SSDMobileNet',
      imageHeight: image.height,
      imageWidth: image.width,
      imageMean: 127.5,
      imageStd: 127.5,
      numResultsPerClass: 5,
      threshold: 0.5,
      asynch: true,
    );

    if (recognitions != null) {


      setState(() {
        this.recognitions = recognitions;
        for (var rec in recognitions!) {
          double objectHeightMm = getObjectKnownHeight(rec['detectedClass']);
          double boundingBoxHeightPixels = rec['rect']['h'] * imageHeight.toDouble();
          double distance = calculateDistance(objectHeightMm, boundingBoxHeightPixels);
          rec["distance"] = distance;

          // Calculate the center of the bounding box
          double boundingBoxCenterX = (rec['rect']['x'] + rec['rect']['w'] / 2) * imageWidth;

          // Determine position relative to the center
          String position;
          if (boundingBoxCenterX < imageWidth / 3) {
            position = 'left';
          } else if (boundingBoxCenterX > (imageWidth / 3) * 2) {
            position = 'right';
          } else {
            position = 'center';
          }
          rec["position"] = position;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container();
    }
    return SafeArea(
      child: Scaffold(
        body: Expanded(
          child: Stack(
            children: [
              CameraPreview(_controller),
              if (recognitions != null)
                BoundingBoxes(
                  recognitions: recognitions!,
                  screenH: MediaQuery.of(context).size.height,
                  screenW: MediaQuery.of(context).size.width,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BoundingBoxes extends StatelessWidget {
  final List<dynamic> recognitions;
  final double screenH;
  final double screenW;

  BoundingBoxes({
    required this.recognitions,
    required this.screenH,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: recognitions.map((rec) {
        var x = rec["rect"]["x"] * screenW;
        var y = rec["rect"]["y"] * screenH;
        double w = rec["rect"]["w"] * screenW;
        double h = rec["rect"]["h"] * screenH;

        // Ensure bounding boxes stay within screen limits
        x = x < 0 ? 0 : x;
        y = y < 0 ? 0 : y;
        w = x + w > screenW ? screenW - x : w;
        h = y + h > screenH ? screenH - y : h;

        double distance = rec["distance"];
        String position = rec["position"];

        return Positioned(
          left: x,
          top: y,
          width: w,
          height: h,
          child: Container(
            padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blueAccent,
                width: 3,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rec["detectedClass"],
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Distance: ${distance.round()} meters",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Position: $position",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
