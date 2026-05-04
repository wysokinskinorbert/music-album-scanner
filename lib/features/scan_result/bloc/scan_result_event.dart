part of 'scan_result_bloc.dart';

abstract class ScanResultEvent extends Equatable {
  const ScanResultEvent();
  @override
  List<Object?> get props => [];
}

/// Start full recognition pipeline on a captured image.
class StartRecognition extends ScanResultEvent {
  final String imagePath;
  const StartRecognition(this.imagePath);
  @override
  List<Object?> get props => [imagePath];
}

/// Manual search by text input.
class ManualSearch extends ScanResultEvent {
  final String artist;
  final String album;
  const ManualSearch({required this.artist, required this.album});
  @override
  List<Object?> get props => [artist, album];
}

/// Confirm and save the recognized album to collection.
class ConfirmAndSave extends ScanResultEvent {
  final Album album;
  const ConfirmAndSave(this.album);
  @override
  List<Object?> get props => [album];
}

/// Select one result from multiple matches.
class SelectResult extends ScanResultEvent {
  final int index;
  const SelectResult(this.index);
  @override
  List<Object?> get props => [index];
}

/// Retry recognition (restart the pipeline).
class RetryRecognition extends ScanResultEvent {
  final String imagePath;
  const RetryRecognition(this.imagePath);
  @override
  List<Object?> get props => [imagePath];
}

/// Cancel recognition and go back.
class CancelRecognition extends ScanResultEvent {}
