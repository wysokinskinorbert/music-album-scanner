part of 'collection_bloc.dart';

abstract class CollectionEvent extends Equatable {
  const CollectionEvent();
  @override
  List<Object?> get props => [];
}

/// Load all albums in collection.
class LoadCollection extends CollectionEvent {}

/// Search collection by query.
class SearchCollection extends CollectionEvent {
  final String query;
  const SearchCollection(this.query);
  @override
  List<Object?> get props => [query];
}

/// Add album to collection.
class AddAlbum extends CollectionEvent {
  final Album album;
  const AddAlbum(this.album);
  @override
  List<Object?> get props => [album];
}

/// Remove album from collection.
class DeleteAlbum extends CollectionEvent {
  final String albumId;
  const DeleteAlbum(this.albumId);
  @override
  List<Object?> get props => [albumId];
}

/// Update existing album.
class UpdateAlbum extends CollectionEvent {
  final Album album;
  const UpdateAlbum(this.album);
  @override
  List<Object?> get props => [album];
}

/// Clear search and show all.
class ClearSearch extends CollectionEvent {}

/// Export collection to JSON/CSV.
class ExportCollection extends CollectionEvent {}

/// Toggle album favorite status.
class ToggleFavorite extends CollectionEvent {
  final String albumId;
  const ToggleFavorite(this.albumId);
  @override
  List<Object?> get props => [albumId];
}
