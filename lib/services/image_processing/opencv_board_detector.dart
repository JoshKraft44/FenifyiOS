import 'dart:typed_data';
import 'dart:math' as math;
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'debug_exporter.dart';

/// Represents a line in Hough space (rho, theta parameterization)
/// Used for robust line intersection calculations
class Line {
  final double rho;
  final double theta;
  late final double cosFactor;
  late final double sinFactor;
  late final (double, double) center;

  Line(this.rho, this.theta) {
    cosFactor = math.cos(theta);
    sinFactor = math.sin(theta);
    center = (cosFactor * rho, sinFactor * rho);
  }

  (double, double) getCenter() => center;
  double getRho() => rho;
  double getTheta() => theta;

  /// Get line segment endpoints for drawing
  (cv.Point, cv.Point) getSegment(double lenLeft, double lenRight) {
    final (x0, y0) = center;
    final x1 = (x0 + lenRight * (-sinFactor)).round();
    final y1 = (y0 + lenRight * cosFactor).round();
    final x2 = (x0 - lenLeft * (-sinFactor)).round();
    final y2 = (y0 - lenLeft * cosFactor).round();
    return (cv.Point(x1, y1), cv.Point(x2, y2));
  }

  bool isHorizontal({double thresholdAngle = math.pi / 4}) {
    return math.sin(theta).abs() > math.cos(thresholdAngle);
  }

  bool isVertical({double thresholdAngle = math.pi / 4}) {
    return math.cos(theta).abs() > math.cos(thresholdAngle);
  }

  /// Calculate intersection point with another line
  (double, double)? intersect(Line other) {
    final ct1 = math.cos(theta);
    final st1 = math.sin(theta);
    final ct2 = math.cos(other.theta);
    final st2 = math.sin(other.theta);
    final d = ct1 * st2 - st1 * ct2;

    if (d.abs() < 1e-10) return null; // Parallel lines

    final x = (st2 * rho - st1 * other.rho) / d;
    final y = (-ct2 * rho + ct1 * other.rho) / d;
    return (x, y);
  }

  void draw(cv.Mat image, cv.Scalar color, {int thickness = 2}) {
    final (p1, p2) = getSegment(1000, 1000);
    cv.line(image, p1, p2, color, thickness: thickness);
  }

  @override
  String toString() => '(theta: ${(theta * 180 / math.pi).toStringAsFixed(2)}°, rho: ${rho.toStringAsFixed(0)})';
}

/// Partition lines into horizontal and vertical sets, sorted by position
(List<Line>, List<Line>) partitionLines(List<Line> lines) {
  final horizontal = lines.where((l) => l.isHorizontal()).toList();
  final vertical = lines.where((l) => l.isVertical()).toList();

  // Sort horizontal by y-position (center.y)
  horizontal.sort((a, b) => a.center.$2.compareTo(b.center.$2));

  // Sort vertical by x-position (center.x)
  vertical.sort((a, b) => a.center.$1.compareTo(b.center.$1));

  return (horizontal, vertical);
}

/// Filter out lines that are too close together (keeps middle line of cluster)
List<Line> filterCloseLines(List<Line> lines, {required bool horizontal, required double threshold}) {
  if (lines.isEmpty) return [];

  final result = <Line>[];
  int i = 0;

  while (i < lines.length) {
    final startIdx = i;
    final startPos = horizontal ? lines[i].center.$2 : lines[i].center.$1;

    // Find all lines within threshold
    while (i < lines.length) {
      final currentPos = horizontal ? lines[i].center.$2 : lines[i].center.$1;
      if ((currentPos - startPos).abs() >= threshold) break;
      i++;
    }

    // Take middle line from cluster
    final midIdx = startIdx + ((i - startIdx) ~/ 2);
    result.add(lines[midIdx]);
  }

  return result;
}

/// Get perspective transform points from a contour by finding the bounding rectangle
/// Simplified version that uses the contour's bounding polygon
(cv.Point, cv.Point, cv.Point, cv.Point)? getPerspectiveFromContour(cv.VecPoint contour) {
  try {
    // Approximate the contour to a polygon
    final epsilon = cv.arcLength(contour, true) * 0.02;
    final approx = cv.approxPolyDP(contour, epsilon, true);

    // Look for 4-6 vertices (roughly rectangular)
    if (approx.length >= 4 && approx.length <= 6) {
      final rect = cv.boundingRect(contour);

      // Return the 4 corners of the bounding rectangle
      return (
        cv.Point(rect.x, rect.y),
        cv.Point(rect.x + rect.width, rect.y),
        cv.Point(rect.x + rect.width, rect.y + rect.height),
        cv.Point(rect.x, rect.y + rect.height),
      );
    }

    return null;
  } catch (e) {
    print('[OpenCV] getPerspectiveFromContour error: $e');
    return null;
  }
}

/// Extract and warp a perspective-transformed region from an image
/// Simplified version using ROI extraction
cv.Mat? extractPerspective(
  cv.Mat image,
  (cv.Point, cv.Point, cv.Point, cv.Point)? perspective,
  int width,
  int height,
) {
  try {
    if (perspective == null) {
      // No perspective provided, just resize whole image
      return cv.resize(image, (width, height));
    }

    // Extract bounding rectangle from perspective points
    final (p1, p2, p3, p4) = perspective;

    // Find min/max x and y coordinates
    final minX = [p1.x, p2.x, p3.x, p4.x].reduce(math.min).clamp(0, image.cols);
    final maxX = [p1.x, p2.x, p3.x, p4.x].reduce(math.max).clamp(0, image.cols);
    final minY = [p1.y, p2.y, p3.y, p4.y].reduce(math.min).clamp(0, image.rows);
    final maxY = [p1.y, p2.y, p3.y, p4.y].reduce(math.max).clamp(0, image.rows);

    final rect = cv.Rect(minX, minY, maxX - minX, maxY - minY);

    // Extract ROI and resize
    final roi = image.region(rect);
    return cv.resize(roi, (width, height));
  } catch (e) {
    print('[OpenCV] extractPerspective error: $e');
    return null;
  }
}

/// Extract grid lines from a board image
/// Returns (horizontal, vertical) line lists or null if grid not found
(List<Line>, List<Line>)? extractGrid(
  cv.Mat image, {
  int nVertical = 9,
  int nHorizontal = 9,
  int threshold1 = 50,
  int threshold2 = 150,
  int apertureSize = 3,
  int houghThresholdStep = 20,
  int houghThresholdMin = 50,
  int houghThresholdMax = 150,
}) {
  try {
    final h = image.rows;
    final w = image.cols;
    final closeThresholdV = (w / nVertical) / 4;
    final closeThresholdH = (h / nHorizontal) / 4;

    final gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY);
    final (_, bw) = cv.threshold(gray, 128, 255, cv.THRESH_BINARY | cv.THRESH_OTSU);
    final edges = cv.canny(bw, threshold1.toDouble(), threshold2.toDouble(), apertureSize: apertureSize);

    for (int i = 0; i < (houghThresholdMax - houghThresholdMin + 1) ~/ houghThresholdStep; i++) {
      final threshold = houghThresholdMax - (houghThresholdStep * i);
      final linesRaw = cv.HoughLines(edges, 1, math.pi / 180, threshold);

      if (linesRaw.isEmpty) continue;

      final lines = <Line>[];
      for (int j = 0; j < linesRaw.rows; j++) {
        final row = linesRaw.row(j);
        final rho = row.at<double>(0, 0);
        final theta = row.at<double>(0, 1);
        lines.add(Line(rho, theta));
      }

      final (horizontal, vertical) = partitionLines(lines);
      final filteredV = filterCloseLines(vertical, horizontal: false, threshold: closeThresholdV);
      final filteredH = filterCloseLines(horizontal, horizontal: true, threshold: closeThresholdH);

      if (filteredV.length >= nVertical && filteredH.length >= nHorizontal) {
        return (filteredH, filteredV);
      }
    }

    return null;
  } catch (e) {
    print('[OpenCV] extractGrid error: $e');
    return null;
  }
}

