import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'utils/debug_helper.dart';

// Application entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Print debug folder path in debug mode
  if (kDebugMode) {
    await DebugHelper.printDebugPath();
  }

  runApp(const ChessAnalyzerApp());
}

class ChessAnalyzerApp extends StatelessWidget {
  const ChessAnalyzerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Fenify',
            theme: themeProvider.themeData,
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}