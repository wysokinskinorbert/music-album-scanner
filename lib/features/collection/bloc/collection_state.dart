part of 'collection_bloc.dart';

abstract class CollectionState extends Equatable {
  const CollectionState();
  @override
  List<Object?> get props => [];
}

class CollectionInitial extends CollectionState {}

class CollectionLoading extends CollectionState {}

class CollectionLoaded extends CollectionState {
  final List<Album> albums;
  final String? searchQuery;
  final int totalCount;

  const CollectionLoaded({
    required this.albums,
    this.searchQuery,
    required this.totalCount,
  });

  @override
  List<Object?> get props => [albums, searchQuery, totalCount];
}

class CollectionError extends CollectionState {
  final String message;
  const CollectionError(this.message);
  @override
  List<Object?> get props => [message];
}
