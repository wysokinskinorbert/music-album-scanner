part of 'scan_result_bloc.dart';

abstract class ScanResultState extends Equatable {
  const ScanResultState();
  @override
  List<Object?> get props => [];
}

class ScanResultInitial extends ScanResultState {}

class ScanResultProcessing extends ScanResultState {
  final String? imagePath;
  const ScanResultProcessing({this.imagePath});
}

class ScanResultSuccess extends ScanResultState {
  final Album album;
  final String source;
  final double confidence;
  final String? imagePath;

  const ScanResultSuccess({
    required this.album,
    required this.source,
    required this.confidence,
    this.imagePath,
  });

  @override
  List<Object?> get props => [album, source, confidence, imagePath];
}

class ScanResultMultipleMatches extends ScanResultState {
  final List<Album> matches;
  final String? imagePath;

  const ScanResultMultipleMatches({
    required this.matches,
    this.imagePath,
  });

  @override
  List<Object?> get props => [matches, imagePath];
}

class ScanResultFailure extends ScanResultState {
  final String message;
  final String? imagePath;

  const ScanResultFailure({
    required this.message,
    this.imagePath,
  });

  @override
  List<Object?> get props => [message, imagePath];
}

class ScanResultSaved extends ScanResultState {
  final Album album;
  const ScanResultSaved(this.album);
  @override
  List<Object?> get props => [album];
}
