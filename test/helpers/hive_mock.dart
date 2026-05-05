// Konfiguracja Hive w pamięci do testów (bez prawdziwego systemu plików)
// In-memory Hive setup for tests – no real filesystem access.
//
// Użycie / Usage:
//   await HiveTestSetup.setUp();
//   // ... testy ...
//   await HiveTestSetup.tearDown();
//
// Lub użyj dekoratora setUp/tearDown w grupie testów:
//   setUpAll(HiveTestSetup.setUp);
//   tearDownAll(HiveTestSetup.tearDown);

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:music_album_scanner/core/constants/app_constants.dart';

/// Zarządza środowiskiem Hive dla testów jednostkowych.
/// Manages the in-memory Hive environment for unit tests.
class HiveTestSetup {
  static String? _tempPath;

  /// Inicjalizuje Hive z katalogiem tymczasowym (w pamięci/temp).
  /// Initializes Hive with a temporary directory (no real persistence).
  static Future<void> setUp() async {
    // Tworzy tymczasowy katalog dla Hive w /tmp
    _tempPath =
        '${Directory.systemTemp.path}/hive_test_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(_tempPath!).create(recursive: true);
    Hive.init(_tempPath!);

    // Otwiera standardowe boxy używane w aplikacji
    await Hive.openBox<dynamic>(AppConstants.hiveBoxName);
    await Hive.openBox<dynamic>(AppConstants.collectionBoxName);
    await Hive.openBox<dynamic>(AppConstants.settingsBoxName);
  }

  /// Czyści i zamyka środowisko Hive po testach.
  /// Cleans up and closes Hive after tests.
  static Future<void> tearDown() async {
    await Hive.deleteFromDisk();
    if (_tempPath != null) {
      final dir = Directory(_tempPath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
    _tempPath = null;
  }

  /// Zwraca tymczasową ścieżkę używaną przez Hive.
  /// Returns the temp path used by Hive in tests.
  static String? get tempPath => _tempPath;

  /// Otwiera dodatkowy box na żądanie / Opens an extra box on demand.
  static Future<Box<T>> openBox<T>(String name) async {
    return await Hive.openBox<T>(name);
  }

  /// Czyści zawartość wszystkich boxów bez ich zamykania.
  /// Clears all box contents without closing them.
  static Future<void> clearAllBoxes() async {
    for (final name in Hive.boxNames()) {
      final box = Hive.box(name);
      await box.clear();
    }
  }
}

/// Rejestracja adaptera Hive w trybie testowym (bez codegen-u).
/// Mock-style Hive adapter registration for testing without generated adapters.
///
/// Ponieważ projekt używa hive_generator, adaptery są generowane automatycznie.
/// W testach jednostkowych bez uruchamiania build_runner, możemy zarejestrować
/// adaptery ręcznie, lub użyć mapy typów do serializacji JSON.
class HiveAdapterMock {
  /// Rejestruje adapter w Hive. Używane gdy .g.dart nie jest dostępne.
  /// Registers a mock adapter. Useful when generated adapters are absent.
  static void registerMockAdapter<T>(
    TypeAdapter<T> adapter,
  ) {
    // Sprawdza, czy adapter nie jest już zarejestrowany
    // Checks if the adapter is already registered
    try {
      Hive.registerAdapter(adapter);
    } catch (_) {
      // Adapter już istnieje – ignorujemy / Adapter already registered – ignore
    }
  }
}
