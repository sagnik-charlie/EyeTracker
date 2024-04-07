import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as pth;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dao/eye_data.dart';

class CameraView extends StatefulWidget {
  CameraView(
      {Key? key,
      required this.customPaint,
      required this.onImage,
      this.eye_data,
      this.onCameraFeedReady,
      this.onDetectorViewModeChanged,
      this.onCameraLensDirectionChanged,
      this.initialCameraLensDirection = CameraLensDirection.back})
      : super(key: key);

  final CustomPaint? customPaint;  
  final Function(InputImage inputImage) onImage;
  final MyData? eye_data;
  final VoidCallback? onCameraFeedReady;
  final VoidCallback? onDetectorViewModeChanged;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  var status;
  List<MyData>? eye_data_list=[];
  int _cameraIndex = -1;
  double _gyroX = 0.0; 
  double _gyroY = 0.0; 
  double _gyroZ = 0.0; 
  double _accX = 0.0; 
  double _accY = 0.0; 
  double _accZ = 0.0; 
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  bool _changingCameraLens = false;
  Sheet? sheet;
  double _random_top = 250;
  double _random_left = 250;
  Random _random = Random();
  String? path;
  bool saveButtonPressed=false;
  var excel;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
    gyroscopeEvents.listen((GyroscopeEvent event) { 
      setState(() { 
        _gyroX = event.x; 
        _gyroY = event.y; 
        _gyroZ = event.z; 
      }); 
    });
  accelerometerEvents.listen((AccelerometerEvent event) { 
      setState(() { 
        _accX = event.x; 
        _accY = event.y; 
        _accZ = event.z; 
      }); 
    }); 
  }

  void _initialize() async {
    status = await Permission.manageExternalStorage.request();
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    if(status==PermissionStatus.granted){
    Directory? directory = await getExternalStorageDirectory();
    path = '${directory?.path}/my_data${Random().nextInt(100)}.xlsx';
    print(path);  
      excel = Excel.createExcel();
      sheet = excel['Sheet1'];
      List<CellValue?> excelData = [];
        excelData.add(TextCellValue("FaceLeftCheek"));
        excelData.add(TextCellValue("FaceRightCheek"));
        excelData.add(TextCellValue("FacePhotoPath"));
        excelData.add(TextCellValue("LeftEyePath"));
        excelData.add(TextCellValue("RightEyePath")); 
        excelData.add(TextCellValue("LeftEyeContours"));
        excelData.add(TextCellValue("RightEyeContours")); 
        excelData.add(TextCellValue("LeftEyeLandmark"));
        excelData.add(TextCellValue("RightEyeLandmark")); 
        excelData.add(TextCellValue("HeadEulerAngleX"));
        excelData.add(TextCellValue("HeadEulerAngleY"));
        excelData.add(TextCellValue("HeadEulerAngleZ"));
        excelData.add(TextCellValue("Acc_X"));
        excelData.add(TextCellValue("Acc_Y"));
        excelData.add(TextCellValue("Acc_Z"));
        excelData.add(TextCellValue("Gyro_X"));
        excelData.add(TextCellValue("Gyro_Y"));
        excelData.add(TextCellValue("Gyro_Z"));
        excelData.add(TextCellValue("Gaze"));  
        sheet!.appendRow(excelData);
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _liveFeedBody());
  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty) return Container();
    if (_controller == null) return Container();
    if (_controller?.value.isInitialized == false) return Container();
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: _changingCameraLens
                ? Center(
                    child: const Text('Changing camera lens'),
                  )
                : CameraPreview(
                    _controller!,
                    child: widget.customPaint,
                  ),
          ),
          _saveButton(),
          _switchLiveCameraToggle(),
          _detectionViewModeToggle(),
          _increment(),
          _exposureControl(),
        ],
      ),
    );
  }

  Widget _saveButton() => Positioned(
        top: _random_top,
        left: _random_left,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            //onPressed: () => Navigator.of(context).pop(),
            onPressed: () async {
              saveButtonPressed=true;                
   },
            backgroundColor: Colors.blueAccent,
            child: Text('Start')
          ),
        ),
      );

  Widget _detectionViewModeToggle() => Positioned(
        bottom: 8,
        left: 8,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            onPressed: widget.onDetectorViewModeChanged,
            backgroundColor: Colors.black54,
            child: Icon(
              Icons.photo_library_outlined,
              size: 25,
            ),
          ),
        ),
      );

  Widget _switchLiveCameraToggle() => Positioned(
        bottom: 8,
        right: 8,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            onPressed: _switchLiveCamera,
            backgroundColor: Colors.black54,
            child: Icon(
              Platform.isIOS
                  ? Icons.flip_camera_ios_outlined
                  : Icons.flip_camera_android_outlined,
              size: 25,
            ),
          ),
        ),
      );

  Widget _increment() => Positioned(
        bottom: 16,
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 250,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
               '$_counter',
               style: TextStyle( fontSize: 16, color: Colors.white, // Text color
                  backgroundColor: Colors.blue, // Background color
                      ),
                    )
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _exposureControl() => Positioned(
        top: 40,
        right: 8,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 250,
          ),
          child: Column(children: [
            Container(
              width: 55,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    '${_currentExposureOffset.toStringAsFixed(1)}x',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SizedBox(
                  height: 30,
                  child: Slider(
                    value: _currentExposureOffset,
                    min: _minAvailableExposureOffset,
                    max: _maxAvailableExposureOffset,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white30,
                    onChanged: (value) async {
                      setState(() {
                        _currentExposureOffset = value;
                      });
                      await _controller?.setExposureOffset(value);
                    },
                  ),
                ),
              ),
            )
          ]),
        ),
      );

  Future _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      // Set to ResolutionPreset.high. Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }       
      _controller?.getMinZoomLevel().then((value) {
       // _currentZoomLevel = value;
       // _minAvailableZoom = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
       // _maxAvailableZoom = value;
      });
      _currentExposureOffset = 0.0;
      _controller?.getMinExposureOffset().then((value) {
        _minAvailableExposureOffset = value;
      });
      _controller?.getMaxExposureOffset().then((value) {
        _maxAvailableExposureOffset = value;
      });
      _controller?.startImageStream(_processCameraImage).then((value) {
        if (widget.onCameraFeedReady != null) {
          widget.onCameraFeedReady!();
        }
        if (widget.onCameraLensDirectionChanged != null) {
          widget.onCameraLensDirectionChanged!(camera.lensDirection);
        }
      });
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;

    await _stopLiveFeed();
    await _startLiveFeed();
    setState(() => _changingCameraLens = false);
  }

  void _updatePosition() {
    setState(() {
     // Generate random position within the screen boundaries
      _random_top = _random.nextDouble() * (MediaQuery.of(context).size.height - 50);
      _random_left = _random.nextDouble() * (MediaQuery.of(context).size.width - 100);
    });
  }
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _processData() async {
      for (var item in eye_data_list!) {
        Uint8List? nv21Image=await item.image_data.bytes!;
        img.Image? pngImage=await convertNV21toPNG(nv21Image);
        //pngImage = img.copyRotate(pngImage!, angle: -90);
        img.Image croppedImage_rightEye = img.copyCrop(pngImage!, x: item.right_eye.x-35, y: item.right_eye.y-25, width:64 , height:64);
        img.Image croppedImage_leftEye = img.copyCrop(pngImage!, x: item.left_eye.x-35, y:item.left_eye.y-25, width:64,height:64);
        String saved_img_path_rightEye= await saveImageAsPNG(croppedImage_rightEye,'rightEye');
        String saved_img_path_leftEye= await saveImageAsPNG(croppedImage_leftEye,'leftEye');
        String face_photo= await saveImageAsPNG(pngImage,'face');
        List<CellValue?> excelData = [];
        excelData.add(TextCellValue(item.left_cheek));
        excelData.add(TextCellValue(item.right_cheek));
        excelData.add(TextCellValue(face_photo));
        //excelData.add(TextCellValue(saved_img_path_rightEye));
        //excelData.add(TextCellValue(saved_img_path_leftEye));
        excelData.add(TextCellValue(saved_img_path_leftEye));
        excelData.add(TextCellValue(saved_img_path_rightEye)); 
        excelData.add(TextCellValue(item.leftEyeContour.toString().replaceAll(RegExp(r'Point') , '')));
        excelData.add(TextCellValue(item.rightEyeContour.toString().replaceAll(RegExp(r'Point') , '')));
        excelData.add(TextCellValue(item.left_eye.toString().replaceAll(RegExp(r'Point') , '')));
        excelData.add(TextCellValue(item.right_eye.toString().replaceAll(RegExp(r'Point') , '')));
        excelData.add(TextCellValue(item.head_euler_x));
        excelData.add(TextCellValue(item.head_euler_y));
     
        excelData.add(TextCellValue(item.head_euler_z));
        excelData.add(TextCellValue(_accX.toString()));
        excelData.add(TextCellValue(_accY.toString()));
        excelData.add(TextCellValue(_accZ.toString()));
        excelData.add(TextCellValue(_gyroX.toString()));
        excelData.add(TextCellValue(_gyroY.toString()));
        excelData.add(TextCellValue(_gyroZ.toString()));
     double gazeX=_random_left+25,gazeY=_random_top+25;
     excelData.add(TextCellValue('($gazeX,$gazeY)'));  
     sheet!.appendRow(excelData);
  }
  
    List<int>? fileBytes=excel.save();
    if (fileBytes != null) {
    File(pth.join(path!))
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);
      _updatePosition();
  }     
      
      // ignore: use_build_context_synchronously
      showDialog(
      context: this.context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text('Data saved'),
        actions: [
          TextButton(
            onPressed: () { 
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ); 
     
  }

  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage);
    if(saveButtonPressed && eye_data_list!.length<=5){
      eye_data_list?.add(widget.eye_data!);
    }
    if(status==PermissionStatus.granted && saveButtonPressed && eye_data_list!.length==5){
    _processData();
    saveButtonPressed=false;
    _incrementCounter();
    eye_data_list=[];
    }
    if(eye_data_list!.length>5){
      eye_data_list=[];
    }      
  }

  Future<img.Image?> convertNV21toPNG(Uint8List nv21ImageData) async {
  // Get image dimensions
  int width = 720; // Replace with actual width
  int height = 720; // Replace with actual height

  // Extract luminance (Y) component
  Uint8List yChannel = Uint8List(width * height);
  for (int i = 0; i < width * height ; i++) {
    yChannel[i] = nv21ImageData[i];
  }

  // Create grayscale image
  img.Image grayImage = img.Image(width: width, height:height);
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      int pixel = yChannel[x * width + y];
      img.Color grayColor=img.ColorRgb8(pixel,pixel,pixel);
      grayImage.setPixel(y, x, grayColor);
    }
  }

  // Encode grayscale image as PNG
  Uint8List pngImageData = img.encodePng(grayImage)!;
  img.Image? image = await img.decodePng(pngImageData);
  return image;
}

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }
  Future<String> saveImageAsPNG(img.Image? pngImageData,String folder) async {
  try {
    // Get the directory for storing images
    final Directory? extDir = await getExternalStorageDirectory();
    final String dirPath = '${extDir!.path}/$folder';
    await Directory(dirPath).create(recursive: true);

    // Generate a unique file name
    final String filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.png';

    // Write the file
    File(filePath).writeAsBytesSync(img.encodePng(pngImageData!));

    print('Image saved: $filePath');
    return filePath;
  } catch (e) {
    print('Error saving image: $e');
    return 'Error saving image: $e';
  }
}

  
}