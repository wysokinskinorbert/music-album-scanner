// Unit test for _calculateMatchScore logic
// This tests the scoring algorithm without needing an Android device
//
// Run: dart test test/scoring_test.dart

/// Replicates the _calculateMatchScore logic from RecognitionService
/// for unit testing purposes.
double calculateMatchScore(String query, String artist, String title) {
  final queryLower = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
  final artistLower = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
  final titleLower = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
  final combinedLower = '$artistLower $titleLower';
  final combinedReverse = '$titleLower $artistLower';

  if (queryLower.length < 3) return 0.0;

  final genericWords = {'hat', 'neon', 'insect', 'gold', 'disc', 'blue', 'red', 'black', 'white',
    'original', 'remaster', 'digital', 'analog', 'vinyl', 'cd', 'lp', 'ep'};
  final queryWords = queryLower.split(RegExp(r'\s+'));
  if (queryWords.length == 1 && genericWords.contains(queryLower)) {
    return 0.0;
  }

  final isSelfTitled = artistLower == titleLower;

  int artistMatches = 0;
  int titleMatches = 0;
  int meaningfulWords = 0;
  for (final word in queryWords) {
    if (word.length < 3) continue;
    meaningfulWords++;
    final inArtist = artistLower.contains(word);
    final inTitle = titleLower.contains(word);
    if (inArtist) artistMatches++;
    if (inTitle) titleMatches++;
  }
  if (meaningfulWords == 0) return 0.0;

  final matchedWords = artistMatches + titleMatches;
  double score = matchedWords / meaningfulWords;

  // Specificity bonus
  if (queryWords.length >= 4 && matchedWords >= 3) {
    score += 0.15;
  } else if (queryWords.length >= 3 && matchedWords >= 2) {
    score += 0.10;
  }

  // Title match bonus
  if (titleMatches >= 1 && !isSelfTitled) {
    score += 0.15 * titleMatches;
  }

  // Full query substring bonus
  if (combinedLower.contains(queryLower) || combinedReverse.contains(queryLower)) {
    score += 0.25;
  }

  // Exact artist match bonus
  if (artistLower == queryLower || queryLower.contains(artistLower)) {
    score += 0.15;
  }

  // Self-titled penalty
  if (isSelfTitled && meaningfulWords > 1) {
    int nonArtistWords = 0;
    for (final word in queryWords) {
      if (word.length < 3) continue;
      if (!artistLower.contains(word)) nonArtistWords++;
    }
    if (nonArtistWords > 0) {
      score *= 0.5;
    }
  }

  // Single-word title-only penalty
  if (queryWords.length == 1 && titleLower.contains(queryLower) && !artistLower.contains(queryLower)) {
    score *= 0.3;
  }

  // Artist mismatch penalty
  bool artistHasAnyWord = false;
  for (final word in queryWords) {
    if (word.length >= 3 && artistLower.contains(word)) {
      artistHasAnyWord = true;
      break;
    }
  }
  if (!artistHasAnyWord && meaningfulWords > 0) {
    score *= 0.5;
  }

  return score.clamp(0.0, 1.5);
}

