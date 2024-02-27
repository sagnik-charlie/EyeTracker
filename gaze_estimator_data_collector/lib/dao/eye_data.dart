import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class MyData {
  String left_cheek;
  String right_cheek;
  InputImage image_data;
  String head_euler_x;
  String head_euler_y;
  String head_euler_z;
  Point<int> right_eye;
  Point<int> left_eye;
  String gaze;

  MyData({required this.left_cheek, required this.right_cheek,required this.image_data, required this.head_euler_x, required this.head_euler_y,
  required this.head_euler_z, required this.left_eye, required this.right_eye, required this.gaze});

  
}