import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_distance_and_position_measurement/MainScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final camera = cameras.first;
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MainScreen(cameras: cameras),
  ));
}
