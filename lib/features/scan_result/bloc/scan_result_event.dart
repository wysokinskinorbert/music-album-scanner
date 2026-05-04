part of 'scan_result_bloc.dart';

abstract class ScanResultEvent extends Equatable {
  const ScanResultEvent();
  @override
  List<Object?> get props => [];
}

/// Start recognition on a captured image.
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

/// Confirm and save the recognized album.
class ConfirmAndSave extends ScanResultEvent {
  final Album album;
  const ConfirmAndSave(this.album);
  @override
  List<Object?> get props => [album];
}

/// Edit recognized data before saving.
class EditRecognizedData extends ScanResultEvent {
  final String? title;
  final String? artist;
  final int? releaseYear;
  final String? genre;
  final String? label;
  const EditRecognizedData({
    this.title,
    this.artist,
    this.releaseYear,
    this.genre,
    this.label,
  });
}

/// Retry recognition.
class RetryRecognition extends ScanResultEvent {
  final String imagePath;
  const RetryRecognition(this.imagePath);
  @override
  List<Object?> get props => [imagePath];
}
