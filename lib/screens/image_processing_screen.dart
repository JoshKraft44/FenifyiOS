import 'package:flutter/material.dart';
import 'dart:io';
import '../providers/theme_provider.dart';
import '../services/image_processing/image_processor.dart';
import 'analysis_screen/analysis_screen.dart';

class ImageProcessingScreen extends StatefulWidget {
  final File imageFile;

  const ImageProcessingScreen({
    Key? key,
    required this.imageFile,
  }) : super(key: key);

  @override
  State<ImageProcessingScreen> createState() => _ImageProcessingScreenState();
}

class _ImageProcessingScreenState extends State<ImageProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _startImageProcessing();
  }

  Future<void> _startImageProcessing() async {
    try {
      final imageProcessor = ImageProcessor();
      final result = await imageProcessor.processImageFile(widget.imageFile);

      if (result != null && result.isNotEmpty) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AnalysisScreen(fen: result),
            ),
          );
        }
      } else {
        if (mounted) {
          _showError('Could not detect a valid chess position in this image.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error processing image: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Processing Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Center(
        child: CircularProgressIndicator(
          color: context.isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}