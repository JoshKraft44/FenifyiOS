import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../providers/theme_provider.dart';
import '../screens/analysis_screen/analysis_screen.dart';
import '../screens/image_processing_screen.dart';
import '../screens/saved_positions_screen/saved_positions_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/pro_screen.dart';
import '../services/image_processing/image_processor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  io.File? _image;
  bool _isProcessing = false;
  final TextEditingController _fenController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImageProcessor _imageProcessor = ImageProcessor();
  int _selectedIndex = 0;
  
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  
  
  // Sample positions for quick access
  final Map<String, String> _samplePositions = {
    'Starting Position': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    'Ruy Lopez': 'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
    'Sicilian Defense': 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
    'Queen\'s Gambit': 'rnbqkbnr/ppp1pppp/8/3p4/2PP4/8/PP2PPPP/RNBQKBNR b KQkq - 0 2',
    'King\'s Indian': 'rnbqkb1r/pppppp1p/5np1/8/2PP4/8/PP2PPPP/RNBQKBNR w KQkq - 0 3',
  };

  @override
  void initState() {
    super.initState();
    _fenController.text = _samplePositions['Starting Position']!;
    _initializeImageProcessor();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );
    
    _fadeController.forward();
  }

  Future<void> _initializeImageProcessor() async {
    try {
      if (kDebugMode) debugPrint('HomeScreen: Starting image processors initialization...');
      // Export debug crops to your Mac while developing
      // Update to match your local server if needed
      if (kDebugMode) {
        // Update to Mac current LAN IP
        // ipconfig getifaddr en0
        ImageProcessor.debugExportBaseUrl = 'http://192.168.2.237:8787';
      }
      
      // Initialize 2D image processor
      await _imageProcessor.init();
      if (kDebugMode) debugPrint('HomeScreen: 2D image processor initialized successfully');
      
      
      if (kDebugMode) debugPrint('HomeScreen: Image processors initialization completed');
    } catch (e) {
      if (kDebugMode) debugPrint('HomeScreen: Failed to initialize image processors: $e');
    }
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _fenController.dispose();
    super.dispose();
  }

  void _navigateToAnalysis(String fen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisScreen(fen: fen),
      ),
    );
  }
  
  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.seasalt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.cadetGray.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Upload Chess Position',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepNavy,
                  ),
                ),
              ),
              // Custom upload widget that only shows gallery option
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      _pickFromGallery();
                    },
                    icon: Icon(Icons.photo_library_rounded, color: AppColors.deepNavy),
                    label: Text(
                      'Choose from Gallery',
                      style: TextStyle(
                        color: AppColors.deepNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.columbiaBlue,
                      foregroundColor: AppColors.deepNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // Use io.File explicitly to avoid dartchess File conflict
        final imageFile = io.File(image.path);

        // Navigate to image processing screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ImageProcessingScreen(imageFile: imageFile),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showManualEntry() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: context.borderColor, width: 1),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.secondaryTextColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Manual Entry',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: context.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter FEN notation to analyze a position',
                        style: TextStyle(
                          fontSize: 16,
                          color: context.secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // FEN input field
                      TextFormField(
                        controller: _fenController,
                        style: TextStyle(color: context.primaryTextColor),
                        decoration: InputDecoration(
                          labelText: 'FEN String',
                          labelStyle: TextStyle(color: context.secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.columbiaBlue, width: 2),
                          ),
                          prefixIcon: Icon(Icons.edit_note, color: context.secondaryTextColor),
                          hintText: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                          hintStyle: TextStyle(color: context.secondaryTextColor.withOpacity(0.6)),
                          filled: true,
                          fillColor: context.surfaceColor,
                        ),
                        maxLines: 3,
                        validator: _validateFEN,
                      ),
                      const SizedBox(height: 32),
                      
                      // Sample positions
                      Text(
                        'Quick Positions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: context.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...(_samplePositions.entries.map((entry) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _fenController.text = entry.value;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: ListTile(
                                title: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: context.primaryTextColor,
                                  ),
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.columbiaBlue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.grid_3x3, color: context.primaryTextColor, size: 20),
                                ),
                                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: context.secondaryTextColor),
                              ),
                            ),
                          ),
                        ),
                      )),
                      
                      const SizedBox(height: 32),
                      
                      // Analyze button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pop(context);
                              _navigateToAnalysis(_fenController.text);
                            }
                          },
                          icon: const Icon(Icons.analytics),
                          label: const Text('Analyze Position'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.columbiaBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Navigate to saved positions screen
  void _showSavedPositions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedPositionsScreen(),
      ),
    );
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    switch (index) {
      case 0:
        // Already on home screen, do nothing
        break;
      case 1:
        _showSavedPositions();
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProScreen(),
          ),
        );
        break;
    }
    
    // Reset selected index to home after navigation
    if (index != 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
    }
  }
  
  String? _validateFEN(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a FEN string';
    }
    
    if (!value.contains('/')) {
      return 'Invalid FEN: should contain / characters';
    }
    
    if (!value.contains(' ')) {
      return 'Invalid FEN: missing space separators';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Modern Header
                      _buildModernHeader(),

                      const Spacer(flex: 2),

                      // Main Action Section
                      _buildMainActionSection(),

                      const Spacer(flex: 1),

                      // Quick Actions
                      _buildQuickActions(),

                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
              
              // Modern Bottom Navigation
              _buildModernBottomNav(),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          // Modern Logo with subtle animation
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: context.isDarkMode
                          ? [
                              AppColors.columbiaBlue.withOpacity(0.3),
                              AppColors.lightBlue.withOpacity(0.1),
                            ]
                          : [
                              Colors.white.withOpacity(0.9),
                              Colors.white.withOpacity(0.7),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.borderColor,
                      width: 1,
                    ),
                  ),
                  child: ColorFiltered(
                    colorFilter: context.isDarkMode
                        ? const ColorFilter.matrix([
                            -1,  0,  0, 0, 255,
                             0, -1,  0, 0, 255,
                             0,  0, -1, 0, 255,
                             0,  0,  0, 1,   0,
                          ])
                        : const ColorFilter.matrix([
                             1, 0, 0, 0, 0,
                             0, 1, 0, 0, 0,
                             0, 0, 1, 0, 0,
                             0, 0, 0, 1, 0,
                          ]),
                    child: Image.asset(
                      'assets/images/icon2.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Modern Title
          Text(
            'Fenify',
            style: TextStyle(
              fontSize: context.isDarkMode ? 42 : 36,
              fontWeight: context.isDarkMode ? FontWeight.w300 : FontWeight.w700,
              color: context.primaryTextColor,
              letterSpacing: context.isDarkMode ? 2 : 0.5,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'AI Chess Analysis',
            style: TextStyle(
              fontSize: 16,
              color: context.secondaryTextColor,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionSection() {
    return Column(
      children: [
        // Main Scan Button
        GestureDetector(
          onTap: _showScanOptions,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.columbiaBlue.withOpacity(0.15),
                  AppColors.lightBlue.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.borderColor,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : AppColors.lightBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 24,
                    color: context.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scan Position',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Camera • Gallery',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                Icons.edit_note_rounded,
                'Manual Entry',
                'Enter FEN notation',
                _showManualEntry,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                Icons.history_rounded,
                'Recent',
                'View saved positions',
                _showSavedPositions,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.borderColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : AppColors.lightBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: context.primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.primaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: context.secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode 
          ? Colors.white.withOpacity(0.1)
          : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.borderColor,
          width: 1,
        ),
        boxShadow: context.isDarkMode 
          ? null
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildModernNavItem(Icons.home_rounded, 'Home', 0),
          _buildModernNavItem(Icons.bookmark_rounded, 'Saved', 1),
          _buildModernNavItem(Icons.settings_rounded, 'Settings', 2),
          _buildModernNavItem(Icons.star_rounded, 'Pro', 3),
        ],
      ),
    );
  }

  Widget _buildModernNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? (context.isDarkMode 
                ? Colors.white.withOpacity(0.15)
                : AppColors.columbiaBlue.withOpacity(0.15))
            : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected 
                ? (context.isDarkMode ? Colors.white : AppColors.columbiaBlue)
                : (context.isDarkMode 
                    ? Colors.white.withOpacity(0.6) 
                    : AppColors.cadetGray),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected 
                  ? (context.isDarkMode ? Colors.white : AppColors.columbiaBlue)
                  : (context.isDarkMode 
                      ? Colors.white.withOpacity(0.6) 
                      : AppColors.cadetGray),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildScanOptionsModal(),
    );
  }

  Widget _buildScanOptionsModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: context.backgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: context.borderColor, width: 1),
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.secondaryTextColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    'Scan Chess Position',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.primaryTextColor,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  Text(
                    'Choose your scanning method',
                    style: TextStyle(
                      fontSize: 16,
                      color: context.secondaryTextColor,
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Input Method Options  
                  _buildInputMethodSection(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildInputMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Input Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.primaryTextColor.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 10),
        _buildInputMethodCard(
          Icons.camera_alt_rounded,
          'Take Photo',
          'Capture with camera',
          () => _handleInputMethod('camera'),
        ),
        const SizedBox(height: 8),
        _buildInputMethodCard(
          Icons.photo_library_rounded,
          'Upload Image',
          'Choose from gallery',
          () => _handleInputMethod('gallery'),
        ),
      ],
    );
  }


  Widget _buildInputMethodCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.columbiaBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: context.isDarkMode ? Colors.white : AppColors.deepNavy,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: context.secondaryTextColor.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }


  void _handleInputMethod(String method) {
    Navigator.pop(context);
    HapticFeedback.lightImpact();
    
    if (method == 'camera') {
      // TODO: Implement camera capture
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera functionality coming soon'),
          backgroundColor: AppColors.columbiaBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _pickFromGallery();
    }
  }
}
