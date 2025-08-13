import 'package:flutter/material.dart';
import '../utils/fen_utils.dart';

/// Text field widget for editing and validating FEN notation with real-time feedback
class FenEditorWidget extends StatefulWidget {
  final String initialFen;
  final Function(String) onFenChanged;

  const FenEditorWidget({
    Key? key,
    required this.initialFen,
    required this.onFenChanged,
  }) : super(key: key);

  @override
  _FenEditorWidgetState createState() => _FenEditorWidgetState();
}

class _FenEditorWidgetState extends State<FenEditorWidget> {
  late TextEditingController _controller;
  bool _isValid = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialFen);
    _validateFen(widget.initialFen);
  }

  void _validateFen(String fen) {
    if (fen.trim().isEmpty) {
      setState(() {
        _isValid = false;
        _errorMessage = 'FEN cannot be empty';
      });
      return;
    }

    try {
      final isValid = FenUtils.validateFen(fen);
      setState(() {
        _isValid = isValid;
        _errorMessage = isValid ? '' : 'Invalid FEN notation';
      });
    } catch (e) {
      setState(() {
        _isValid = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FEN Notation',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Enter FEN notation',
            errorText: _isValid ? null : _errorMessage,
            suffixIcon: IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                if (_isValid) {
                  widget.onFenChanged(_controller.text);
                  FocusScope.of(context).unfocus();
                }
              },
            ),
          ),
          onChanged: (value) {
            _validateFen(value);
          },
          onSubmitted: (value) {
            if (_isValid) {
              widget.onFenChanged(value);
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () {
                final fen = FenUtils.getInitialPosition();
                _controller.text = fen;
                _validateFen(fen);
                widget.onFenChanged(fen);
              },
              child: const Text('Reset to Initial'),
            ),
            OutlinedButton(
              onPressed: _isValid
                  ? () {
                      widget.onFenChanged(_controller.text);
                      FocusScope.of(context).unfocus();
                    }
                  : null,
              child: const Text('Apply'),
            ),
          ],
        ),
      ],
    );
  }
}
