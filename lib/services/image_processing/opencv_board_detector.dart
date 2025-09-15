import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Enhanced chess board detection using OpenCV computer vision library.
class OpenCVBoardDetector {
  /// Detects and crops a chess board from the input image using advanced computer vision techniques.
  /// Ensures the result is properly aligned for the 2D TensorFlow model.
  static Future<Uint8List?> detectAndCropChessboard(Uint8List imageBytes) async {
    try {
      print('[OpenCV] Starting enhanced chess board detection');
      
      // Convert image bytes to OpenCV Mat
      final srcMat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
      if (srcMat.isEmpty) {
        print('[OpenCV] Failed to decode image');
        return null;
      }
      
      print('[OpenCV] Image size: ${srcMat.cols}x${srcMat.rows}');
      
      // Use OpenCV's built-in chessboard corner detection - the industry standard
      final cornersResult = await _detectChessboardCorners(srcMat);
      if (cornersResult != null) {
        print('[OpenCV] Chessboard corners detection successful');
        return _matToBytes(cornersResult);
      }
      
      // Fallback: Smart center crop weighted toward the middle where chess apps put boards
      print('[OpenCV] Using smart center crop for app screenshot');
      return _smartCenterCropForApps(srcMat);
      
    } catch (e) {
      print('[OpenCV] Exception: $e');
      return null; // Return null to use original image
    }
  }
  
  /// Use OpenCV's built-in chessboard corner detection - industry standard approach
  static Future<cv.Mat?> _detectChessboardCorners(cv.Mat srcMat) async {
    try {
      print('[OpenCV] Attempting OpenCV findChessboardCorners detection');
      
      final gray = cv.cvtColor(srcMat, cv.COLOR_BGR2GRAY);
      
      // Standard chessboard is 8x8 squares, so 7x7 internal corners
      // Try multiple common chessboard sizes
      final chessboardSizes = [
        (7, 7),   // Standard 8x8 board
        (6, 6),   // 7x7 board
        (8, 8),   // 9x9 board
        (5, 5),   // 6x6 board
        (9, 9),   // 10x10 board
      ];
      
      for (final size in chessboardSizes) {
        print('[OpenCV] Trying chessboard size: ${size.$1}x${size.$2}');
        
        // Use findChessboardCorners - the standard OpenCV function
        final (found, corners) = cv.findChessboardCorners(gray, size);
        
        if (found && corners.isNotEmpty) {
          print('[OpenCV] Found ${corners.length} corners for ${size.$1}x${size.$2} board');
          
          // Refine corners to sub-pixel accuracy
          final refinedCorners = cv.cornerSubPix(
            gray, 
            corners, 
            (11, 11),        // winSize
            (-1, -1)         // zeroZone  
          );
          
          // Calculate bounding box from corners
          final boundingBox = _calculateBoundingBoxFromCorners(refinedCorners, srcMat);
          if (boundingBox != null) {
            // Extract and resize the chessboard region
            final boardRegion = cv.getRectSubPix(srcMat, 
              (boundingBox.width, boundingBox.height),
              cv.Point2f(boundingBox.x + boundingBox.width / 2, 
                        boundingBox.y + boundingBox.height / 2));
            
            final resized = cv.resize(boardRegion, (512, 512));
            print('[OpenCV] Successfully extracted chessboard using corner detection');
            return resized;
          }
        }
      }
      
      print('[OpenCV] No chessboard corners found with standard detection');
      return null;
      
    } catch (e) {
      print('[OpenCV] Chessboard corners detection error: $e');
      return null;
    }
  }
  
