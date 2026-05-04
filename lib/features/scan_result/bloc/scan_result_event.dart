part of 'scan_result_bloc.dart';

abstract class ScanResultEvent extends Equatable {
  const ScanResultEvent();

  @override
  List<Object?> get props => [];
}

class StartRecognition extends ScanResultEvent {
  final String imagePath;
  const StartRecognition(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

class ManualSearch extends ScanResultEvent {
  final String artist;
  final String album;
  const ManualSearch({required this.artist, required this.album});

  @override
  List<Object?> get props => [artist, album];
}

class ConfirmAndSave extends ScanResultEvent {
  final Album album;
  const ConfirmAndSave({required this.album});

  @override
  List<Object?> get props => [album];
}

class SelectResult extends ScanResultEvent {
  final Album album;
  const SelectResult({required this.album});

  @override
  List<Object?> get props => [album];
}

class RetryRecognition extends ScanResultEvent {
  final String imagePath;
  const RetryRecognition(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

class CancelRecognition extends ScanResultEvent {
  const CancelRecognition();
}