/// Extract 64 individual tile images from a board using grid lines
/// Returns list of ((x, y), tileImage) tuples
List<((int, int), cv.Mat)> extractTiles(
  cv.Mat image,
  (List<Line>, List<Line>) grid,
  int tileWidth,
  int tileHeight,
) {
  final result = <((int, int), cv.Mat)>[];
  final (horizontal, vertical) = grid;

  try {
    for (int x = 0; x < 8; x++) {
      final v1 = vertical[x];
      final v2 = vertical[x + 1];

      for (int y = 0; y < 8; y++) {
        final h1 = horizontal[y];
        final h2 = horizontal[y + 1];

        // Calculate 4 corners of this tile
        final topLeft = h1.intersect(v1);
        final topRight = h1.intersect(v2);
        final bottomRight = h2.intersect(v2);
        final bottomLeft = h2.intersect(v1);

        if (topLeft != null && topRight != null && bottomRight != null && bottomLeft != null) {
          final perspective = (
            cv.Point(topLeft.$1.round(), topLeft.$2.round()),
            cv.Point(topRight.$1.round(), topRight.$2.round()),
            cv.Point(bottomRight.$1.round(), bottomRight.$2.round()),
            cv.Point(bottomLeft.$1.round(), bottomLeft.$2.round()),
          );

          final tile = extractPerspective(image, perspective, tileWidth, tileHeight);
          if (tile != null) {
            result.add(((x, y), tile));
          }
        }
      }
    }
  } catch (e) {
    print('[OpenCV] extractTiles error: $e');
  }

  return result;
}

