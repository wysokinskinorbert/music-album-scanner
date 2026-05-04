import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/album_model.dart';
import '../../../data/models/recognition_result.dart';
import '../../../data/services/recognition_service.dart';
import '../../../data/repositories/album_repository.dart';

part 'scan_result_event.dart';
part 'scan_result_state.dart';

class ScanResultBloc extends Bloc<ScanResultEvent, ScanResultState> {
  final RecognitionService _recognition;
  final AlbumRepository _repository;

  // Keep pipeline results for multiple match selection
  RecognitionPipelineResult? _lastPipelineResult;

  ScanResultBloc({
    required RecognitionService recognition,
    required AlbumRepository repository,
  })  : _recognition = recognition,
        _repository = repository,
        super(ScanResultInitial()) {
    on<StartRecognition>(_onStartRecognition);
    on<ManualSearch>(_onManualSearch);
    on<ConfirmAndSave>(_onConfirmAndSave);
    on<SelectResult>(_onSelectResult);
    on<RetryRecognition>(_onRetryRecognition);
    on<CancelRecognition>(_onCancelRecognition);
  }

  Future<void> _onStartRecognition(
    StartRecognition event,
    Emitter<ScanResultState> emit,
  ) async {
    // Step 1: Barcode scan
    emit(const ScanResultProcessing(
      currentStep: 'Scanning barcode...',
      stepsCompleted: 0,
      totalSteps: 4,
    ));

    final pipelineResult = await _recognition.recognizeAlbum(event.imagePath);
    _lastPipelineResult = pipelineResult;

    final result = pipelineResult.bestResult;

    if (result.isSuccess) {
      final rawData = result.rawApiData ?? {};
      final album = Album(
        id: const Uuid().v4(),
        title: rawData['title'] ?? result.albumTitle ?? 'Unknown',
        artist: rawData['artist'] ?? result.artist ?? 'Unknown',
        releaseYear: rawData['releaseYear'],
        label: rawData['label'],
        genre: rawData['genre'],
        tracklist: List<String>.from(rawData['tracklist'] ?? []),
        coverArtUrl: rawData['coverArtUrl'],
        userPhotoPath: event.imagePath,
        dateAdded: DateTime.now(),
        musicBrainzId: rawData['musicBrainzId'],
        discogsId: rawData['discogsId'],
        recognitionConfidence: result.confidence,
        barcode: rawData['barcode'],
        country: rawData['country'],
      );

      emit(ScanResultSuccess(
        album: album,
        source: result.sourceLabel,
        confidence: result.confidence,
        imagePath: event.imagePath,
        pipelineSummary: pipelineResult.pipelineSummary,
        extractedText: pipelineResult.extractedText?.rawText,
      ));
    } else {
      emit(ScanResultFailure(
        message: result.errorMessage ?? 'Recognition failed',
        imagePath: event.imagePath,
        pipelineSummary: pipelineResult.pipelineSummary,
        extractedText: pipelineResult.extractedText?.rawText,
        stepsAttempted: pipelineResult.stepsAttempted,
        stepsSucceeded: pipelineResult.stepsSucceeded,
      ));
    }
  }

  Future<void> _onManualSearch(
    ManualSearch event,
    Emitter<ScanResultState> emit,
  ) async {
    emit(const ScanResultProcessing(currentStep: 'Searching...'));

    final result = await _recognition.searchByQuery(
      event.artist,
      event.album,
    );

    if (result.isSuccess && result.rawApiData != null) {
      final rawData = result.rawApiData!;
      final album = Album(
        id: const Uuid().v4(),
        title: rawData['title'] ?? event.album,
        artist: rawData['artist'] ?? event.artist,
        releaseYear: rawData['releaseYear'],
        label: rawData['label'],
        genre: rawData['genre'],
        tracklist: List<String>.from(rawData['tracklist'] ?? []),
        coverArtUrl: rawData['coverArtUrl'],
        dateAdded: DateTime.now(),
        musicBrainzId: rawData['musicBrainzId'],
        discogsId: rawData['discogsId'],
        recognitionConfidence: result.confidence,
      );
      emit(ScanResultSuccess(
        album: album,
        source: result.sourceLabel,
        confidence: result.confidence,
      ));
    } else {
      emit(ScanResultFailure(
        message: result.errorMessage ?? 'No results found for "\${event.artist} - \${event.album}"',
      ));
    }
  }

  Future<void> _onConfirmAndSave(
    ConfirmAndSave event,
    Emitter<ScanResultState> emit,
  ) async {
    try {
      await _repository.addAlbum(event.album);
      emit(ScanResultSaved(event.album));
    } catch (e) {
      emit(ScanResultFailure(message: 'Failed to save: ${e.toString()}'));
    }
  }

  Future<void> _onSelectResult(
    SelectResult event,
    Emitter<ScanResultState> emit,
  ) async {
    // For future: select from multiple matches
  }

  Future<void> _onRetryRecognition(
    RetryRecognition event,
    Emitter<ScanResultState> emit,
  ) async {
    add(StartRecognition(event.imagePath));
  }

  Future<void> _onCancelRecognition(
    CancelRecognition event,
    Emitter<ScanResultState> emit,
  ) async {
    emit(ScanResultInitial());
  }
}
