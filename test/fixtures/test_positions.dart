// test/fixtures/test_positions.dart
class TestPositions {
  static const String startingPosition = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  static const String englishOpening = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
  static const String sicilianDefense = 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2';
  static const String kingsGambit = 'rnbqkbnr/pppp1ppp/8/4p3/4PP2/8/PPPP2PP/RNBQKBNR b KQkq f3 0 2';
  static const String endgamePosition = '8/8/8/8/8/3k4/3P4/3K4 w - - 0 1';
  static const String mateInOne = 'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2';
  
  // Invalid positions for testing error handling
  static const String invalidNoKings = 'rnbq1bnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQ1BNR w KQkq - 0 1';
  static const String invalidMultipleKings = 'rnbqkknr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  static const String invalidPawnOnFirstRank = 'pnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  static const String invalidAdjacentKings = '8/8/8/8/3kK3/8/8/8 w - - 0 1';
  
  static List<String> getValidPositions() {
    return [
      startingPosition,
      englishOpening,
      sicilianDefense,
      kingsGambit,
      endgamePosition,
      mateInOne,
    ];
  }
  
  static List<String> getInvalidPositions() {
    return [
      invalidNoKings,
      invalidMultipleKings,
      invalidPawnOnFirstRank,
      invalidAdjacentKings,
    ];
  }
  
  static List<String> generateTestFens() {
    return [
      // Opening positions
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2',
      
      // Middle game positions
      'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 4 4',
      'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 6 6',
      
      // Endgame positions
      '8/8/8/8/8/3k4/3P4/3K4 w - - 0 1',
      '8/8/8/8/8/8/4K3/3QK3 w - - 0 1',
      
      // Special positions
      'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1', // Castling available
      'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R4RK1 b kq - 0 1',   // After white castles
    ];
  }
}