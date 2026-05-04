import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

/// Represents a recognized music album with full metadata.
@HiveType(typeId: 0)
class Album extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String artist;

  @HiveField(3)
  final int? releaseYear;

  @HiveField(4)
  final String? label;

  @HiveField(5)
  final String? genre;

  @HiveField(6)
  final List<String> tracklist;

  @HiveField(7)
  final String? coverArtUrl;

  @HiveField(8)
  final String? userPhotoPath;

  @HiveField(9)
  final DateTime dateAdded;

  @HiveField(10)
  final String? musicBrainzId;

  @HiveField(11)
  final String? discogsId;

  @HiveField(12)
  final double recognitionConfidence;

  @HiveField(13)
  final String? barcode;

  @HiveField(14)
  final String? country;

  @HiveField(15)
  final String? format;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    this.releaseYear,
    this.label,
    this.genre,
    this.tracklist = const [],
    this.coverArtUrl,
    this.userPhotoPath,
    required this.dateAdded,
    this.musicBrainzId,
    this.discogsId,
    this.recognitionConfidence = 0.0,
    this.barcode,
    this.country,
    this.format,
  });

  Album copyWith({
    String? title,
    String? artist,
    int? releaseYear,
    String? label,
    String? genre,
    List<String>? tracklist,
    String? coverArtUrl,
    String? userPhotoPath,
    String? musicBrainzId,
    String? discogsId,
    double? recognitionConfidence,
    String? barcode,
    String? country,
    String? format,
  }) {
    return Album(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      releaseYear: releaseYear ?? this.releaseYear,
      label: label ?? this.label,
      genre: genre ?? this.genre,
      tracklist: tracklist ?? this.tracklist,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      userPhotoPath: userPhotoPath ?? this.userPhotoPath,
      dateAdded: dateAdded,
      musicBrainzId: musicBrainzId ?? this.musicBrainzId,
      discogsId: discogsId ?? this.discogsId,
      recognitionConfidence: recognitionConfidence ?? this.recognitionConfidence,
      barcode: barcode ?? this.barcode,
      country: country ?? this.country,
      format: format ?? this.format,
    );
  }

  /// Convenience getters for compatibility
  int? get year => releaseYear;
  double? get scanConfidence => recognitionConfidence == 0.0 ? null : recognitionConfidence;
  bool? get isFavorite => null; // TODO: implement favorites
  String? get recognitionSource => barcode != null ? 'barcode' : 'ocr';

  @override
  List<Object?> get props => [id, title, artist, musicBrainzId, discogsId];
}
