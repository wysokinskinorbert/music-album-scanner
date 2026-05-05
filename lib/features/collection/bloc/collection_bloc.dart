import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/album_model.dart';
import '../../../data/repositories/album_repository.dart';

part 'collection_event.dart';
part 'collection_state.dart';

class CollectionBloc extends Bloc<CollectionEvent, CollectionState> {
  final AlbumRepository _repository;

  CollectionBloc(this._repository) : super(CollectionInitial()) {
    on<LoadCollection>(_onLoadCollection);
    on<SearchCollection>(_onSearchCollection);
    on<AddAlbum>(_onAddAlbum);
    on<DeleteAlbum>(_onDeleteAlbum);
    on<UpdateAlbum>(_onUpdateAlbum);
    on<ClearSearch>(_onClearSearch);
    on<ExportCollection>(_onExportCollection);
    on<ToggleFavorite>(_onToggleFavorite);
  }

  Future<void> _onLoadCollection(
    LoadCollection event,
    Emitter<CollectionState> emit,
  ) async {
    emit(CollectionLoading());
    try {
      final albums = _repository.getAllAlbums();
      emit(CollectionLoaded(
        albums: albums,
        totalCount: _repository.count,
      ));
    } catch (e) {
      emit(CollectionError(e.toString()));
    }
  }

  Future<void> _onSearchCollection(
    SearchCollection event,
    Emitter<CollectionState> emit,
  ) async {
    try {
      final results = _repository.search(event.query);
      emit(CollectionLoaded(
        albums: results,
        searchQuery: event.query,
        totalCount: _repository.count,
      ));
    } catch (e) {
      emit(CollectionError(e.toString()));
    }
  }

  Future<void> _onAddAlbum(
    AddAlbum event,
    Emitter<CollectionState> emit,
  ) async {
    try {
      await _repository.addAlbum(event.album);
      add(LoadCollection());
    } catch (e) {
      emit(CollectionError(e.toString()));
    }
  }

  Future<void> _onDeleteAlbum(
    DeleteAlbum event,
    Emitter<CollectionState> emit,
  ) async {
    try {
      await _repository.deleteAlbum(event.albumId);
      add(LoadCollection());
    } catch (e) {
      emit(CollectionError(e.toString()));
    }
  }

  Future<void> _onUpdateAlbum(
    UpdateAlbum event,
    Emitter<CollectionState> emit,
  ) async {
    try {
      await _repository.updateAlbum(event.album);
      add(LoadCollection());
    } catch (e) {
      emit(CollectionError(e.toString()));
    }
  }

  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<CollectionState> emit,
  ) async {
    add(LoadCollection());
  }

  Future<void> _onExportCollection(
    ExportCollection event,
    Emitter<CollectionState> emit,
  ) async {
    try {
      // Export collection as JSON - returns the list of maps
      _repository.exportCollection();
      emit(CollectionLoaded(
        albums: _repository.getAllAlbums(),
        totalCount: _repository.count,
        exportPath: 'collection_export.json',
      ));
    } catch (e) {
      emit(CollectionError(e.toString()));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<CollectionState> emit,
  ) async {
    try {
      // Album model doesn't have an isFavorite field that can be toggled via copyWith.
      // Just reload the collection for now.
      add(LoadCollection());
    } catch (e) {
      emit(CollectionError(e.toString()));
    }
  }
}