void main() {
  final tests = <_TestCase>[
    // ========================================
    // KEY TEST: "Master of Puppets Metallica" should prefer the real album over self-titled
    // ========================================
    _TestCase(
      query: 'Master of Puppets Metallica',
      artist: 'Metallica',
      title: 'Master of Puppets',
      description: 'Full query → correct album',
    ),
    _TestCase(
      query: 'Master of Puppets Metallica',
      artist: 'Metallica',
      title: 'Metallica', // self-titled
      description: 'Full query → self-titled (should score LOWER)',
    ),

    // ========================================
    // All 20 test cases from integration test
    // ========================================

    // 01. Radiohead - OK Computer
    _TestCase(
      query: 'OK Computer Radiohead',
      artist: 'Radiohead',
      title: 'OK Computer',
      description: 'Radiohead OK Computer → correct',
    ),
    _TestCase(
      query: 'OK Computer Radiohead',
      artist: 'Radiohead',
      title: 'Radiohead',
      description: 'Radiohead OK Computer → self-titled',
    ),

    // 02. Miles Davis - Kind of Blue
    _TestCase(
      query: 'Kind of Blue Miles Davis',
      artist: 'Miles Davis',
      title: 'Kind of Blue',
      description: 'Miles Davis Kind of Blue → correct',
    ),

    // 03. Daft Punk - Discovery
    _TestCase(
      query: 'Daft Punk Discovery',
      artist: 'Daft Punk',
      title: 'Discovery',
      description: 'Daft Punk Discovery → correct',
    ),

    // 04. Nirvana - Nevermind
    _TestCase(
      query: 'Nevermind Nirvana',
      artist: 'Nirvana',
      title: 'Nevermind',
      description: 'Nirvana Nevermind → correct',
    ),
    _TestCase(
      query: 'Nevermind Nirvana',
      artist: 'Nirvana',
      title: 'Nirvana',
      description: 'Nirvana Nevermind → self-titled',
    ),

    // 05. Kendrick Lamar - TPAB
    _TestCase(
      query: 'To Pimp a Butterfly Kendrick Lamar',
      artist: 'Kendrick Lamar',
      title: 'To Pimp a Butterfly',
      description: 'TPAB → correct',
    ),
    _TestCase(
      query: 'To Pimp a Butterfly Kendrick Lamar',
      artist: 'Kendrick Lamar',
      title: 'Kendrick Lamar',
      description: 'TPAB → self-titled',
    ),

    // 06. Burial - Untrue
    _TestCase(
      query: 'Untrue Burial',
      artist: 'Burial',
      title: 'Untrue',
      description: 'Burial Untrue → correct',
    ),

    // 07. Bjork - Homogenic
    _TestCase(
      query: 'Homogenic Bjork',
      artist: 'Bjork',
      title: 'Homogenic',
      description: 'Bjork Homogenic → correct',
    ),

    // 08. Black Sabbath - Paranoid
    _TestCase(
      query: 'Paranoid Black Sabbath',
      artist: 'Black Sabbath',
      title: 'Paranoid',
      description: 'Black Sabbath Paranoid → correct',
    ),

    // 09. Fela Kuti - Zombie
    _TestCase(
      query: 'Zombie Fela Kuti',
      artist: 'Fela Kuti',
      title: 'Zombie',
      description: 'Fela Kuti Zombie → correct',
    ),

    // 12. Can - Tago Mago
    _TestCase(
      query: 'Tago Mago Can',
      artist: 'Can',
      title: 'Tago Mago',
      description: 'Can Tago Mago → correct',
    ),

    // 13. Aphex Twin - SAW 85-92
    _TestCase(
      query: 'SAW 85-92 Aphex Twin',
      artist: 'Aphex Twin',
      title: 'Selected Ambient Works 85-92',
      description: 'Aphex Twin SAW → partial title match',
    ),

    // 14. Fleetwood Mac - Rumours
    _TestCase(
      query: 'Rumours Fleetwood Mac',
      artist: 'Fleetwood Mac',
      title: 'Rumours',
      description: 'Fleetwood Mac Rumours → correct',
    ),

    // 15. Boards of Canada - MHTRTC
    _TestCase(
      query: 'Music Has the Right to Children Boards of Canada',
      artist: 'Boards of Canada',
      title: 'Music Has the Right to Children',
      description: 'BoC MHTRTC → correct',
    ),

    // 17. Talking Heads - Remain in Light
    _TestCase(
      query: 'Remain in Light Talking Heads',
      artist: 'Talking Heads',
      title: 'Remain in Light',
      description: 'Talking Heads Remain in Light → correct',
    ),

    // 18. Nusrat Fateh Ali Khan
    _TestCase(
      query: 'Mustt Mustt Nusrat Fateh Ali Khan',
      artist: 'Nusrat Fateh Ali Khan',
      title: 'Mustt Mustt',
      description: 'Nusrat Fateh Ali Khan → correct',
    ),

    // 19. Metallica - Master of Puppets (the KEY case)
    _TestCase(
      query: 'Master of Puppets Metallica',
      artist: 'Metallica',
      title: 'Master of Puppets',
      description: 'Metallica MoP → correct',
    ),

    // 20. King Gizzard - Nonagon Infinity
    _TestCase(
      query: 'Nonagon Infinity King Gizzard',
      artist: 'King Gizzard & the Lizard Wizard',
      title: 'Nonagon Infinity',
      description: 'King Gizzard Nonagon → correct',
    ),
  ];

  print('=' * 80);
  print('SCORING ALGORITHM TEST RESULTS');
  print('=' * 80);

  int pass = 0;
  int fail = 0;

  // Group key scenarios: for each album, check that correct > self-titled
  final pairs = <String, List<_TestCase>>{};
  for (final t in tests) {
    final key = '${t.query}|${t.artist}';
    pairs.putIfAbsent(key, () => []).add(t);
  }

  print('\n--- PAIRWISE COMPARISONS (correct vs self-titled) ---\n');
  for (final entry in pairs.entries) {
    final cases = entry.value;
    if (cases.length == 2) {
      final correct = cases.firstWhere((c) => c.artist != c.title, orElse: () => cases.first);
      final selfTitled = cases.firstWhere((c) => c.artist == c.title, orElse: () => cases.last);

      final correctScore = calculateMatchScore(correct.query, correct.artist, correct.title);
      final selfScore = calculateMatchScore(selfTitled.query, selfTitled.artist, selfTitled.title);

      final ok = correctScore > selfScore;
      if (ok) pass++; else fail++;

      print('${ok ? "PASS" : "FAIL"}: "${correct.query}"');
      print('  ${correct.artist} - ${correct.title}: ${correctScore.toStringAsFixed(3)}');
      print('  ${selfTitled.artist} - ${selfTitled.title}: ${selfScore.toStringAsFixed(3)}');
      print('');
    } else {
      for (final t in cases) {
        final s = calculateMatchScore(t.query, t.artist, t.title);
        print('  ${t.description}: ${s.toStringAsFixed(3)} (${t.artist} - ${t.title})');
      }
      print('');
    }
  }

  print('=' * 80);
  print('RESULTS: $pass passed, $fail failed');
  print('=' * 80);

  // Also simulate the full candidate selection for Metallica
  print('\n--- SIMULATION: Metallica scenario ---');
  print('Query: "Master of Puppets Metallica"');
  final candidates = [
    ('Metallica', 'Master of Puppets'),
    ('Metallica', 'Metallica'),
    ('Metallica', '...And Justice for All'),
    ('Metallica', 'Ride the Lightning'),
    ('Metallica', 'Load'),
  ];
  for (final c in candidates) {
    final s = calculateMatchScore('Master of Puppets Metallica', c.$1, c.$2);
    print('  ${c.$1} - ${c.$2}: ${s.toStringAsFixed(3)}');
  }
  final best = candidates.reduce((a, b) =>
    calculateMatchScore('Master of Puppets Metallica', a.$1, a.$2) >
    calculateMatchScore('Master of Puppets Metallica', b.$1, b.$2) ? a : b);
  print('  WINNER: ${best.$1} - ${best.$2}');

  // Simulate with single-word query "Metallica"
  print('\nQuery: "Metallica"');
  for (final c in candidates) {
    final s = calculateMatchScore('Metallica', c.$1, c.$2);
    print('  ${c.$1} - ${c.$2}: ${s.toStringAsFixed(3)}');
  }
  final best2 = candidates.reduce((a, b) =>
    calculateMatchScore('Metallica', a.$1, a.$2) >
    calculateMatchScore('Metallica', b.$1, b.$2) ? a : b);
  print('  WINNER: ${best2.$1} - ${best2.$2}');
}

class _TestCase {
  final String query;
  final String artist;
  final String title;
  final String description;
  _TestCase({required this.query, required this.artist, required this.title, required this.description});
}
