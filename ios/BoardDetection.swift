//  BoardDetection.swift
//  Created by Josh Kraft

import UIKit
import CoreGraphics
import os.log

// MARK: - ImageProcessor
/// Core image processing utilities for chess board detection and analysis
class ImageProcessor {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "fenify", category: "ImageProcessor")
    static func convertToGrayscale(_ bitmap: UIImage) -> [Int]? {
        guard let cgImage = bitmap.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: height * width * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var grayscale = [Int](repeating: 0, count: width * height)
        
        for i in 0..<(width * height) {
            let pixelIndex = i * bytesPerPixel
            let r = Int(pixelData[pixelIndex])
            let g = Int(pixelData[pixelIndex + 1])
            let b = Int(pixelData[pixelIndex + 2])
            
            // Convert to grayscale using luminance formula
            let gray = Int(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
            grayscale[i] = gray
        }
        
        return grayscale
    }
    
    static func colorDifference(_ color1: Int, _ color2: Int) -> Int {
        let r1 = (color1 >> 16) & 0xFF
        let g1 = (color1 >> 8) & 0xFF
        let b1 = color1 & 0xFF
        
        let r2 = (color2 >> 16) & 0xFF
        let g2 = (color2 >> 8) & 0xFF
        let b2 = color2 & 0xFF
        
        return abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)
    }
}

// MARK: - EdgeDetector
/// Sobel edge detection for finding chess board boundaries
class EdgeDetector {
    static func detectEdges(_ grayscale: [Int], width: Int, height: Int) -> [Int] {
        var edges = [Int](repeating: 0, count: grayscale.count)
        
        // Sobel kernels
        let sobelX = [
            [-1, 0, 1],
            [-2, 0, 2],
            [-1, 0, 1]
        ]
        let sobelY = [
            [-1, -2, -1],
            [0, 0, 0],
            [1, 2, 1]
        ]
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var gx = 0
                var gy = 0
                
                // Apply Sobel kernels
                for ky in -1...1 {
                    for kx in -1...1 {
                        let pixel = grayscale[(y + ky) * width + (x + kx)]
                        gx += pixel * sobelX[ky + 1][kx + 1]
                        gy += pixel * sobelY[ky + 1][kx + 1]
                    }
                }
                
                // Calculate gradient magnitude
                let magnitude = Int(sqrt(Double(gx * gx + gy * gy)))
                edges[y * width + x] = magnitude > 50 ? 255 : 0
            }
        }
        
        return edges
    }
}

// MARK: - Utility Functions (Global, accessible to all classes)
func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
    image.draw(in: CGRect(origin: .zero, size: size))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return resizedImage ?? image
}