/// Filter contours based on size, shape, and hierarchy
/// Returns list of valid contour indices
List<int> filterContoursByHierarchy(
  cv.Mat image,
  cv.Contours contours,
  cv.VecVec4i hierarchy, {
  double minRatioBounding = 0.6,
  double minAreaPercentage = 0.01,
  double maxAreaPercentage = 0.40,
}) {
  final result = <int>[];
  final imageArea = image.rows * image.cols;

  for (int i = 0; i < contours.length; i++) {
    final contour = contours[i];

    // Check hierarchy - only top-level contours (no parent)
    if (hierarchy.isNotEmpty && i < hierarchy.length) {
      final hierarchyVec = hierarchy[i];
      // Vec4i has: [next, previous, first_child, parent]
      // Skip if this contour has a child (not a leaf)
      final hasChild = hierarchyVec.val3 != -1;
      if (hasChild) continue;
    }

    // Check bounding box ratio
    final rect = cv.boundingRect(contour);
    final boundingArea = rect.width * rect.height;
    final contourArea = cv.contourArea(contour);

    if (boundingArea == 0) continue;
    final ratioBounding = contourArea / boundingArea;
    if (ratioBounding < minRatioBounding) continue;

    // Check area percentage
    final areaRatio = contourArea / imageArea;
    if (areaRatio < minAreaPercentage || areaRatio > maxAreaPercentage) continue;

    result.add(i);
  }

  return result;
}

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
      
      // Try multiple detection strategies, from most robust to fallback

      // Strategy 1: Python pipeline approach - contour + perspective + grid extraction
      print('[OpenCV] Trying Strategy 1: Contour-based perspective detection');
      final strategy1Result = await _detectUsingContourPerspective(srcMat);
      if (strategy1Result != null) {
        print('[OpenCV] Strategy 1 successful');
        return _finalizeDetection(srcMat, strategy1Result, 'strategy1');
      }

      // Strategy 2: Current approach - largest square detection
      print('[OpenCV] Trying Strategy 2: Largest square detection');
      final (squareResult, detectedBounds) = await _detectLargestSquareWithBounds(srcMat);
      if (squareResult != null && detectedBounds != null) {
        print('[OpenCV] Strategy 2 successful');
        return _finalizeDetection(srcMat, squareResult, 'strategy2', bounds: detectedBounds);
      }

      print('[OpenCV] No 8x8 board detected with any strategy; returning null');
      return null;
      
    } catch (e) {
      print('[OpenCV] Exception: $e');
      return null; // Return null to use original image
    }
  }

  /// Strategy 1: Detect board using contour-based perspective detection (Python pipeline approach)
  static Future<cv.Mat?> _detectUsingContourPerspective(cv.Mat srcMat) async {
    try {
      // Convert to grayscale and threshold
      final gray = cv.cvtColor(srcMat, cv.COLOR_BGR2GRAY);
      final (_, bw) = cv.threshold(gray, 128, 255, cv.THRESH_BINARY | cv.THRESH_OTSU);

      // Find contours - try multiple methods
      final (contours, hierarchy) = cv.findContours(bw, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

      if (contours.isEmpty) {
        print('[OpenCV] Strategy 1: No contours found');
        return null;
      }

      print('[OpenCV] Strategy 1: Found ${contours.length} contours, filtering...');

      // IMPROVED FILTERING: Very lenient for real-world chess boards
      final validIndices = <int>[];
      final imageArea = srcMat.rows * srcMat.cols;

      for (int i = 0; i < contours.length; i++) {
        final contour = contours[i];
        final area = cv.contourArea(contour);
        final areaRatio = area / imageArea;

        // Accept very wide range: 3% to 98% of image
        // (boards can be small in frame or fill entire image)
        if (areaRatio >= 0.03 && areaRatio <= 0.98) {
          final rect = cv.boundingRect(contour);
          final aspectRatio = rect.width / rect.height.toDouble();

          // Very lenient aspect ratio for chess boards (0.6 to 1.6)
          if (aspectRatio >= 0.6 && aspectRatio <= 1.6) {
            validIndices.add(i);
          }
        }
      }

      print('[OpenCV] Strategy 1: Found ${validIndices.length} valid square-ish contours');

      // Sort by area (largest first) - boards are usually prominent
      validIndices.sort((a, b) {
        final areaA = cv.contourArea(contours[a]);
        final areaB = cv.contourArea(contours[b]);
        return areaB.compareTo(areaA);
      });

      // Try all valid candidates thoroughly
      for (final idx in validIndices) {
        final contour = contours[idx];
        final area = cv.contourArea(contour);
        final areaRatio = area / imageArea;

        print('[OpenCV] Strategy 1: Trying contour $idx (area: ${(areaRatio * 100).toStringAsFixed(1)}%)');

        // Get perspective transform from contour
        final perspective = getPerspectiveFromContour(contour);
        if (perspective == null) {
          print('[OpenCV] Strategy 1: No perspective for contour $idx');
          continue;
        }

        // Extract the board using perspective transform
        final board = extractPerspective(srcMat, perspective, 512, 512);
        if (board == null) {
          print('[OpenCV] Strategy 1: Extract failed for contour $idx');
          continue;
        }

        // Validate: Check if it looks like a chess board
        if (_quickBoardValidation(board)) {
          print('[OpenCV] Strategy 1: ✓ Valid board detected at contour $idx');
          return board;
        } else {
          print('[OpenCV] Strategy 1: Board validation failed for contour $idx');
        }
      }

      print('[OpenCV] Strategy 1: No valid board found after trying ${validIndices.length} candidates');
      return null;
    } catch (e) {
      print('[OpenCV] Strategy 1 error: $e');
      return null;
    }
  }

  /// Quick validation - checks if extracted region looks like a chess board
  static bool _quickBoardValidation(cv.Mat board) {
    try {
      // 1. Check aspect ratio (must be square-ish)
      final aspect = board.cols / board.rows;
      if (aspect < 0.85 || aspect > 1.15) {
        print('[OpenCV] Validation failed: aspect ratio $aspect');
        return false;
      }

      // 2. Check for reasonable contrast (chess boards have alternating light/dark squares)
      final gray = cv.cvtColor(board, cv.COLOR_BGR2GRAY);

      // Calculate standard deviation of pixel intensities
      final (mean, stdDev) = cv.meanStdDev(gray);
      final std = stdDev.val1; // Get first channel stddev

      // Chess boards should have good contrast (stddev > 25)
      // Lower threshold for varied lighting conditions
      if (std < 25) {
        print('[OpenCV] Validation failed: low contrast (std: ${std.toStringAsFixed(1)})');
        return false;
      }

      print('[OpenCV] Validation passed: aspect=${aspect.toStringAsFixed(2)}, std=${std.toStringAsFixed(1)}');
      return true;
    } catch (e) {
      print('[OpenCV] Validation error: $e');
      return false;
    }
  }

  /// Finalize detection by resizing and exporting debug images
  static Uint8List _finalizeDetection(cv.Mat srcMat, cv.Mat detectedBoard, String strategy, {cv.Rect? bounds}) {
    // Export original image with detected square outline if bounds provided
    if (bounds != null) {
      final originalWithOutline = _drawSquareOutlineOnOriginal(srcMat, bounds);
      final outlineBytes = _matToBytes(originalWithOutline);
      DebugExporter.exportBytes(outlineBytes, name: 'opencv_original_with_outline_${strategy}_${DateTime.now().millisecondsSinceEpoch}.png');
    }

    final resized = cv.resize(detectedBoard, (512, 512));

    // Create overlay with 8x8 grid lines on the final result
    final overlayResult = _createSquareGridOverlay(resized);
    final bytes = _matToBytes(overlayResult);
    DebugExporter.exportBytes(bytes, name: 'opencv_square_with_grid_${strategy}_${DateTime.now().millisecondsSinceEpoch}.png');

    // Also export the clean version without overlay
    final cleanBytes = _matToBytes(resized);
    DebugExporter.exportBytes(cleanBytes, name: 'opencv_square_clean_${strategy}_${DateTime.now().millisecondsSinceEpoch}.png');

    return cleanBytes;
  }

  /// Validates that a candidate crop shows exactly an 8x8 chessboard grid.
  /// Requires exactly 9 line clusters in each direction (8 cells = 9 lines).
  static bool _validateStrict8x8Grid(cv.Mat mat) {
    try {
      // Aspect ratio check - must be roughly square
      final aspect = mat.cols / mat.rows;
      final squareish = aspect > 0.85 && aspect < 1.15;
      if (!squareish) {
        print('[OpenCV] Validation: rejected due to non-square aspect (${aspect.toStringAsFixed(2)})');
        return false;
      }

      // Use contrast-enhanced L channel (Lab) for robust line detection on colored boards
      final lab = cv.cvtColor(mat, cv.COLOR_BGR2Lab);
      final channels = cv.split(lab);
      final l = channels[0];
      final lEq = cv.equalizeHist(l);
      final blurred = cv.gaussianBlur(lEq, (3, 3), 0);
      final edges = cv.canny(blurred, 50, 150);

      final lines = cv.HoughLinesP(edges, 1, cv.CV_PI / 180, 80, minLineLength: 60, maxLineGap: 10);
      if (lines.rows == 0) {
        print('[OpenCV] Validation: no Hough lines');
        return false;
      }

      final horizontal = <int>[]; // y positions (midpoints)
      final vertical = <int>[];   // x positions (midpoints)

      for (int i = 0; i < lines.rows; i++) {
        final row = lines.row(i);
        final x1 = row.at<int>(0, 0);
        final y1 = row.at<int>(0, 1);
        final x2 = row.at<int>(0, 2);
        final y2 = row.at<int>(0, 3);

        final dx = (x2 - x1).toDouble();
        final dy = (y2 - y1).toDouble();
        final length = (dx.abs() + dy.abs());
        if (length < 40) continue;

        final angleDeg = (math.atan2(dy, dx) * 180.0 / 3.141592653589793).abs();
        // Normalize angle to [0,90]
        final angle = angleDeg > 90 ? 180 - angleDeg : angleDeg;

        if (angle < 12) {
          // horizontal-ish
          horizontal.add(((y1 + y2) / 2).round());
        } else if (angle > 78) {
          // vertical-ish
          vertical.add(((x1 + x2) / 2).round());
        }
      }

      print('[OpenCV] Raw line positions: H:${horizontal.length} V:${vertical.length}');

      // First pass: cluster with reasonable tolerance to group nearby lines
      var hTolerance = (mat.rows * 0.02).round();
      var vTolerance = (mat.cols * 0.02).round();

      var hCenters = _clusterCenters(horizontal, tolerance: hTolerance);
      var vCenters = _clusterCenters(vertical, tolerance: vTolerance);

      print('[OpenCV] After clustering: H:${hCenters.length} V:${vCenters.length}');

      // If we have too many lines, select the best subset of 7-9 evenly spaced lines
      if (hCenters.length > 15) {
        hCenters = _selectBestEvenlySpacedLines(hCenters, targetCount: 9);
        print('[OpenCV] Selected best ${hCenters.length} horizontal lines from ${hCenters.length} clustered');
      }
      if (vCenters.length > 15) {
        vCenters = _selectBestEvenlySpacedLines(vCenters, targetCount: 9);
        print('[OpenCV] Selected best ${vCenters.length} vertical lines from ${vCenters.length} clustered');
      }

      // If we have exactly 7 lines, infer missing outer edge lines
      hCenters = _inferMissingEdgeLines(hCenters, mat.rows);
      vCenters = _inferMissingEdgeLines(vCenters, mat.cols);

      // Evaluate spacing consistency for both dimensions
      final hSpacingQuality = _evaluateSpacingConsistency(hCenters);
      final vSpacingQuality = _evaluateSpacingConsistency(vCenters);

      print('[OpenCV] Spacing quality - H: ${hSpacingQuality.toStringAsFixed(3)}, V: ${vSpacingQuality.toStringAsFixed(3)}');

      // If one dimension has much better spacing, use it to constrain the other
      if ((vSpacingQuality < hSpacingQuality * 0.7) && vSpacingQuality < 0.15) {
        print('[OpenCV] Vertical spacing is much better, using it to constrain horizontal search');
        final newHCenters = _findConstrainedLines(horizontal, vCenters, true, mat); // true = finding horizontal lines
        final newHQuality = _evaluateSpacingConsistency(newHCenters);
        if (newHQuality < hSpacingQuality) {
          hCenters = newHCenters;
          print('[OpenCV] Constrained horizontal search improved spacing: ${hSpacingQuality.toStringAsFixed(3)} → ${newHQuality.toStringAsFixed(3)}');
        } else {
          print('[OpenCV] Constrained search did not improve spacing, keeping original');
        }
      } else if ((hSpacingQuality < vSpacingQuality * 0.7) && hSpacingQuality < 0.15) {
        print('[OpenCV] Horizontal spacing is much better, using it to constrain vertical search');
        final newVCenters = _findConstrainedLines(vertical, hCenters, false, mat); // false = finding vertical lines
        final newVQuality = _evaluateSpacingConsistency(newVCenters);
        if (newVQuality < vSpacingQuality) {
          vCenters = newVCenters;
          print('[OpenCV] Constrained vertical search improved spacing: ${vSpacingQuality.toStringAsFixed(3)} → ${newVQuality.toStringAsFixed(3)}');
        } else {
          print('[OpenCV] Constrained search did not improve spacing, keeping original');
        }
      }

      final hCount = hCenters.length;
      final vCount = vCenters.length;

      print('[OpenCV] Validation clusters H:$hCount V:$vCount (after edge inference)');

      // Export overlay of detected grid lines for debugging
      try {
        print('[OpenCV] Drawing overlay: H centers: $hCenters, V centers: $vCenters');
        final overlay = mat.clone();
        // Draw horizontal centers in green
        for (final y in hCenters) {
          cv.line(overlay, cv.Point(0, y), cv.Point(overlay.cols, y), cv.Scalar(0, 255, 0, 255), thickness: 3);
        }
        // Draw vertical centers in blue
        for (final x in vCenters) {
          cv.line(overlay, cv.Point(x, 0), cv.Point(x, overlay.rows), cv.Scalar(255, 0, 0, 255), thickness: 3);
        }
        final overlayPng = _matToBytes(overlay);
        DebugExporter.exportBytes(overlayPng, name: 'overlay_grid_${DateTime.now().millisecondsSinceEpoch}_H${hCount}_V$vCount.png');
        print('[OpenCV] Overlay exported successfully');
      } catch (e) {
        print('[OpenCV] Overlay error: $e');
      }

      // Accept 7 lines (internal) or 9 lines (with edges) for 8x8 board
      // We can also work with fewer lines in some cases
      if ((hCount < 6 || hCount > 12) || (vCount < 6 || vCount > 12)) {
        print('[OpenCV] Validation failed: line count out of range (H:$hCount V:$vCount, need 6-12 each)');
        return false;
      }

      // For proper 8x8 detection, prefer 7 or 9 lines but allow some flexibility
      if (hCount != 7 && hCount != 9 && vCount != 7 && vCount != 9) {
        print('[OpenCV] Warning: unusual line count (H:$hCount V:$vCount), but proceeding');
      }

      // Check for roughly uniform spacing between adjacent lines
      bool spacingOk(List<int> centers, int size) {
        if (centers.length < 3) return false;
        centers.sort();
        final gaps = <double>[];
        for (int i = 1; i < centers.length; i++) {
          gaps.add((centers[i] - centers[i - 1]).toDouble());
        }
        final mean = gaps.reduce((a, b) => a + b) / gaps.length;
        final varSum = gaps.fold(0.0, (s, g) => s + (g - mean) * (g - mean));
        final std = math.sqrt(varSum / gaps.length);
        final cvRatio = std / (mean == 0 ? 1 : mean);
        // Chess boards need consistent spacing but allow some real-world variation
        final ok = cvRatio < 0.30 && mean > size * 0.07; // CV must be < 30%, cell size at least 7%
        if (!ok) {
          print('[OpenCV] Validation failed: irregular spacing (cv=${cvRatio.toStringAsFixed(2)}, mean=${mean.toStringAsFixed(1)})');
        }
        // Also check margin symmetry
        final firstGap = gaps.first;
        final lastGap = gaps.last;
        final marginRatio = (firstGap - lastGap).abs() / (mean == 0 ? 1 : mean);
        if (marginRatio > 0.5) {
          print('[OpenCV] Validation failed: asymmetric margins (ratio=${marginRatio.toStringAsFixed(2)})');
          return false;
        }
        return ok;
      }

      final spacingValid = spacingOk(hCenters, mat.rows) && spacingOk(vCenters, mat.cols);
      if (!spacingValid) return false;

      return true;
    } catch (e) {
      print('[OpenCV] Validation error: $e');
      return false;
    }
  }


  /// Simple 1D clustering by proximity (pixels). Returns cluster centers.
  static List<int> _clusterCenters(List<int> coords, {required int tolerance}) {
    if (coords.isEmpty) return <int>[];
    coords.sort();
    final centers = <int>[];
    int start = coords.first;
    int end = coords.first;
    int clusterSize = 1;

    for (int i = 1; i < coords.length; i++) {
      if ((coords[i] - end).abs() <= tolerance) {
        end = coords[i];
        clusterSize++;
      } else {
        final center = ((start + end) / 2).round();
        centers.add(center);
        start = end = coords[i];
        clusterSize = 1;
      }
    }
    final center = ((start + end) / 2).round();
    centers.add(center);
    print('[OpenCV] Clustered ${coords.length} coords into ${centers.length} centers (tolerance: $tolerance)');
    return centers;
  }

  /// Select the best subset of evenly spaced lines for chess board detection
  static List<int> _selectBestEvenlySpacedLines(List<int> lines, {required int targetCount}) {
    if (lines.length <= targetCount) return lines;

    lines.sort();
    double bestScore = double.infinity;
    List<int> bestSubset = [];

    // Try different starting positions and find the most evenly spaced subset
    for (int start = 0; start <= lines.length - targetCount; start++) {
      for (int step = 1; step <= (lines.length - start) ~/ targetCount; step++) {
        final subset = <int>[];

        // Build subset with this step size
        for (int i = 0; i < targetCount && start + i * step < lines.length; i++) {
          subset.add(lines[start + i * step]);
        }

        if (subset.length == targetCount) {
          // Calculate spacing variance (lower is better)
          final spacings = <double>[];
          for (int i = 1; i < subset.length; i++) {
            spacings.add((subset[i] - subset[i-1]).toDouble());
          }

          if (spacings.isNotEmpty) {
            final avgSpacing = spacings.reduce((a, b) => a + b) / spacings.length;
            final variance = spacings.map((s) => (s - avgSpacing) * (s - avgSpacing)).reduce((a, b) => a + b) / spacings.length;

            if (variance < bestScore) {
              bestScore = variance;
              bestSubset = List.from(subset);
            }
          }
        }
      }
    }

    if (bestSubset.isNotEmpty) {
      print('[OpenCV] Best evenly spaced subset: spacings variance = ${bestScore.toStringAsFixed(2)}');
      return bestSubset;
    }

    // Fallback: take evenly distributed lines across the range
    final result = <int>[];
    for (int i = 0; i < targetCount; i++) {
      final index = (i * (lines.length - 1) / (targetCount - 1)).round();
      result.add(lines[index]);
    }
    return result;
  }

  /// Evaluate spacing consistency (lower score = more consistent)
  static double _evaluateSpacingConsistency(List<int> centers) {
    if (centers.length < 3) return 1.0; // Not enough data

    centers.sort();
    final spacings = <double>[];
    for (int i = 1; i < centers.length; i++) {
      spacings.add((centers[i] - centers[i-1]).toDouble());
    }

    final mean = spacings.reduce((a, b) => a + b) / spacings.length;
    final variance = spacings.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) / spacings.length;
    final stdDev = math.sqrt(variance);

    // Coefficient of variation (CV) - lower is better
    final cv = stdDev / mean;
    print('[OpenCV] Spacing analysis: mean=${mean.toStringAsFixed(1)}, stdDev=${stdDev.toStringAsFixed(1)}, CV=${cv.toStringAsFixed(3)}');
    return cv;
  }

  /// Find constrained lines using the good dimension to define search area
  static List<int> _findConstrainedLines(List<int> rawLines, List<int> goodDimension, bool findingHorizontal, cv.Mat mat) {
    if (goodDimension.length < 7) return rawLines;

    goodDimension.sort();

    // Define the search region using the good dimension (with some padding)
    final start = goodDimension.first;
    final end = goodDimension.last;
    final padding = ((end - start) * 0.1).round(); // 10% padding
    final searchStart = (start - padding).clamp(0, findingHorizontal ? mat.rows : mat.cols);
    final searchEnd = (end + padding).clamp(0, findingHorizontal ? mat.rows : mat.cols);

    print('[OpenCV] Constraining search to range $searchStart-$searchEnd (from good dimension $start-$end)');

    // Filter raw lines to only those within the search region
    final constrainedLines = rawLines.where((line) => line >= searchStart && line <= searchEnd).toList();

    print('[OpenCV] Filtered ${rawLines.length} raw lines to ${constrainedLines.length} within region');

    if (constrainedLines.length < 5) {
      print('[OpenCV] Too few constrained lines, falling back to original');
      return rawLines;
    }

    // Cluster with tighter tolerance within the constrained region
    final regionSize = searchEnd - searchStart;
    final tightTolerance = (regionSize * 0.015).round(); // Stricter 1.5% tolerance

    var clustered = _clusterCenters(constrainedLines, tolerance: tightTolerance);
    print('[OpenCV] Constrained clustering: ${constrainedLines.length} → ${clustered.length} lines');

    // Select the most evenly spaced subset
    if (clustered.length > 9) {
      clustered = _selectBestEvenlySpacedLines(clustered, targetCount: 9);
    }

    // Infer edges if needed
    clustered = _inferMissingEdgeLines(clustered, findingHorizontal ? mat.rows : mat.cols);

    print('[OpenCV] Final constrained result: ${clustered.length} lines');
    return clustered;
  }

  /// Infer missing edge lines when we have exactly 7 internal lines for an 8x8 board
  static List<int> _inferMissingEdgeLines(List<int> centers, int imageSize) {
    if (centers.length == 9) {
      // Already have all 9 lines (7 internal + 2 edges)
      return centers;
    }

    if (centers.length == 7) {
      // Add missing outer edge lines by extrapolating with equal spacing
      final List<int> result = List.from(centers);
      result.sort();

      // Calculate average spacing between existing lines
      final spacings = <int>[];
      for (int i = 1; i < result.length; i++) {
        spacings.add(result[i] - result[i-1]);
      }
      final avgSpacing = spacings.reduce((a, b) => a + b) / spacings.length;

      // Add edge lines with same spacing
      final firstEdge = (result.first - avgSpacing).round().clamp(0, imageSize);
      final lastEdge = (result.last + avgSpacing).round().clamp(0, imageSize);

      result.insert(0, firstEdge);
      result.add(lastEdge);

      print('[OpenCV] Inferred edge lines: added $firstEdge and $lastEdge (spacing: ${avgSpacing.toStringAsFixed(1)})');
      return result;
    }

    // Return as-is for other counts
    return centers;
  }
  
  

  /// Detect chessboard by finding the largest square region in the image
  static Future<cv.Mat?> _detectLargestSquare(cv.Mat srcMat) async {
    final (result, _) = await _detectLargestSquareWithBounds(srcMat);
    return result;
  }

  /// Detect chessboard and return both the cropped result and the bounds
  static Future<(cv.Mat?, cv.Rect?)> _detectLargestSquareWithBounds(cv.Mat srcMat) async {
    try {
      print('[OpenCV] Attempting largest square detection');

      // Simple grayscale conversion - don't over-process and destroy the lines
      final gray = cv.cvtColor(srcMat, cv.COLOR_BGR2GRAY);

      // Basic edge detection with standard parameters
      final edges = cv.canny(gray, 50, 150);

      // 2. Find all contours
      final (contours, hierarchy) = cv.findContours(edges, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
      print('[OpenCV] Found ${contours.length} contours');

      if (contours.isEmpty) {
        print('[OpenCV] No contours found');
        return (null, null);
      }

      // 3. Find rectangular contours and score them
      final candidates = <({cv.Rect rect, double score})>[];

      for (int i = 0; i < contours.length; i++) {
        final contour = contours[i];
        // Approximate contour to polygon
        final epsilon = cv.arcLength(contour, true) * 0.02;
        final approx = cv.approxPolyDP(contour, epsilon, true);

        // Look for roughly rectangular shapes (4-6 vertices work due to noise)
        if (approx.length >= 4 && approx.length <= 6) {
          final rect = cv.boundingRect(contour);

          // 4. Filter for square-ish shapes (aspect ratio close to 1.0)
          final aspectRatio = rect.width / rect.height.toDouble();
          if (aspectRatio >= 0.7 && aspectRatio <= 1.4) {

            // 5. Score by size, position, and squareness
            final area = rect.width * rect.height;
            final imageArea = srcMat.cols * srcMat.rows;
            final sizeScore = area / imageArea.toDouble(); // Bigger is better

            // Prefer centered squares
            final centerX = rect.x + rect.width / 2;
            final centerY = rect.y + rect.height / 2;
            final imageCenterX = srcMat.cols / 2;
            final imageCenterY = srcMat.rows / 2;
            final centerDistance = math.sqrt(
              math.pow(centerX - imageCenterX, 2) + math.pow(centerY - imageCenterY, 2)
            );
            final maxDistance = math.sqrt(
              math.pow(srcMat.cols / 2, 2) + math.pow(srcMat.rows / 2, 2)
            );
            final centerScore = 1.0 - (centerDistance / maxDistance);

            // Prefer squares over rectangles
            final squareScore = 1.0 - (aspectRatio - 1.0).abs();

            // Combined score: size (60%) + position (20%) + squareness (20%)
            final totalScore = sizeScore * 0.6 + centerScore * 0.2 + squareScore * 0.2;

            // Only consider reasonably sized squares (at least 5% of image)
            if (sizeScore > 0.05) {
              // Validate that this square actually looks like a chess board
              final chessScore = _validateChessBoardPattern(srcMat, rect);
              final finalScore = totalScore * 0.7 + chessScore * 0.3; // Blend geometric and chess scores

              candidates.add((rect: rect, score: finalScore));
              print('[OpenCV] Square candidate: ${rect.width}x${rect.height} at (${rect.x},${rect.y}) size=${(sizeScore*100).toStringAsFixed(1)}% chess=${chessScore.toStringAsFixed(2)} final=${finalScore.toStringAsFixed(3)}');
            }
          }
        }
      }

      if (candidates.isEmpty) {
        print('[OpenCV] No suitable square candidates found, trying with VERY relaxed criteria');

        // VERY relaxed criteria - just look for anything square-ish
        for (int i = 0; i < contours.length; i++) {
          final contour = contours[i];
          final rect = cv.boundingRect(contour);
          final aspectRatio = rect.width / rect.height.toDouble();

          // Very lenient: 0.6 to 1.6 aspect ratio (same as Strategy 1)
          if (aspectRatio >= 0.6 && aspectRatio <= 1.6) {
            final area = rect.width * rect.height;
            final imageArea = srcMat.cols * srcMat.rows;
            final sizeScore = area / imageArea.toDouble();

            // Accept even tiny boards (1% of image)
            if (sizeScore >= 0.01 && sizeScore <= 0.99) {
              // Check for chess-like contrast
              final roi = srcMat.region(rect);
              final gray = cv.cvtColor(roi, cv.COLOR_BGR2GRAY);

              final (_, stdDev) = cv.meanStdDev(gray);
              final std = stdDev.val1; // Get first channel stddev

              // Chess boards need some contrast (stddev > 20)
              if (std > 20) {
                final contrastScore = (std / 128.0).clamp(0.0, 1.0); // Normalize
                final finalScore = sizeScore * 0.4 + contrastScore * 0.6;

                candidates.add((rect: rect, score: finalScore));
                print('[OpenCV] Relaxed candidate: ${rect.width}x${rect.height} size=${(sizeScore*100).toStringAsFixed(1)}% std=${std.toStringAsFixed(1)} score=${finalScore.toStringAsFixed(3)}');
              }
            }
          }
        }

        if (candidates.isEmpty) {
          print('[OpenCV] Still no candidates found even with very relaxed criteria');
          return (null, null);
        }
      }

      // Pick the highest scoring square
      candidates.sort((a, b) => b.score.compareTo(a.score));
      final bestSquare = candidates.first;

      print('[OpenCV] Best square: ${bestSquare.rect.width}x${bestSquare.rect.height} at (${bestSquare.rect.x},${bestSquare.rect.y}) score=${bestSquare.score.toStringAsFixed(3)}');

      // Export bounds overlay for debugging
      _exportBoundsOverlay('bounds_square', srcMat, bestSquare.rect);

      // Extract the square region
      final croppedBoard = _extractSquareRegion(srcMat, bestSquare.rect);
      if (croppedBoard != null) {
        print('[OpenCV] Square extraction successful');
        return (croppedBoard, bestSquare.rect);
      }

      return (null, null);
    } catch (e) {
      print('[OpenCV] Grid detection error: $e');
      return (null, null);
    }
  }

  /// Validate if a square region contains a chess board pattern
  static double _validateChessBoardPattern(cv.Mat srcMat, cv.Rect rect) {
    try {
      // Extract the region
      final roi = srcMat.region(rect);
      final gray = cv.cvtColor(roi, cv.COLOR_BGR2GRAY);

      // Look for grid lines within this region
      final edges = cv.canny(gray, 30, 100);

      // Detect horizontal and vertical lines
      final lines = cv.HoughLinesP(edges, 1, cv.CV_PI / 180, 30, minLineLength: rect.width * 0.2, maxLineGap: 10);

      var horizontalLines = 0;
      var verticalLines = 0;

      for (int i = 0; i < lines.rows; i++) {
        final line = lines.row(i);
        final x1 = line.at<int>(0, 0);
        final y1 = line.at<int>(0, 1);
        final x2 = line.at<int>(0, 2);
        final y2 = line.at<int>(0, 3);

        final dx = (x1 - x2).abs();
        final dy = (y1 - y2).abs();

        // Classify as horizontal or vertical
        if (dx > dy * 2) {
          horizontalLines++;
        } else if (dy > dx * 2) {
          verticalLines++;
        }
      }

      // Chess boards should have multiple lines in both directions
      const minLines = 3; // At least 3 lines each way (flexible for various crops)
      const maxLines = 12; // But not too many (noisy detection)

      final hGood = horizontalLines >= minLines && horizontalLines <= maxLines;
      final vGood = verticalLines >= minLines && verticalLines <= maxLines;

      if (hGood && vGood) {
        // Additional check: look for alternating light/dark pattern
        final checkered = _hasCheckeredPattern(gray);
        final lineBalance = 1.0 - ((horizontalLines - verticalLines).abs() / math.max(horizontalLines, verticalLines));

        return (checkered * 0.6 + lineBalance * 0.4).clamp(0.0, 1.0);
      }

      return 0.0;
    } catch (e) {
      print('[OpenCV] Chess validation error: $e');
      return 0.0;
    }
  }

  /// Check for alternating light/dark checkered pattern
  static double _hasCheckeredPattern(cv.Mat gray) {
    // Sample a grid of points and check for alternating brightness
    const rows = 8;
    const cols = 8;
    final cellW = gray.cols / cols;
    final cellH = gray.rows / rows;

    var alternatingCount = 0;
    var totalChecks = 0;

    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < cols - 1; c++) {
        final y = (r * cellH + cellH / 2).round();
        final x = (c * cellW + cellW / 2).round();

        if (x < gray.cols && y < gray.rows) {
          final current = gray.at<int>(y, x);

          // Check right neighbor
          final rightX = ((c + 1) * cellW + cellW / 2).round();
          if (rightX < gray.cols) {
            final right = gray.at<int>(y, rightX);
            if ((current - right).abs() > 30) alternatingCount++; // Significant brightness difference
            totalChecks++;
          }

          // Check bottom neighbor
          final bottomY = ((r + 1) * cellH + cellH / 2).round();
          if (bottomY < gray.rows) {
            final bottom = gray.at<int>(bottomY, x);
            if ((current - bottom).abs() > 30) alternatingCount++;
            totalChecks++;
          }
        }
      }
    }

    return totalChecks > 0 ? alternatingCount / totalChecks : 0.0;
  }


  /// Detect horizontal lines in edge image - optimized for chess grids
  static List<cv.Vec4i> _detectHorizontalLines(cv.Mat edges) {
    // Much higher threshold and longer minimum length for chess board grids
    final lines = cv.HoughLinesP(edges, 1, cv.CV_PI / 180, 150, minLineLength: 300, maxLineGap: 20);
    final horizontalLines = <cv.Vec4i>[];

    for (int i = 0; i < lines.rows; i++) {
      final line = lines.row(i);
      final x1 = line.at<int>(0, 0);
      final y1 = line.at<int>(0, 1);
      final x2 = line.at<int>(0, 2);
      final y2 = line.at<int>(0, 3);

      final dx = (x1 - x2).abs();
      final dy = (y1 - y2).abs();
      final length = math.sqrt(dx * dx + dy * dy);

      // Must be strongly horizontal, long, and span a significant portion of image width
      if (dx > dy * 4 && length > 400 && dx > edges.cols * 0.4) {
        horizontalLines.add(cv.Vec4i(x1, y1, x2, y2));
      }
    }

    print('[OpenCV] Filtered to ${horizontalLines.length} strong horizontal lines');
    return horizontalLines;
  }

  /// Detect vertical lines in edge image - optimized for chess grids
  static List<cv.Vec4i> _detectVerticalLines(cv.Mat edges) {
    // Much higher threshold and longer minimum length for chess board grids
    final lines = cv.HoughLinesP(edges, 1, cv.CV_PI / 180, 150, minLineLength: 300, maxLineGap: 20);
    final verticalLines = <cv.Vec4i>[];

    for (int i = 0; i < lines.rows; i++) {
      final line = lines.row(i);
      final x1 = line.at<int>(0, 0);
      final y1 = line.at<int>(0, 1);
      final x2 = line.at<int>(0, 2);
      final y2 = line.at<int>(0, 3);

      final dx = (x1 - x2).abs();
      final dy = (y1 - y2).abs();
      final length = math.sqrt(dx * dx + dy * dy);

      // Must be strongly vertical, long, and span a significant portion of image height
      if (dy > dx * 4 && length > 400 && dy > edges.rows * 0.15) {
        verticalLines.add(cv.Vec4i(x1, y1, x2, y2));
      }
    }

    print('[OpenCV] Filtered to ${verticalLines.length} strong vertical lines');
    return verticalLines;
  }


  /// Find the best subset of exactly 7 evenly-spaced lines from a larger set
  static List<cv.Vec4i> _findBestLineSubset(List<cv.Vec4i> lines, bool isHorizontal) {
    if (lines.length <= 7) return lines;

    // Extract positions and sort them
    final positions = <int>[];
    for (final line in lines) {
      if (isHorizontal) {
        positions.add(((line.val2 + line.val4) / 2).round());
      } else {
        positions.add(((line.val1 + line.val3) / 2).round());
      }
    }

    // Sort positions and corresponding lines together
    final indexedLines = List.generate(lines.length, (i) => (positions[i], lines[i]));
    indexedLines.sort((a, b) => a.$1.compareTo(b.$1));

    final sortedPositions = indexedLines.map((e) => e.$1).toList();
    final sortedLines = indexedLines.map((e) => e.$2).toList();

    // Find the subset of 7 lines with the most uniform spacing
    double bestScore = double.infinity;
    List<cv.Vec4i> bestLines = [];

    // Try all possible contiguous subsets of 7 lines
    for (int start = 0; start <= lines.length - 7; start++) {
      final subset = sortedLines.sublist(start, start + 7);
      final subsetPositions = sortedPositions.sublist(start, start + 7);

      // Calculate spacing uniformity score (lower is better)
      final gaps = <int>[];
      for (int i = 1; i < subsetPositions.length; i++) {
        gaps.add(subsetPositions[i] - subsetPositions[i - 1]);
      }

      final mean = gaps.reduce((a, b) => a + b) / gaps.length;
      final variance = gaps.fold(0.0, (sum, gap) => sum + (gap - mean) * (gap - mean)) / gaps.length;

      if (variance < bestScore) {
        bestScore = variance;
        bestLines = subset;
      }
    }

    print('[OpenCV] Best line subset variance: ${bestScore.toStringAsFixed(1)}');
    return bestLines;
  }

  /// Find the rectangular region where both horizontal and vertical lines intersect
  static cv.Rect? _findBoardRegion(List<cv.Vec4i> hLines, List<cv.Vec4i> vLines, cv.Mat srcMat) {
    // Get bounds of horizontal lines
    final hPositions = hLines.map((line) => ((line.val2 + line.val4) / 2).round()).toList();
    hPositions.sort();

    // Get bounds of vertical lines
    final vPositions = vLines.map((line) => ((line.val1 + line.val3) / 2).round()).toList();
    vPositions.sort();

    if (hPositions.length < 7 || vPositions.length < 7) return null;

    // Use the middle 7 positions to avoid outliers
    final midHStart = (hPositions.length - 7) ~/ 2;
    final midVStart = (vPositions.length - 7) ~/ 2;

    final coreH = hPositions.sublist(midHStart, midHStart + 7);
    final coreV = vPositions.sublist(midVStart, midVStart + 7);

    // Calculate average spacing
    final hGap = (coreH.last - coreH.first) / 6.0; // 6 gaps between 7 lines
    final vGap = (coreV.last - coreV.first) / 6.0;

    // Board should be square, so use consistent spacing
    final avgGap = (hGap + vGap) / 2;

    // Extend by 1 gap on each side to include board edges
    final left = (coreV.first - avgGap).round().clamp(0, srcMat.cols);
    final right = (coreV.last + avgGap).round().clamp(0, srcMat.cols);
    final top = (coreH.first - avgGap).round().clamp(0, srcMat.rows);
    final bottom = (coreH.last + avgGap).round().clamp(0, srcMat.rows);

    return cv.Rect(left, top, right - left, bottom - top);
  }

  /// Make a region perfectly square using the smaller dimension
  static cv.Rect _makeSquareRegion(cv.Rect region, cv.Mat srcMat) {
    final size = region.width < region.height ? region.width : region.height;

    // Center the square within the original region
    final centerX = region.x + region.width / 2;
    final centerY = region.y + region.height / 2;

    final left = (centerX - size / 2).round().clamp(0, srcMat.cols - size);
    final top = (centerY - size / 2).round().clamp(0, srcMat.rows - size);

    return cv.Rect(left, top, size, size);
  }

  /// Check if line counts are reasonable for a chessboard

  /// Tier 1: High quality detection (strict) - for clear screenshots
  static (List<cv.Vec4i>, List<cv.Vec4i>) _detectLinesTier1(cv.Mat edges) {
    return (_detectHorizontalLines(edges), _detectVerticalLines(edges));
  }

  /// Tier 2: Medium quality (relaxed thresholds)
  static (List<cv.Vec4i>, List<cv.Vec4i>) _detectLinesTier2(cv.Mat edges) {
    final hLines = _detectHorizontalLinesWithParams(edges, threshold: 100, minLength: 200.0, widthRatio: 0.3);
    final vLines = _detectVerticalLinesWithParams(edges, threshold: 100, minLength: 200.0, heightRatio: 0.12);
    return (hLines, vLines);
  }

  /// Tier 3: Fallback (loose thresholds) - for difficult images
  static (List<cv.Vec4i>, List<cv.Vec4i>) _detectLinesTier3(cv.Mat edges) {
    final hLines = _detectHorizontalLinesWithParams(edges, threshold: 80, minLength: 150.0, widthRatio: 0.25);
    final vLines = _detectVerticalLinesWithParams(edges, threshold: 80, minLength: 150.0, heightRatio: 0.1);
    return (hLines, vLines);
  }

  /// Parameterized horizontal line detection
  static List<cv.Vec4i> _detectHorizontalLinesWithParams(cv.Mat edges, {
    required int threshold,
    required double minLength,
    required double widthRatio,
  }) {
    final lines = cv.HoughLinesP(edges, 1, cv.CV_PI / 180, threshold, minLineLength: minLength, maxLineGap: 20);
    final horizontalLines = <cv.Vec4i>[];

    for (int i = 0; i < lines.rows; i++) {
      final line = lines.row(i);
      final x1 = line.at<int>(0, 0);
      final y1 = line.at<int>(0, 1);
      final x2 = line.at<int>(0, 2);
      final y2 = line.at<int>(0, 3);

      final dx = (x1 - x2).abs();
      final dy = (y1 - y2).abs();
      final length = math.sqrt(dx * dx + dy * dy);

      if (dx > dy * 3 && length > minLength * 0.75 && dx > edges.cols * widthRatio) {
        horizontalLines.add(cv.Vec4i(x1, y1, x2, y2));
      }
    }

    return horizontalLines;
  }

  /// Parameterized vertical line detection
  static List<cv.Vec4i> _detectVerticalLinesWithParams(cv.Mat edges, {
    required int threshold,
    required double minLength,
    required double heightRatio,
  }) {
    final lines = cv.HoughLinesP(edges, 1, cv.CV_PI / 180, threshold, minLineLength: minLength, maxLineGap: 20);
    final verticalLines = <cv.Vec4i>[];

    for (int i = 0; i < lines.rows; i++) {
      final line = lines.row(i);
      final x1 = line.at<int>(0, 0);
      final y1 = line.at<int>(0, 1);
      final x2 = line.at<int>(0, 2);
      final y2 = line.at<int>(0, 3);

      final dx = (x1 - x2).abs();
      final dy = (y1 - y2).abs();
      final length = math.sqrt(dx * dx + dy * dy);

      if (dy > dx * 3 && length > minLength * 0.75 && dy > edges.rows * heightRatio) {
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

    // Use outermost detected grid lines as exact board boundaries - no extension needed
    int left = minX.clamp(0, regionMat.cols);
    int right = maxX.clamp(0, regionMat.cols);
    int top = minY.clamp(0, regionMat.rows);
    int bottom = maxY.clamp(0, regionMat.rows);

    int width = right - left;
    int height = bottom - top;

    // Make square by expanding both sides equally to preserve board centering
    if (width != height) {
      final size = width > height ? width : height;
      if (width < height) {
        final delta = size - width;
        final addEach = delta ~/ 2;
        left = (left - addEach).clamp(0, regionMat.cols);
        right = (right + (delta - addEach)).clamp(0, regionMat.cols);
      } else {
        final delta = size - height;
        final addEach = delta ~/ 2;
        top = (top - addEach).clamp(0, regionMat.rows);
        bottom = (bottom + (delta - addEach)).clamp(0, regionMat.rows);
      }
      width = right - left;
      height = bottom - top;
    }

    // Enforce minimum size
    final size = width; // == height after square adjustment
    if (size < 100) return null;
    return cv.Rect(left, top, width, height);
  }
  
  /// Extract square region from bounds
  static cv.Mat? _extractSquareRegion(cv.Mat srcMat, cv.Rect bounds) {
    try {
      // Use direct ROI extraction to avoid perspective distortion
      final roi = srcMat.region(bounds);
      return roi;
    } catch (e) {
      print('[OpenCV] Error extracting square region: $e');
      return null;
    }
  }

  static void _exportBoundsOverlay(String tag, cv.Mat srcMat, cv.Rect bounds) {
    try {
      final overlay = srcMat.clone();
      final p1 = cv.Point(bounds.x, bounds.y);
      final p2 = cv.Point(bounds.x + bounds.width, bounds.y);
      final p3 = cv.Point(bounds.x + bounds.width, bounds.y + bounds.height);
      final p4 = cv.Point(bounds.x, bounds.y + bounds.height);
      final green = cv.Scalar(0, 255, 0, 255);
      cv.line(overlay, p1, p2, green);
      cv.line(overlay, p2, p3, green);
      cv.line(overlay, p3, p4, green);
      cv.line(overlay, p4, p1, green);
      final bytes = _matToBytes(overlay);
      DebugExporter.exportBytes(bytes, name: '${tag}_${DateTime.now().millisecondsSinceEpoch}.png');
    } catch (_) {}
  }
  
  /// Draw square outline on the original image to show detection bounds
  static cv.Mat _drawSquareOutlineOnOriginal(cv.Mat originalMat, cv.Rect bounds) {
    final overlay = originalMat.clone();

    // Draw thick lime green outline around the detected square
    final outlineColor = cv.Scalar(0, 255, 0, 255); // Lime green in BGR
    const thickness = 8;

    // Draw the rectangle outline
    final p1 = cv.Point(bounds.x, bounds.y);
    final p2 = cv.Point(bounds.x + bounds.width, bounds.y);
    final p3 = cv.Point(bounds.x + bounds.width, bounds.y + bounds.height);
    final p4 = cv.Point(bounds.x, bounds.y + bounds.height);

    cv.line(overlay, p1, p2, outlineColor, thickness: thickness);
    cv.line(overlay, p2, p3, outlineColor, thickness: thickness);
    cv.line(overlay, p3, p4, outlineColor, thickness: thickness);
    cv.line(overlay, p4, p1, outlineColor, thickness: thickness);

    // Add corner markers for extra visibility
    const cornerSize = 20;
    final cornerColor = cv.Scalar(255, 0, 0, 255); // Blue corners in BGR
    const cornerThickness = 6;

    // Top-left corner
    cv.line(overlay, cv.Point(bounds.x, bounds.y), cv.Point(bounds.x + cornerSize, bounds.y), cornerColor, thickness: cornerThickness);
    cv.line(overlay, cv.Point(bounds.x, bounds.y), cv.Point(bounds.x, bounds.y + cornerSize), cornerColor, thickness: cornerThickness);

    // Top-right corner
    cv.line(overlay, cv.Point(bounds.x + bounds.width, bounds.y), cv.Point(bounds.x + bounds.width - cornerSize, bounds.y), cornerColor, thickness: cornerThickness);
    cv.line(overlay, cv.Point(bounds.x + bounds.width, bounds.y), cv.Point(bounds.x + bounds.width, bounds.y + cornerSize), cornerColor, thickness: cornerThickness);

    // Bottom-right corner
    cv.line(overlay, cv.Point(bounds.x + bounds.width, bounds.y + bounds.height), cv.Point(bounds.x + bounds.width - cornerSize, bounds.y + bounds.height), cornerColor, thickness: cornerThickness);
    cv.line(overlay, cv.Point(bounds.x + bounds.width, bounds.y + bounds.height), cv.Point(bounds.x + bounds.width, bounds.y + bounds.height - cornerSize), cornerColor, thickness: cornerThickness);

    // Bottom-left corner
    cv.line(overlay, cv.Point(bounds.x, bounds.y + bounds.height), cv.Point(bounds.x + cornerSize, bounds.y + bounds.height), cornerColor, thickness: cornerThickness);
    cv.line(overlay, cv.Point(bounds.x, bounds.y + bounds.height), cv.Point(bounds.x, bounds.y + bounds.height - cornerSize), cornerColor, thickness: cornerThickness);

    return overlay;
  }

  /// Create an overlay showing the 8x8 grid on the detected square
  static cv.Mat _createSquareGridOverlay(cv.Mat squareMat) {
    final overlay = squareMat.clone();
    final size = squareMat.cols; // Should be square (512x512)
    final cellSize = size / 8.0;

    // Draw grid lines in bright green for visibility
    final lineColor = cv.Scalar(0, 255, 0, 255); // Green in BGR
    const thickness = 2;

    // Draw horizontal lines (8 internal lines + 2 edges = 10 total, but we draw 9 to show 8x8 grid)
    for (int i = 0; i <= 8; i++) {
      final y = (i * cellSize).round();
      cv.line(overlay, cv.Point(0, y), cv.Point(size, y), lineColor, thickness: thickness);
    }

    // Draw vertical lines (same logic)
    for (int i = 0; i <= 8; i++) {
      final x = (i * cellSize).round();
      cv.line(overlay, cv.Point(x, 0), cv.Point(x, size), lineColor, thickness: thickness);
    }

    // Add square labels for debugging (A1, A2, etc.)
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final x = (col * cellSize + cellSize / 2).round();
        final y = (row * cellSize + cellSize / 2).round();

        // Chess notation: A-H for files (columns), 1-8 for ranks (rows, but inverted)
        final file = String.fromCharCode('A'.codeUnitAt(0) + col);
        final rank = (8 - row).toString();
        final label = '$file$rank';

        // Draw text in small font (if OpenCV Dart supports it)
        try {
          cv.putText(overlay, label, cv.Point(x - 8, y + 4), cv.FONT_HERSHEY_SIMPLEX, 0.4, cv.Scalar(255, 255, 0, 255), thickness: 1);
        } catch (e) {
          // Text rendering may not be available in all OpenCV builds
          print('[OpenCV] Text rendering not available: $e');
        }
      }
    }

    return overlay;
  }

  /// Convert OpenCV Mat to bytes
  static Uint8List _matToBytes(cv.Mat mat) {
    return cv.imencode('.png', mat).$2;
  }

  /// Extract individual 64 tiles from a detected board for debugging/training
  /// Returns list of tile images with their coordinates
  static Future<List<((int, int), Uint8List)>?> extractBoardTiles(Uint8List imageBytes, {int tileSize = 100}) async {
    try {
      print('[OpenCV] Starting tile extraction');

      // Decode image
      final srcMat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
      if (srcMat.isEmpty) return null;

      // First detect the board using strategy 1 (more reliable for grid extraction)
      final board = await _detectUsingContourPerspective(srcMat);
      if (board == null) {
        print('[OpenCV] Board detection failed for tile extraction');
        return null;
      }

      // Extract grid
      final grid = extractGrid(board, nVertical: 9, nHorizontal: 9);
      if (grid == null) {
        print('[OpenCV] Grid extraction failed');
        return null;
      }

      // Extract tiles
      final tiles = extractTiles(board, grid, tileSize, tileSize);
      print('[OpenCV] Extracted ${tiles.length} tiles');

      // Convert to bytes
      final result = <((int, int), Uint8List)>[];
      for (final ((x, y), tileMat) in tiles) {
        final tileBytes = _matToBytes(tileMat);
        result.add(((x, y), tileBytes));
      }

      return result;
    } catch (e) {
      print('[OpenCV] Tile extraction error: $e');
      return null;
    }
  }
}
