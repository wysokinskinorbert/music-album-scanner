import 'package:equatable/equatable.dart';

/// Represents a single scanning session with the camera.
class ScanSession extends Equatable {
  final String id;
  final String? photoPath;
  final DateTime timestamp;
  final ScanStatus status;

  const ScanSession({
    required this.id,
    this.photoPath,
    required this.timestamp,
    this.status = ScanStatus.initial,
  });

  ScanSession copyWith({
    String? photoPath,
    ScanStatus? status,
  }) {
    return ScanSession(
      id: id,
      photoPath: photoPath ?? this.photoPath,
      timestamp: timestamp,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, photoPath, status];
}

enum ScanStatus {
  initial,
  capturing,
  processing,
  recognized,
  failed,
}