// MARK: - SmartCropper
/// Intelligent center cropping with edge density analysis for optimal board extraction
class SmartCropper {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "fenify", category: "SmartCropper")
    static func centerCrop(_ bitmap: UIImage) -> UIImage? {
        os_log("Applying intelligent center crop", log: Self.log, type: .debug)
        
        do {
            // Find the optimal crop area by analyzing the image content
            let cropSize = findOptimalCropSize(bitmap)
            let centerX = bitmap.size.width / 2
            let centerY = bitmap.size.height / 2
            
            let left = max(0, centerX - CGFloat(cropSize) / 2)
            let top = max(0, centerY - CGFloat(cropSize) / 2)
            let right = min(bitmap.size.width, left + CGFloat(cropSize))
            let bottom = min(bitmap.size.height, top + CGFloat(cropSize))
            
            let actualWidth = right - left
            let actualHeight = bottom - top
            let actualSize = min(actualWidth, actualHeight)
            
            guard let cgImage = bitmap.cgImage?.cropping(to: CGRect(x: left, y: top, width: actualSize, height: actualSize)) else {
                return safeFallbackCrop(bitmap)
            }
            
            let croppedBitmap = UIImage(cgImage: cgImage)
            
            // Ensure final size is divisible by 8 and large enough for good square extraction
            let targetSize = max(512, Int(actualSize / 8) * 8)
            return resizeImage(croppedBitmap, to: CGSize(width: targetSize, height: targetSize))
            
        } catch {
            os_log("Error in smart crop: %@", log: Self.log, type: .error, error.localizedDescription)
            return safeFallbackCrop(bitmap)
        }
    }
    
    private static func findOptimalCropSize(_ bitmap: UIImage) -> Int {
        let minDimension = min(bitmap.size.width, bitmap.size.height)
        
        // Try different crop percentages and score them
        let cropPercentages: [Float] = [0.95, 0.90, 0.85, 0.80, 0.75]
        var bestScore = 0.0
        var bestSize = Int(minDimension * 0.85)
        
        for percentage in cropPercentages {
            let testSize = Int(minDimension * CGFloat(percentage))
            let score = scoreImageCrop(bitmap, cropSize: testSize)
            
            if score > bestScore {
                bestScore = score
                bestSize = testSize
            }
        }
        
        // Ensure size is divisible by 8
        return (bestSize / 8) * 8
    }
    
    private static func scoreImageCrop(_ bitmap: UIImage, cropSize: Int) -> Double {
        guard let cgImage = bitmap.cgImage else { return 0.0 }
        
        let centerX = Int(bitmap.size.width / 2)
        let centerY = Int(bitmap.size.height / 2)
        let left = centerX - cropSize / 2
        let top = centerY - cropSize / 2
        
        // Sample pixels and calculate edge density
        var edgeCount = 0
        let sampleStep = max(1, cropSize / 64) // Sample 64x64 grid
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: height * width * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return 0.0
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        for y in stride(from: top, to: top + cropSize, by: sampleStep) {
            for x in stride(from: left, to: left + cropSize, by: sampleStep) {
                if x >= 0 && x < width && y >= 0 && y < height {
                    let pixelIndex = (y * width + x) * bytesPerPixel
                    
                    if x + sampleStep < width && y + sampleStep < height {
                        let rightPixelIndex = (y * width + (x + sampleStep)) * bytesPerPixel
                        let bottomPixelIndex = ((y + sampleStep) * width + x) * bytesPerPixel
                        
                        let pixel = Int(pixelData[pixelIndex]) << 16 | Int(pixelData[pixelIndex + 1]) << 8 | Int(pixelData[pixelIndex + 2])
                        let rightPixel = Int(pixelData[rightPixelIndex]) << 16 | Int(pixelData[rightPixelIndex + 1]) << 8 | Int(pixelData[rightPixelIndex + 2])
                        let bottomPixel = Int(pixelData[bottomPixelIndex]) << 16 | Int(pixelData[bottomPixelIndex + 1]) << 8 | Int(pixelData[bottomPixelIndex + 2])
                        
                        if ImageProcessor.colorDifference(pixel, rightPixel) > 30 ||
                           ImageProcessor.colorDifference(pixel, bottomPixel) > 30 {
                            edgeCount += 1
                        }
                    }
                }
            }
        }
        
        return Double(edgeCount)
    }
    
    private static func safeFallbackCrop(_ bitmap: UIImage) -> UIImage {
        let minDimension = min(bitmap.size.width, bitmap.size.height)
        let size = minDimension * 0.85 // Take 85% to avoid borders
        let x = (bitmap.size.width - size) / 2
        let y = (bitmap.size.height - size) / 2
        
        guard let cgImage = bitmap.cgImage?.cropping(to: CGRect(x: x, y: y, width: size, height: size)) else {
            return bitmap
        }
        
        let croppedBitmap = UIImage(cgImage: cgImage)
        return resizeImage(croppedBitmap, to: CGSize(width: 512, height: 512))
    }
}

// MARK: - PerspectiveCorrector
class PerspectiveCorrector {
    struct PointF {
        let x: Float
        let y: Float
    }
    