  /// Calculate bounding box from detected chessboard corners
  static cv.Rect? _calculateBoundingBoxFromCorners(cv.VecPoint2f corners, cv.Mat srcMat) {
    if (corners.isEmpty) return null;
    
    // Find min/max x and y coordinates
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (int i = 0; i < corners.length; i++) {
      final point = corners[i];
      minX = minX < point.x ? minX : point.x;
      maxX = maxX > point.x ? maxX : point.x;
      minY = minY < point.y ? minY : point.y;
      maxY = maxY > point.y ? maxY : point.y;
    }
    
    // Add some padding around the detected corners
    final padding = ((maxX - minX + maxY - minY) / 2 * 0.1).round();
    
    final x = (minX - padding).round().clamp(0, srcMat.cols);
    final y = (minY - padding).round().clamp(0, srcMat.rows);
    final width = (maxX - minX + 2 * padding).round().clamp(0, srcMat.cols - x);
    final height = (maxY - minY + 2 * padding).round().clamp(0, srcMat.rows - y);
    
    // Make it square using the larger dimension for better coverage
    final size = width > height ? width : height;
    final centerX = x + width / 2;
    final centerY = y + height / 2;
    
    return cv.Rect(
      (centerX - size / 2).round().clamp(0, srcMat.cols),
      (centerY - size / 2).round().clamp(0, srcMat.rows),
      size.clamp(100, srcMat.cols),
      size.clamp(100, srcMat.rows)
    );
  }
  
  /// Detect chessboard by looking for grid patterns - best for app screenshots
  static Future<cv.Mat?> _detectChessboardGrid(cv.Mat srcMat) async {
    try {
      print('[OpenCV] Attempting grid pattern detection');
      
      final gray = cv.cvtColor(srcMat, cv.COLOR_BGR2GRAY);
      
      // Look for the chessboard pattern in the center 80% of the image
      final centerRegion = _extractCenterRegion(srcMat, 0.8);
      final centerGray = cv.cvtColor(centerRegion, cv.COLOR_BGR2GRAY);
      
      // Detect horizontal and vertical lines that form a grid
      final edges = cv.canny(centerGray, 50, 150);
      final horizontalLines = _detectHorizontalLines(edges);
      final verticalLines = _detectVerticalLines(edges);
      
      print('[OpenCV] Found ${horizontalLines.length} horizontal, ${verticalLines.length} vertical lines in center region');
      
      // A chessboard should have roughly 7-9 lines in each direction (8x8 grid)
      if (horizontalLines.length >= 5 && horizontalLines.length <= 12 && 
          verticalLines.length >= 5 && verticalLines.length <= 12) {
        
        // Find the bounding box of the grid lines
        final gridBounds = _calculateGridBounds(horizontalLines, verticalLines, centerRegion);
        if (gridBounds != null) {
          // Adjust bounds back to original image coordinates
          final adjustedBounds = cv.Rect(
            (gridBounds.x + srcMat.cols * 0.1).round(),
            (gridBounds.y + srcMat.rows * 0.1).round(),
            gridBounds.width,
            gridBounds.height
          );
          
          // Extract and resize the grid region
          final boardRegion = _extractSquareRegion(srcMat, adjustedBounds);
          if (boardRegion != null) {
            print('[OpenCV] Grid detection successful');
            return cv.resize(boardRegion, (512, 512));
          }
        }
      }
      
      return null;
    } catch (e) {
      print('[OpenCV] Grid detection error: $e');
      return null;
    }
  }
  
  /// Extract center region of image for focused analysis
  static cv.Mat _extractCenterRegion(cv.Mat srcMat, double percentage) {
    final centerWidth = (srcMat.cols * percentage).round();
    final centerHeight = (srcMat.rows * percentage).round();
    final startX = ((srcMat.cols - centerWidth) / 2).round();
    final startY = ((srcMat.rows - centerHeight) / 2).round();
    
    return cv.getRectSubPix(srcMat, (centerWidth, centerHeight), 
                           cv.Point2f(startX + centerWidth / 2, startY + centerHeight / 2));
  }
  
  /// Detect horizontal lines in edge image
  static List<cv.Vec4i> _detectHorizontalLines(cv.Mat edges) {
    final lines = cv.HoughLinesP(edges, 1, cv.CV_PI / 180, 50, minLineLength: 50, maxLineGap: 10);
    final horizontalLines = <cv.Vec4i>[];
    
    for (int i = 0; i < lines.rows; i++) {
      final line = lines.row(i);
      final x1 = line.at<int>(0, 0);
      final y1 = line.at<int>(0, 1);
      final x2 = line.at<int>(0, 2);
      final y2 = line.at<int>(0, 3);
      
      final dx = (x1 - x2).abs();
      final dy = (y1 - y2).abs();
      
      // More horizontal than vertical
      if (dx > dy * 2) {
        horizontalLines.add(cv.Vec4i(x1, y1, x2, y2));
      }
    }
    
    return horizontalLines;
  }
  
