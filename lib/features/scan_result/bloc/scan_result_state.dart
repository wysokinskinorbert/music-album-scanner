part of 'scan_result_bloc.dart';

abstract class ScanResultState extends Equatable {
  const ScanResultState();

  @override
  List<Object?> get props => [];
}

class ScanResultInitial extends ScanResultState {
  const ScanResultInitial();
}

class ScanResultProcessing extends ScanResultState {
  final String currentStep;
  final int stepsCompleted;
  final int totalSteps;
  final String? pipelineSummary;
  final String? extractedText;

  const ScanResultProcessing({
    this.currentStep = 'Processing...',
    this.stepsCompleted = 0,
    this.totalSteps = 4,
    this.pipelineSummary,
    this.extractedText,
  });

  @override
  List<Object?> get props => [currentStep, stepsCompleted, totalSteps, pipelineSummary, extractedText];
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
    this.source = 'unknown',
    this.confidence = 0.0,
    this.imagePath,
    this.pipelineSummary,
    this.extractedText,
  });

  @override
  List<Object?> get props => [album, source, confidence, imagePath, pipelineSummary, extractedText];
}

class ScanResultFailure extends ScanResultState {
  final String message;
  final String? imagePath;
  final String? pipelineSummary;
  final String? extractedText;

  const ScanResultFailure({
    required this.message,
    this.imagePath,
    this.pipelineSummary,
    this.extractedText,
  });

  @override
  List<Object?> get props => [message, imagePath, pipelineSummary, extractedText];
}

class ScanResultSaved extends ScanResultState {
  final Album album;
  const ScanResultSaved(this.album);

  @override
  List<Object?> get props => [album];
}
