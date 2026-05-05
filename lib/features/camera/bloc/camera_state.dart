part of 'camera_bloc.dart';

abstract class CameraState extends Equatable {
  const CameraState();
  @override
  List<Object?> get props => [];
}

class CameraInitial extends CameraState {}

class CameraInitializing extends CameraState {}

class CameraReadyState extends CameraState {
  final bool isFlashOn;
  final bool isFrontCamera;

  const CameraReadyState({
    this.isFlashOn = false,
    this.isFrontCamera = false,
  });

  CameraReadyState copyWith({bool? isFlashOn, bool? isFrontCamera}) {
    return CameraReadyState(
      isFlashOn: isFlashOn ?? this.isFlashOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    );
  }

  @override
  List<Object?> get props => [isFlashOn, isFrontCamera];
}

class CameraCapturing extends CameraState {}

class CameraCaptureSuccess extends CameraState {
  final String imagePath;
  const CameraCaptureSuccess(this.imagePath);
  @override
  List<Object?> get props => [imagePath];
}

class CameraError extends CameraState {
  final String message;
  const CameraError(this.message);
  @override
  List<Object?> get props => [message];
}
