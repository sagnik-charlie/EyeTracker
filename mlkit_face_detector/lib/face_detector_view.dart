import 'dart:io';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mlkit_face_detector/dao/eye_data.dart';
import 'package:path_provider/path_provider.dart';
import 'detector_view.dart';
import 'painters/face_detector_painter.dart';

class FaceDetectorView extends StatefulWidget {
  const FaceDetectorView({super.key});

  @override
  State<FaceDetectorView> createState() => _FaceDetectorViewState();
}

class _FaceDetectorViewState extends State<FaceDetectorView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      minFaceSize: 0.8,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  MyData? eye_data;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.front;

  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetectorView(
      title: 'Face Detector',
      customPaint: _customPaint,
      text: _text,
      onImage: _processImage,
      eye_data: eye_data,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    Map<FaceLandmarkType,FaceLandmark?> faceMap;
    Map<FaceContourType,FaceContour?> contourMap;
    
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final faces = await _faceDetector.processImage(inputImage);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) { 
        final painter = FaceDetectorPainter(
        faces,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      _customPaint = CustomPaint(painter: painter);
    } else {
      String text = 'Faces found: ${faces.length}\n\n';
      for (final face in faces) {
        text += 'face: ${face.boundingBox}\n\n';
      }
      _text = text;
      // TODO: set _customPaint to draw boundingRect on top of image
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {    
      setState(() {
        String head_euler_x='',head_euler_y='', head_euler_z='', left_cheek='',right_cheek='',right_eye='',left_eye='',gaze='';
        Point<int>? rightEye;
        Point<int>? leftEye;
        
        if(faces.isNotEmpty && faces[0].leftEyeOpenProbability!>0.2 && faces[0].rightEyeOpenProbability!>0.2){
        
        head_euler_x=faces[0].headEulerAngleX.toString().replaceAll(RegExp(r'Point') , '');
        //print(faces[0].headEulerAngleY);
        head_euler_y = faces[0].headEulerAngleY.toString().replaceAll(RegExp(r'Point') , '');
        //print(faces[0].headEulerAngleZ);
        head_euler_z = faces[0].headEulerAngleZ.toString().replaceAll(RegExp(r'Point') , '');
        //print("\nEye Gaze Landmarks\n");
        faceMap=faces[0].landmarks;
        faceMap.forEach((key, value) {
          if(key==FaceLandmarkType.leftCheek){
            left_cheek=(value!.position).toString().replaceAll(RegExp(r'Point') , '');
          }
          if(key==FaceLandmarkType.rightCheek){
            right_cheek=(value!.position).toString().replaceAll(RegExp(r'Point') , '');
          }
          if(key==FaceLandmarkType.rightEye){
              rightEye=value!.position;
          }
          if(key==FaceLandmarkType.leftEye){
            leftEye=value!.position;
          }
         });
        //print("\n Contours Co-orndinates \n");
        
       // print("\n Smiling Probablity \n");
        
        eye_data= MyData (left_cheek: left_cheek,right_cheek: right_cheek, image_data:inputImage, head_euler_x:head_euler_x ,left_eye: leftEye!, right_eye: rightEye!, head_euler_y: head_euler_y, head_euler_z: head_euler_z,gaze:gaze);
        //await saveImageAsPNG(pngImage);
        }  
      }
      );
    }
    
  }
}