  /// Detect vertical lines in edge image
  static List<cv.Vec4i> _detectVerticalLines(cv.Mat edges) {
    final lines = cv.HoughLinesP(edges, 1, cv.CV_PI / 180, 50, minLineLength: 50, maxLineGap: 10);
    final verticalLines = <cv.Vec4i>[];
    
    for (int i = 0; i < lines.rows; i++) {
      final line = lines.row(i);
      final x1 = line.at<int>(0, 0);
      final y1 = line.at<int>(0, 1);
      final x2 = line.at<int>(0, 2);
      final y2 = line.at<int>(0, 3);
      
      final dx = (x1 - x2).abs();
      final dy = (y1 - y2).abs();
      
      // More vertical than horizontal
      if (dy > dx * 2) {
        verticalLines.add(cv.Vec4i(x1, y1, x2, y2));
      }
    }
    
    return verticalLines;
  }
  
  /// Calculate bounding box from grid lines
  static cv.Rect? _calculateGridBounds(List<cv.Vec4i> horizontalLines, List<cv.Vec4i> verticalLines, cv.Mat regionMat) {
    if (horizontalLines.isEmpty || verticalLines.isEmpty) return null;
    
    // Get Y positions from horizontal lines
    final yPositions = horizontalLines.map((line) => ((line.val2 + line.val4) / 2).round()).toList();
    yPositions.sort();
    
    // Get X positions from vertical lines
    final xPositions = verticalLines.map((line) => ((line.val1 + line.val3) / 2).round()).toList();
    xPositions.sort();
    
    if (yPositions.length < 2 || xPositions.length < 2) return null;
    
    final minY = yPositions.first;
    final maxY = yPositions.last;
    final minX = xPositions.first;
    final maxX = xPositions.last;
    
    final width = maxX - minX;
    final height = maxY - minY;
    
    // Make it square using the smaller dimension
    final size = width < height ? width : height;
    final centerX = minX + width / 2;
    final centerY = minY + height / 2;
    
    return cv.Rect(
      (centerX - size / 2).round().clamp(0, regionMat.cols),
      (centerY - size / 2).round().clamp(0, regionMat.rows),
      size.clamp(100, regionMat.cols),
      size.clamp(100, regionMat.rows)
    );
  }
  
  /// Extract square region from bounds
  static cv.Mat? _extractSquareRegion(cv.Mat srcMat, cv.Rect bounds) {
    try {
      return cv.getRectSubPix(srcMat, (bounds.width, bounds.height),
                             cv.Point2f(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2));
    } catch (e) {
      print('[OpenCV] Error extracting square region: $e');
      return null;
    }
  }
  
  /// Smart center crop optimized for chess app screenshots
  static Uint8List? _smartCenterCropForApps(cv.Mat srcMat) {
    try {
      final width = srcMat.cols;
      final height = srcMat.rows;
      
      print('[OpenCV] Smart app crop for ${width}x$height image');
      
      // For vertical screenshots, assume board is in the center-upper area
      // Chess apps typically put board in upper 60% of screen, centered horizontally
      final cropWidth = (width * 0.9).round(); // 90% of width
      final cropHeight = cropWidth; // Make it square
      
      // Position slightly above center for typical app layouts
      final centerX = width / 2;
      final centerY = height * 0.45; // 45% from top (slightly above center)
      
      final croppedBoard = cv.getRectSubPix(srcMat, (cropWidth, cropHeight), 
                                           cv.Point2f(centerX, centerY));
      
      final resized = cv.resize(croppedBoard, (512, 512));
      
      print('[OpenCV] Smart app crop applied: ${cropWidth}x$cropHeight at center ($centerX, $centerY)');
      return _matToBytes(resized);
      
    } catch (e) {
      print('[OpenCV] Smart app crop error: $e');
      return null;
    }
  }
  
