import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';
import '../../data/services/recognition_service.dart';
import '../../data/models/recognition_result.dart';
import '../../services/smolvlm_service.dart';

/// Batch test screen that runs the FULL ENSEMBLE pipeline on all 19 covers.
/// Uses the real RecognitionService with OCR + SmolVLM + ImageLabeler + MusicBrainz + Discogs.
class EnsembleBatchTestScreen extends StatefulWidget {
  const EnsembleBatchTestScreen({super.key});

  @override
  State<EnsembleBatchTestScreen> createState() => _EnsembleBatchTestScreenState();
}

class _EnsembleBatchTestScreenState extends State<EnsembleBatchTestScreen> {
  late final RecognitionService _recognitionService;
  
  List<TestResult> _results = [];
  bool _isRunning = false;
  int _currentIndex = 0;
  int _totalCovers = 0;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _recognitionService = RecognitionService(
      apiClient: ApiClient(),
      smolVLM: SmolVLMService(),
    );
  }

  Future<void> _runBatchTest() async {
    final coversDir = Directory('/sdcard/Download/AlbumCovers');
    if (!coversDir.existsSync()) {
      setState(() => _status = 'ERROR: Covers directory not found');
      return;
    }

    final covers = coversDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
        .toList();

    setState(() {
      _isRunning = true;
      _totalCovers = covers.length;
      _currentIndex = 0;
      _results = [];
      _status = 'Starting batch test...';
    });

    for (int i = 0; i < covers.length; i++) {
      final cover = covers[i];
      final fileName = cover.path.split('/').last;
      
      setState(() {
        _currentIndex = i + 1;
        _status = 'Processing ${i + 1}/${covers.length}: $fileName';
      });

      // Parse expected artist and album from filename
      final expected = _parseExpected(fileName);
      
      // Run FULL ENSEMBLE recognition
      final result = await _recognitionService.recognizeFromImage(cover.path);
      
      // Check if match is correct
      final isMatch = _checkMatch(result, expected);
      
      setState(() {
        _results.add(TestResult(
          fileName: fileName,
          expectedArtist: expected.artist,
          expectedAlbum: expected.album,
          recognizedArtist: result.album?.artist ?? '',
          recognizedAlbum: result.album?.title ?? '',
          source: result.source,
          confidence: result.confidence,
          isMatch: isMatch,
          extractedText: result.extractedText ?? '',
          pipelineSummary: result.pipelineSummary ?? '',
        ));
      });

      // Small delay between covers
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isRunning = false;
      _status = 'Batch test complete!';
    });
  }

  ({String artist, String album}) _parseExpected(String fileName) {
    // Format: 01_Artist_Name_Album_Title.jpg
    final name = fileName.replaceAll('.jpg', '').replaceAll('.png', '');
    final parts = name.split('_');
    
    if (parts.length >= 3) {
      // Skip number prefix
      final startIdx = parts[0].isEmpty ? 1 : (int.tryParse(parts[0]) != null ? 1 : 0);
      
      // Find album title (usually after known artist names)
      final artistParts = <String>[];
      final albumParts = <String>[];
      
      bool foundArtist = false;
      for (int i = startIdx; i < parts.length; i++) {
        if (!foundArtist && _isKnownArtist(parts, i)) {
          artistParts.addAll(parts.sublist(startIdx, i + 1));
          albumParts.addAll(parts.sublist(i + 1));
          foundArtist = true;
          break;
        }
      }
      
      if (!foundArtist) {
        // Fallback: split in half
        final mid = (startIdx + parts.length) ~/ 2;
        artistParts.addAll(parts.sublist(startIdx, mid));
        albumParts.addAll(parts.sublist(mid));
      }
      
      return (
        artist: artistParts.join(' '),
        album: albumParts.join(' '),
      );
    }
    
    return (artist: '', album: '');
  }

  bool _isKnownArtist(List<String> parts, int idx) {
    // Check if this part completes a known artist name
    final joined = parts.sublist(0, idx + 1).join(' ').toLowerCase();
    final knownArtists = [
      'aphex twin', 'burial', 'daft punk', 'kendrick lamar',
      'massive attack', 'miles davis', 'nirvana', 'pink floyd',
      'radiohead', 'the beatles', 'the clash', 'the cure',
      'the smiths', 'the velvet underground', 'arcade fire',
      'bjork', 'boards of canada', 'david bowie', 'joy division',
      'kraftwerk', 'led zeppelin', 'metallica', 'portishead',
      'talking heads', 'tame impala',
    ];
    return knownArtists.any((a) => joined.contains(a));
  }

  bool _checkMatch(RecognitionResult result, ({String artist, String album}) expected) {
    if (result.album == null) return false;
    
    final recognizedArtist = result.album!.artist.toLowerCase();
    final recognizedAlbum = result.album!.title.toLowerCase();
    final expectedArtist = expected.artist.toLowerCase();
    final expectedAlbum = expected.album.toLowerCase();
    
    // Check artist match (fuzzy)
    final artistMatch = recognizedArtist.contains(expectedArtist) || 
                        expectedArtist.contains(recognizedArtist);
    
    // Check album match (fuzzy)
    final albumMatch = recognizedAlbum.contains(expectedAlbum) || 
                       expectedAlbum.contains(recognizedAlbum);
    
    return artistMatch || albumMatch; // Match if either artist OR album matches
  }

  @override
  Widget build(BuildContext context) {
    final correctCount = _results.where((r) => r.isMatch).length;
    final totalCount = _results.length;
    final percentage = totalCount > 0 ? (correctCount / totalCount * 100).toStringAsFixed(1) : '0';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Ensemble Batch Test'),
        actions: [
          if (!_isRunning)
            TextButton.icon(
              onPressed: _runBatchTest,
              icon: const Icon(Icons.play_arrow, color: Color(0xFF00D4FF)),
              label: const Text('RUN', style: TextStyle(color: Color(0xFF00D4FF))),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1A1A2E),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_currentIndex / $_totalCovers',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (totalCount > 0)
                      Text(
                        '$correctCount / $totalCount correct ($percentage%)',
                        style: TextStyle(
                          color: correctCount >= totalCount * 0.6 ? const Color(0xFF00FF88) : const Color(0xFFFF6B6B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _totalCovers > 0 ? _currentIndex / _totalCovers : 0,
                  backgroundColor: const Color(0xFF2A2A3E),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                ),
                const SizedBox(height: 8),
                Text(
                  _status,
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Results list
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return _buildResultCard(result, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(TestResult result, int coverNum) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isMatch ? const Color(0xFF00FF88) : const Color(0xFFFF6B6B),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: result.isMatch ? const Color(0xFF00FF88).withOpacity(0.2) : const Color(0xFFFF6B6B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result.isMatch ? '✓ MATCH' : '✗ MISS',
                  style: TextStyle(
                    color: result.isMatch ? const Color(0xFF00FF88) : const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cover $coverNum',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${(result.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: result.confidence >= 0.7 ? const Color(0xFF00FF88) : const Color(0xFFFFA500),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Expected: ${result.expectedArtist} - ${result.expectedAlbum}',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Found: ${result.recognizedArtist.isNotEmpty ? result.recognizedArtist : 'N/A'} - ${result.recognizedAlbum.isNotEmpty ? result.recognizedAlbum : 'N/A'}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Source: ${result.source}',
            style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11),
          ),
          if (result.extractedText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'OCR: ${result.extractedText.substring(0, result.extractedText.length > 50 ? 50 : result.extractedText.length)}...',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class TestResult {
  final String fileName;
  final String expectedArtist;
  final String expectedAlbum;
  final String recognizedArtist;
  final String recognizedAlbum;
  final String source;
  final double confidence;
  final bool isMatch;
  final String extractedText;
  final String pipelineSummary;

  TestResult({
    required this.fileName,
    required this.expectedArtist,
    required this.expectedAlbum,
    required this.recognizedArtist,
    required this.recognizedAlbum,
    required this.source,
    required this.confidence,
    required this.isMatch,
    required this.extractedText,
    required this.pipelineSummary,
  });
}