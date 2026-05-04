part of 'camera_bloc.dart';

abstract class CameraEvent extends Equatable {
  const CameraEvent();
  @override
  List<Object?> get props => [];
}

class InitializeCamera extends CameraEvent {}

class CapturePhoto extends CameraEvent {}

class ToggleFlash extends CameraEvent {}

class SwitchCamera extends CameraEvent {}

class PickFromGallery extends CameraEvent {}

class CameraReady extends CameraEvent {}
