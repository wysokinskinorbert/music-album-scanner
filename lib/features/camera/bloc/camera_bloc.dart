import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_constants.dart';

part 'camera_event.dart';
part 'camera_state.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  CameraController? get controller => _controller;

  CameraBloc() : super(CameraInitial()) {
    on<InitializeCamera>(_onInitializeCamera);
    on<CapturePhoto>(_onCapturePhoto);
    on<ToggleFlash>(_onToggleFlash);
    on<SwitchCamera>(_onSwitchCamera);
    on<PickFromGallery>(_onPickFromGallery);
  }

  Future<void> _onInitializeCamera(
    InitializeCamera event,
    Emitter<CameraState> emit,
  ) async {
    emit(CameraInitializing());
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        emit(const CameraError('No camera available'));
        return;
      }

      // Prefer back camera
      _currentCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_currentCameraIndex == -1) _currentCameraIndex = 0;

      await _initController(_cameras[_currentCameraIndex]);
      emit(const CameraReadyState());
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
  }

  Future<void> _onCapturePhoto(
    CapturePhoto event,
    Emitter<CameraState> emit,
  ) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    emit(CameraCapturing());
    try {
      final XFile photo = await _controller!.takePicture();
      final savedPath = await _savePhoto(photo);
      emit(CameraCaptureSuccess(savedPath));
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }

  Future<String> _savePhoto(XFile photo) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/album_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final filename = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPath = p.join(photosDir.path, filename);
    await File(photo.path).copy(savedPath);
    return savedPath;
  }

  Future<void> _onToggleFlash(
    ToggleFlash event,
    Emitter<CameraState> emit,
  ) async {
    if (_controller == null) return;
    final currentState = state is CameraReadyState
        ? state as CameraReadyState
        : const CameraReadyState();

    if (currentState.isFlashOn) {
      await _controller!.setFlashMode(FlashMode.off);
    } else {
      await _controller!.setFlashMode(FlashMode.torch);
    }
    emit(currentState.copyWith(isFlashOn: !currentState.isFlashOn));
  }

  Future<void> _onSwitchCamera(
    SwitchCamera event,
    Emitter<CameraState> emit,
  ) async {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    final currentState = state is CameraReadyState
        ? state as CameraReadyState
        : const CameraReadyState();

    try {
      await _initController(_cameras[_currentCameraIndex]);
      emit(currentState.copyWith(
        isFrontCamera: _cameras[_currentCameraIndex].lensDirection ==
            CameraLensDirection.front,
      ));
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }

  Future<void> _onPickFromGallery(
    PickFromGallery event,
    Emitter<CameraState> emit,
  ) async {
    // Handled by UI layer with image_picker
  }

  @override
  Future<void> close() {
    _controller?.dispose();
    return super.close();
  }
}
