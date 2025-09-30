import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import '../edit_position_screen/edit_position_screen.dart';
import '../../widgets/analysis_widgets.dart';
import '../../providers/theme_provider.dart';
import 'controllers/analysis_controller.dart';
import 'widgets/analysis_board_widget.dart';
import 'widgets/analysis_content_widget.dart';
import 'widgets/analysis_status_widget.dart';
import 'dart:ui' as ui;

class AnalysisScreen extends StatefulWidget {
  final String fen;
  const AnalysisScreen({Key? key, required this.fen}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> 
    with WidgetsBindingObserver, TickerProviderStateMixin {
  
  late final AnalysisController _analysisController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Color palette
  static const ui.Color deepNavy = ui.Color(0xFF1a1a2e);
  static const ui.Color cadetGray = ui.Color(0xFF4a5568);
  static const ui.Color seasalt = ui.Color(0xFFF7FAFC);
  static const ui.Color successGreen = ui.Color(0xFF7FB069);
  static const ui.Color warningOrange = ui.Color(0xFFE07A5F);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _analysisController = AnalysisController(
      initialFen: widget.fen,
      onStateChanged: () => setState(() {}),
    );

    _setupAnimations();
    _analysisController.initialize();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _analysisController.pauseAnalysis();
    } else if (state == AppLifecycleState.resumed) {
      _analysisController.resumeAnalysis();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _analysisController.dispose();
    super.dispose();
  }

  void _navigateToEditPosition() async {
    await _analysisController.pauseAnalysis();

    final fenToEdit = _analysisController.isInvalidPosition 
        ? _analysisController.originalFen 
        : _analysisController.currentFen;

    final editedFen = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => EditPositionScreen(fen: fenToEdit)),
    );

    if (editedFen != null && editedFen != fenToEdit) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AnalysisScreen(fen: editedFen)),
      );
    } else if (!_analysisController.isInvalidPosition) {
      await _analysisController.resumeAnalysis();
    }
  }

  void _savePosition() async {
    await _analysisController.savePosition(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final boardSize = screenSize.width;

    // Update arrow colors based on current theme
    _analysisController.updateArrowsForTheme(context);

    return WillPopScope(
      onWillPop: () async {
        // Only allow pop via back button, not swipe gesture
        // Check if this was triggered by a swipe vs button press
        return false; // Block all automatic pops
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: _buildAppBar(),
        body: _buildBody(boardSize),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: context.iconColor,
      elevation: 0,
      systemOverlayStyle: context.isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: context.iconColor),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Analysis',
        style: TextStyle(
          color: context.primaryTextColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Save button
        IconButton(
          icon: Icon(
            Icons.bookmark_add_rounded,
            color: _analysisController.isInvalidPosition 
                ? context.secondaryTextColor.withOpacity(0.5) 
                : context.iconColor,
          ),
          onPressed: _analysisController.isInvalidPosition ? null : _savePosition,
          tooltip: _analysisController.isInvalidPosition ? 'Fix position to save' : 'Save Position',
        ),
        // Arrow toggle button
        if (!_analysisController.isInvalidPosition)
          IconButton(
            icon: Icon(
              _analysisController.showArrows 
                  ? Icons.arrow_forward_rounded 
                  : Icons.arrow_forward_outlined,
              color: _analysisController.showArrows ? successGreen : context.iconColor,
            ),
            onPressed: () => _analysisController.toggleArrows(),
            tooltip: _analysisController.showArrows 
                ? 'Hide best move arrow' 
                : 'Show best move arrow',
          ),
        // Flip button
        IconButton(
          icon: Icon(
            _analysisController.boardFlipped 
                ? Icons.flip_camera_ios_rounded 
                : Icons.flip_camera_ios_outlined,
            color: context.iconColor,
          ),
          onPressed: () => _analysisController.toggleBoardFlip(),
        ),
        // Edit button
        IconButton(
          icon: Icon(
            Icons.edit_rounded,
            color: _analysisController.isInvalidPosition ? warningOrange : context.iconColor,
          ),
          onPressed: _navigateToEditPosition,
          tooltip: _analysisController.isInvalidPosition 
              ? 'Fix invalid position' 
              : 'Edit position',
        ),
      ],
    );
  }

  Widget _buildBody(double boardSize) {
    if (_analysisController.hasError) {
      return AnalysisWidgets.buildErrorWidget(
        lastError: _analysisController.lastError,
        onRestart: () => _analysisController.restartAnalysis(),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Invalid position warning
          if (_analysisController.isInvalidPosition)
            _buildInvalidPositionWarning(),
          
          // Initializing widget
          if (_analysisController.isInitializing)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: context.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            )
          else ...[
            // Turn indicator and depth bar above the board
            if (!_analysisController.isInvalidPosition)
              _buildStatusBar(),
            
            // Chess board 
            AnalysisBoardWidget(
              boardSize: boardSize,
              controller: _analysisController,
            ),
            
            // Evaluation bar directly below board
            if (!_analysisController.isInvalidPosition && _analysisController.principalVariation.isNotEmpty)
              AnalysisWidgets.buildEvaluationBar(
                evaluationScore: _analysisController.evaluationScore,
                isMateScore: _analysisController.isMateScore,
                mateInMoves: _analysisController.mateInMoves,
              ),
            
            // Analysis content
            Expanded(
              child: AnalysisContentWidget(
                controller: _analysisController,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvalidPositionWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warningOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: warningOrange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This position violates chess rules and cannot be analyzed.',
              style: TextStyle(
                color: deepNavy,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return AnalysisStatusWidget(
      position: _analysisController.position!,
      isAnalyzing: _analysisController.isAnalyzing,
      engineReady: _analysisController.engineReady,
      currentDepth: _analysisController.currentDepth,
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.borderColor, width: 1),
        boxShadow: context.isDarkMode ? null : [
          BoxShadow(
            color: context.primaryTextColor.withOpacity(0.1), 
            blurRadius: 20, 
            offset: const Offset(0, -8)
          )
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(
                Icons.first_page_rounded, 
                'Start', 
                _analysisController.currentMoveIndex > 0 && !_analysisController.isInvalidPosition,
                () => _analysisController.goToStart(),
              ),
              _buildNavButton(
                Icons.chevron_left_rounded, 
                'Back', 
                _analysisController.currentMoveIndex > 0 && !_analysisController.isInvalidPosition,
                () => _analysisController.goBackOneMove(),
              ),
              _buildNavButton(
                Icons.chevron_right_rounded, 
                'Forward', 
                _analysisController.currentMoveIndex < _analysisController.gameHistoryLength - 1 && !_analysisController.isInvalidPosition,
                () => _analysisController.goForwardOneMove(),
              ),
              _buildNavButton(
                Icons.last_page_rounded, 
                'End', 
                _analysisController.currentMoveIndex < _analysisController.gameHistoryLength - 1 && !_analysisController.isInvalidPosition,
                () => _analysisController.goToEnd(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String tooltip, bool enabled, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: enabled 
                ? (context.isDarkMode 
                    ? Colors.white.withOpacity(0.1)
                    : context.accentColor.withOpacity(0.1))
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: enabled 
                ? context.primaryTextColor
                : context.secondaryTextColor.withOpacity(0.5),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}