    static func applyCorrection(_ bitmap: UIImage, corners: [Float]) -> UIImage? {
        guard corners.count >= 8 else { return nil }
        
        // Extract corner coordinates
        let topLeft = PointF(x: corners[0], y: corners[1])
        let topRight = PointF(x: corners[2], y: corners[3])
        let bottomRight = PointF(x: corners[4], y: corners[5])
        let bottomLeft = PointF(x: corners[6], y: corners[7])
        
        // For now, return a simple crop of the detected area
        let left = max(0, Int(corners[0]))
        let top = max(0, Int(corners[1]))
        let right = min(Int(bitmap.size.width), Int(corners[4]))
        let bottom = min(Int(bitmap.size.height), Int(corners[5]))
        
        let cropWidth = right - left
        let cropHeight = bottom - top
        
        if cropWidth > 0 && cropHeight > 0 {
            guard let cgImage = bitmap.cgImage?.cropping(to: CGRect(x: left, y: top, width: cropWidth, height: cropHeight)) else {
                return nil
            }
            
            let croppedBitmap = UIImage(cgImage: cgImage)
            
            // Resize to square, ensuring divisible by 8
            let finalSize = max(512, (min(cropWidth, cropHeight) / 8) * 8)
            return resizeImage(croppedBitmap, to: CGSize(width: finalSize, height: finalSize))
        }
        
        return nil
    }
}

// MARK: - BoardDetector
/// Main board detection class using edge detection and perspective correction
class BoardDetector {
    static let TAG = "BoardDetector"
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "fenify", category: TAG)
    private static let MIN_BOARD_SIZE_RATIO: Float = 0.3
    private static let EDGE_THRESHOLD = 50
    private static let MIN_EDGE_COUNT = 1000
    
    func detectAndCorrect(_ bitmap: UIImage) -> UIImage? {
        do {
            os_log("Starting advanced board detection", log: Self.log, type: .debug)
            
            // Convert to grayscale for edge detection
            guard let grayscale = ImageProcessor.convertToGrayscale(bitmap) else {
                os_log("Failed to convert to grayscale", log: Self.log, type: .default)
                return SmartCropper.centerCrop(bitmap)
            }
            
            let width = Int(bitmap.size.width)
            let height = Int(bitmap.size.height)
            
            // Detect edges
            let edges = EdgeDetector.detectEdges(grayscale, width: width, height: height)
            
            // Find the largest rectangular contour (the chessboard)
            if let boardCorners = findChessboardCorners(edges, width: width, height: height) {
                os_log("Found board corners: %@", log: Self.log, type: .debug, String(describing: boardCorners))
                
                // Apply perspective correction to get perfect square board
                if let correctedBoard = PerspectiveCorrector.applyCorrection(bitmap, corners: boardCorners) {
                    os_log("Perspective correction successful", log: Self.log, type: .debug)
                    return correctedBoard
                }
            }
            
            // Fallback: Use center cropping
            os_log("Using fallback cropping", log: Self.log, type: .debug)
            return SmartCropper.centerCrop(bitmap)
            
        } catch {
            os_log("Error in board detection: %@", log: Self.log, type: .error, error.localizedDescription)
            return SmartCropper.centerCrop(bitmap)
        }
    }
    
    private func findChessboardCorners(_ edges: [Int], width: Int, height: Int) -> [Float]? {
        do {
            // Look for the largest rectangular contour
            var minX = width
            var maxX = 0
            var minY = height
            var maxY = 0
            var edgeCount = 0
            
            for y in 0..<height {
                for x in 0..<width {
                    if edges[y * width + x] > 128 {
                        minX = min(minX, x)
                        maxX = max(maxX, x)
                        minY = min(minY, y)
                        maxY = max(maxY, y)
                        edgeCount += 1
                    }
                }
            }
            
            // Validate the detected area
            if edgeCount > BoardDetector.MIN_EDGE_COUNT &&
               Float(maxX - minX) > Float(width) * BoardDetector.MIN_BOARD_SIZE_RATIO &&
               Float(maxY - minY) > Float(height) * BoardDetector.MIN_BOARD_SIZE_RATIO {
                
                // Add padding to ensure full board view
                let padding = Float(min(width, height)) * 0.05
                minX = max(0, minX - Int(padding))
                maxX = min(width - 1, maxX + Int(padding))
                minY = max(0, minY - Int(padding))
                maxY = min(height - 1, maxY + Int(padding))
                
                // Return corners in clockwise order
                return [
                    Float(minX), Float(minY),  // top-left
                    Float(maxX), Float(minY),  // top-right
                    Float(maxX), Float(maxY),  // bottom-right
                    Float(minX), Float(maxY)   // bottom-left
                ]
            }
            
            return nil
            
        } catch {
            os_log("Error finding corners: %@", log: Self.log, type: .error, error.localizedDescription)
            return nil
        }
    }
}
