part of 'scan_result_bloc.dart';

abstract class ScanResultState extends Equatable {
  const ScanResultState();
  @override
  List<Object?> get props => [];
}

class ScanResultInitial extends ScanResultState {}

class ScanResultProcessing extends ScanResultState {
  final String? imagePath;
  final String? currentStep;
  final int stepsCompleted;
  final int totalSteps;

  const ScanResultProcessing({
    this.imagePath,
    this.currentStep,
    this.stepsCompleted = 0,
    this.totalSteps = 4,
  });

  ScanResultProcessing copyWith({
    String? currentStep,
    int? stepsCompleted,
    int? totalSteps,
  }) {
    return ScanResultProcessing(
      imagePath: imagePath,
      currentStep: currentStep ?? this.currentStep,
      stepsCompleted: stepsCompleted ?? this.stepsCompleted,
      totalSteps: totalSteps ?? this.totalSteps,
    );
  }

  /// Progress 0.0 - 1.0.
  double get progress => totalSteps > 0 ? stepsCompleted / totalSteps : 0;

  @override
  List<Object?> get props => [imagePath, currentStep, stepsCompleted, totalSteps];
}

class ScanResultSuccess extends ScanResultState {
  final Album album;
  final String source;
  final double confidence;
  final String? imagePath;
  final String? pipelineSummary;
  final String? extractedText;

  const ScanResultSuccess({
    required this.album,
    required this.source,
    required this.confidence,
    this.imagePath,
    this.pipelineSummary,
    this.extractedText,
  });

  @override
  List<Object?> get props => [album, source, confidence, imagePath];
}

class ScanResultMultipleMatches extends ScanResultState {
  final List<Album> matches;
  final String? imagePath;
  final String? pipelineSummary;

  const ScanResultMultipleMatches({
    required this.matches,
    this.imagePath,
    this.pipelineSummary,
  });

  @override
  List<Object?> get props => [matches, imagePath];
}

class ScanResultFailure extends ScanResultState {
  final String message;
  final String? imagePath;
  final String? pipelineSummary;
  final String? extractedText;
  final int stepsAttempted;
  final int stepsSucceeded;

  const ScanResultFailure({
    required this.message,
    this.imagePath,
    this.pipelineSummary,
    this.extractedText,
    this.stepsAttempted = 0,
    this.stepsSucceeded = 0,
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
