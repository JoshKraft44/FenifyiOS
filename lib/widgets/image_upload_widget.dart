import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import '../services/image_processing/image_processor.dart';

/// Widget for capturing or selecting chess board images and processing them into FEN notation
class ImageUploadWidget extends StatefulWidget {
  final Function(String) onFenGenerated;
  final VoidCallback? onImageSelected;

  const ImageUploadWidget({
    Key? key,
    required this.onFenGenerated,
    this.onImageSelected,
  }) : super(key: key);

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  final ImageProcessor _imageProcessor = ImageProcessor();
  bool _isProcessing = false;
  io.File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _initializeImageProcessor();
  }

  Future<void> _initializeImageProcessor() async {
    try {
      await _imageProcessor.init();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to initialize image processor: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        setState(() {
          _selectedImage = io.File(image.path);
          _isProcessing = true;
        });

        widget.onImageSelected?.call();

        // Process the image to extract FEN
        final fen = await _imageProcessor.processImageFile(_selectedImage!);

        setState(() {
          _isProcessing = false;
        });

        widget.onFenGenerated(fen);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  /// Debug function to extract individual chess squares for inspection
  Future<void> _debugExtractSquares() async {
    if (_selectedImage != null) {
      try {
        if (kDebugMode) debugPrint('Starting debug square extraction...');
        final squaresPaths =
            await _imageProcessor.extractSquaresForDebugging(_selectedImage!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Extracted ${squaresPaths.length} squares for debugging'),
              backgroundColor: Colors.green.shade400,
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error during debug extraction: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Debug extraction failed: $e'),
              backgroundColor: Colors.orange.shade400,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null) ...[
            // Show selected image
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Processing chess position...'),
              const SizedBox(height: 16),
            ],

            // Debug button
            ElevatedButton.icon(
              onPressed: _debugExtractSquares,
              icon: const Icon(Icons.bug_report),
              label: const Text('Debug: Extract Squares'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade400,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Image selection buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