  /// Contour-based detection using shape analysis - most reliable for chess boards
  static Future<cv.Mat?> _detectChessboardByContours(cv.Mat srcMat) async {
    try {
      print('[OpenCV] Attempting contour-based detection');
      
      // Convert to grayscale
      final gray = cv.cvtColor(srcMat, cv.COLOR_BGR2GRAY);
      
      // Apply Gaussian blur to reduce noise
      final blurred = cv.gaussianBlur(gray, (5, 5), 0);
      
      // Apply adaptive threshold to get binary image
      final binary = cv.adaptiveThreshold(blurred, 255, cv.ADAPTIVE_THRESH_GAUSSIAN_C, cv.THRESH_BINARY, 15, 10);
      
      // Find contours
      final contours = cv.findContours(binary, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
      
      // Find the largest rectangular contour
      double maxArea = 0;
      cv.VecPoint? largestContour;
      
      for (final contour in contours.$1) {
        final area = cv.contourArea(contour);
        if (area > maxArea && area > 10000) { // Minimum area threshold
          // Approximate contour to polygon
          final approx = cv.approxPolyDP(contour, cv.arcLength(contour, true) * 0.02, true);
          
          // Check if it's roughly rectangular (4-8 corners)
          if (approx.length >= 4 && approx.length <= 8) {
            maxArea = area;
            largestContour = approx;
          }
        }
      }
      
      if (largestContour == null) {
        return null;
      }
      
      // Get bounding rect of the largest contour
      final boundingRect = cv.boundingRect(largestContour);
      
      // Ensure minimum size and roughly square aspect ratio
      final aspectRatio = boundingRect.width / boundingRect.height;
      if (boundingRect.width < 200 || boundingRect.height < 200 || 
          aspectRatio < 0.7 || aspectRatio > 1.3) {
        return null;
      }
      
      // Make the crop square by using the minimum dimension
      final minSize = boundingRect.width < boundingRect.height ? boundingRect.width : boundingRect.height;
      final squareSize = (minSize * 0.95).round(); // Slightly smaller to ensure we stay within bounds
      
      // Crop a perfect square from the center of the detected region
      final croppedBoard = cv.getRectSubPix(srcMat, (squareSize, squareSize), 
                                           cv.Point2f(boundingRect.x + boundingRect.width / 2, 
                                                      boundingRect.y + boundingRect.height / 2));
      
      // Always resize to exactly 512x512 for consistent grid alignment
      final resized = cv.resize(croppedBoard, (512, 512));
      
      print('[OpenCV] Contour detection successful - area: $maxArea');
      return resized;
      
    } catch (e) {
      print('[OpenCV] Contour detection error: $e');
      return null;
    }
  }
  
  /// Edge-based detection for finding rectangular regions
  static Future<cv.Mat?> _detectChessboardByEdges(cv.Mat srcMat) async {
    try {
      print('[OpenCV] Attempting edge-based detection');
      
      // Convert to grayscale
      final gray = cv.cvtColor(srcMat, cv.COLOR_BGR2GRAY);
      
      // Apply Gaussian blur
      final blurred = cv.gaussianBlur(gray, (5, 5), 0);
      
      // Detect edges using Canny
      final edges = cv.canny(blurred, 50, 150);
      
      // Find lines using HoughLinesP
      final linesVec = cv.HoughLinesP(edges, 1, cv.CV_PI / 180, 100, minLineLength: 100, maxLineGap: 10);
      
      if (linesVec.rows < 10) {
        print('[OpenCV] Not enough lines detected: ${linesVec.rows}');
        return null;
      }
      
      // Analyze line orientations to find board region
      final horizontalLines = <List<int>>[];
      final verticalLines = <List<int>>[];
      
      for (int i = 0; i < linesVec.rows; i++) {
        final line = linesVec.row(i);
        final x1 = line.at<int>(0, 0);
        final y1 = line.at<int>(0, 1);
        final x2 = line.at<int>(0, 2);
        final y2 = line.at<int>(0, 3);
        
        final dx = (x1 - x2).abs();
        final dy = (y1 - y2).abs();
        
        if (dx > dy * 2) {
          // More horizontal than vertical
          horizontalLines.add([x1, y1, x2, y2]);
        } else if (dy > dx * 2) {
          // More vertical than horizontal
          verticalLines.add([x1, y1, x2, y2]);
        }
      }
      
      print('[OpenCV] Found ${horizontalLines.length} horizontal, ${verticalLines.length} vertical lines');
      
      if (horizontalLines.length < 3 || verticalLines.length < 3) {
        return null;
      }
      
      // Find bounding box from line positions
      final bounds = _findBoundsFromLines(horizontalLines, verticalLines, srcMat);
      if (bounds == null) return null;
      
      // Make the crop square and resize to 512x512
      final squareSize = bounds.width < bounds.height ? bounds.width : bounds.height;
      final croppedBoard = cv.getRectSubPix(srcMat, (squareSize, squareSize),
                                           cv.Point2f(bounds.x + squareSize / 2, bounds.y + squareSize / 2));
      
      // Always resize to exactly 512x512 for consistent grid alignment  
      final resized = cv.resize(croppedBoard, (512, 512));
      
      print('[OpenCV] Edge detection successful');
      return resized;
      
    } catch (e) {
      print('[OpenCV] Edge detection error: $e');
      return null;
    }
  }
  
  /// Find bounds from detected lines
  static cv.Rect? _findBoundsFromLines(List<List<int>> horizontalLines, List<List<int>> verticalLines, cv.Mat srcMat) {
    try {
      // Get Y positions from horizontal lines
      final yPositions = horizontalLines.map((line) => ((line[1] + line[3]) / 2).round()).toList();
      yPositions.sort();
      
      // Get X positions from vertical lines  
      final xPositions = verticalLines.map((line) => ((line[0] + line[2]) / 2).round()).toList();
      xPositions.sort();
      
      if (yPositions.length < 2 || xPositions.length < 2) return null;
      
      // Use outer bounds with some padding
      final minY = yPositions.first;
      final maxY = yPositions.last;
      final minX = xPositions.first;
      final maxX = xPositions.last;
      
      final padding = ((srcMat.cols + srcMat.rows) / 2 * 0.05).round();
      final left = (minX - padding).clamp(0, srcMat.cols);
      final top = (minY - padding).clamp(0, srcMat.rows);
      final right = (maxX + padding).clamp(0, srcMat.cols);
      final bottom = (maxY + padding).clamp(0, srcMat.rows);
      
      final width = right - left;
      final height = bottom - top;
      
      // Ensure roughly square and minimum size
      final size = width < height ? width : height;
      if (size < 200) return null;
      
      return cv.Rect(left, top, size, size);
      
    } catch (e) {
      print('[OpenCV] Bounds calculation error: $e');
      return null;
    }
  }
  
  /// Intelligent center crop using OpenCV
  static Uint8List? _intelligentCenterCrop(cv.Mat srcMat) {
    try {
      final width = srcMat.cols;
      final height = srcMat.rows;
      final minDim = width < height ? width : height;
      
      // Take 85% to avoid borders
      final cropSize = (minDim * 0.85).round();
      
      final centerX = width / 2;
      final centerY = height / 2;
      
      final croppedBoard = cv.getRectSubPix(srcMat, (cropSize, cropSize), 
                                           cv.Point2f(centerX, centerY));
      
      // Always resize to exactly 512x512 for consistent grid alignment
      final resized = cv.resize(croppedBoard, (512, 512));
      
      return _matToBytes(resized);
      
    } catch (e) {
      print('[OpenCV] Intelligent crop error: $e');
      return null;
    }
  }
  
  /// Convert OpenCV Mat to bytes
  static Uint8List _matToBytes(cv.Mat mat) {
    return cv.imencode('.png', mat).$2;
  }
  
  /// Simple center crop fallback
  static Uint8List? _centerCropSquare(Uint8List imageBytes) {
    try {
      return imageBytes; // Return original as final fallback
    } catch (e) {
      print('[OpenCV] Center crop error: $e');
      return null;
    }
  }
}