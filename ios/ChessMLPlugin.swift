//
//  ChessMLPlugin.swift
//  Runner
//
//  Created by Josh Kraft on 2025-07-23.
//

import Flutter
import UIKit
import TensorFlowLite
import CoreGraphics
import os.log

/// Flutter plugin for TensorFlow Lite chess piece classification and board image processing
public class ChessMLPlugin: NSObject, FlutterPlugin {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "fenify", category: "ChessMLPlugin")
    private var interpreter: Interpreter?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "chess_ml_channel", binaryMessenger: registrar.messenger())
        let instance = ChessMLPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "loadModel":
            loadModel(call: call, result: result)
        case "classifyImage":
            classifyImage(call: call, result: result)
        case "classifyBatch":
            classifyBatch(call: call, result: result)
        case "disposeModel":
            disposeModel(result: result)
        case "processChessboard":
            processChessboard(call: call, result: result)
        case "extractSquares":
            extractSquares(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func loadModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        os_log("Loading TensorFlow Lite model", log: Self.log, type: .debug)
        
        do {
            // Get model path from Documents directory (iOS-safe location)
            guard let modelPath = getModelPath() else {
                throw NSError(domain: "ChessMLPlugin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get model path"])
            }
            
            os_log("Using model path: %@", log: Self.log, type: .debug, modelPath)
            
            // Try different interpreter configurations for compatibility
            let compatibilityOptions: [Interpreter.Options] = [
                // Latest version configuration
                {
                    var options = Interpreter.Options()
                    options.threadCount = 2
                    options.isXNNPackEnabled = true
                    return options
                }(),
                // Fallback configuration
                {
                    var options = Interpreter.Options()
                    options.threadCount = 1
                    options.isXNNPackEnabled = false
                    return options
                }(),
                // Basic configuration
                Interpreter.Options()
            ]
            
            var success = false
            for (index, options) in compatibilityOptions.enumerated() {
                do {
                    os_log("Trying interpreter configuration %d", log: Self.log, type: .debug, index + 1)
                    
                    interpreter = try Interpreter(modelPath: modelPath, options: options)
                    try interpreter?.allocateTensors()
                    
                    os_log("Model loaded successfully with config %d", log: Self.log, type: .debug, index + 1)
                    os_log("Model input shape: %@", log: Self.log, type: .debug, String(describing: try interpreter?.input(at: 0).shape ?? []))
                    os_log("Model output shape: %@", log: Self.log, type: .debug, String(describing: try interpreter?.output(at: 0).shape ?? []))
                    
                    success = true
                    break
                } catch {
                    os_log("Config %d failed: %@", log: Self.log, type: .default, index + 1, error.localizedDescription)
                    if index == compatibilityOptions.count - 1 {
                        throw error
                    }
                }
            }
            
            // Test the model after successful loading
            if success {
                testSingleSquareClassification()
            }
            
            result(success)
        } catch {
            os_log("Error loading model: %@", log: Self.log, type: .error, error.localizedDescription)
            result(false)
        }
    }
    
    private func getModelPath() -> String? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let modelPath = "\(documentsPath)/piece_classifier.tflite"
        
        // Check if model already exists in Documents
        if FileManager.default.fileExists(atPath: modelPath) {
            os_log("Model found in Documents directory", log: Self.log, type: .debug)
            return modelPath
        }
        
        // Copy model from bundle to Documents directory
        guard let bundlePath = Bundle.main.path(forResource: "piece_classifier", ofType: "tflite") else {
            os_log("Model not found in bundle", log: Self.log, type: .error)
            return nil
        }
        
        do {
            try FileManager.default.copyItem(atPath: bundlePath, toPath: modelPath)
            os_log("Model copied to Documents directory", log: Self.log, type: .debug)
            return modelPath
        } catch {
            os_log("Failed to copy model: %@", log: Self.log, type: .error, error.localizedDescription)
            
            // Fallback: try to use bundle path directly
            os_log("Falling back to bundle path", log: Self.log, type: .default)
            return bundlePath
        }
    }
    
    private func classifyImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let interpreter = interpreter else {
            result([
                "success": false,
                "error": "Model not loaded"
            ])
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let imageBytes = args["imageBytes"] as? FlutterStandardTypedData else {
            result([
                "success": false,
                "error": "No image data provided"
            ])
            return
        }
        
        do {
            let classificationResult = try classifyImageData(imageBytes.data, interpreter: interpreter)
            result([
                "success": true,
                "classIndex": classificationResult.0,
                "confidence": classificationResult.1
            ])
        } catch {
            os_log("Error classifying image: %@", log: Self.log, type: .error, error.localizedDescription)
            result([
                "success": false,
                "error": error.localizedDescription
            ])
        }
    }
    
    private func classifyBatch(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let interpreter = interpreter else {
            os_log("Model not loaded, returning empty squares", log: Self.log, type: .default)
            if let args = call.arguments as? [String: Any],
               let imageList = args["imageList"] as? [FlutterStandardTypedData] {
                let resultList = Array(repeating: 6, count: imageList.count) // 6 = empty square
                result(resultList)
            } else {
                result([])
            }
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let imageList = args["imageList"] as? [FlutterStandardTypedData] else {
            result([])
            return
        }
        
        var results: [Int] = []
        for (index, imageData) in imageList.enumerated() {
            do {
                let classificationResult = try classifyImageData(imageData.data, interpreter: interpreter)
                results.append(classificationResult.0)
                os_log("Square %d -> class %d (confidence: %.3f)", log: Self.log, type: .debug, index, classificationResult.0, classificationResult.1)
            } catch {
                os_log("Error classifying square %d: %@", log: Self.log, type: .error, index, error.localizedDescription)
                results.append(6) // Default to empty square
            }
        }
        
        os_log("Batch classification complete: %@", log: Self.log, type: .debug, String(describing: results))
        result(results)
    }
    
    private func disposeModel(result: @escaping FlutterResult) {
        os_log("Disposing model...", log: Self.log, type: .debug)
        interpreter = nil
        result(true)
    }
    
    private func processChessboard(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let interpreter = interpreter,
              let args = call.arguments as? [String: Any],
              let imageBytes = args["imageBytes"] as? FlutterStandardTypedData else {
            os_log("No image data or interpreter not initialized", log: Self.log, type: .default)
            result("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
            return
        }
        
        do {
            os_log("Processing full chessboard image", log: Self.log, type: .debug)
            let fen = try processChessboardImage(imageBytes.data, interpreter: interpreter)
            result(fen)
        } catch {
            os_log("Error processing chessboard: %@", log: Self.log, type: .error, error.localizedDescription)
            result("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        }
    }
    
    private func extractSquares(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imageBytes = args["imageBytes"] as? FlutterStandardTypedData else {
            result([
                "success": false,
                "error": "No image data provided"
            ])
            return
        }
        
        do {
            os_log("Extracting squares for debugging", log: Self.log, type: .debug)
            let squaresPaths = try extractAndSaveSquares(imageBytes.data)
            result([
                "success": true,
                "squaresPaths": squaresPaths
            ])
        } catch {
            os_log("Error extracting squares: %@", log: Self.log, type: .error, error.localizedDescription)
            result([
                "success": false,
                "error": error.localizedDescription
            ])
        }
    }
    
    // MARK: - Helper Methods
    
    private func classifyImageData(_ imageData: Data, interpreter: Interpreter) throws -> (Int, Float) {
        // Convert data to UIImage
        guard let uiImage = UIImage(data: imageData) else {
            throw NSError(domain: "ChessMLPlugin", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create UIImage from data"])
        }
        
        // Resize to 64x64
        let resizedImage = resizeImage(uiImage, to: CGSize(width: 64, height: 64))
        
        // Convert to input tensor format (NHWC: [1, 64, 64, 3])
        let inputData = try convertImageToInputData(resizedImage)
        
        // Copy data to input tensor
        try interpreter.copy(inputData, toInputAt: 0)
        
        // Run inference
        try interpreter.invoke()
        
        // Get output tensor
        let outputTensor = try interpreter.output(at: 0)
        let outputData = outputTensor.data
        
        // Convert output to float array
        let outputArray = outputData.toArray(type: Float32.self)
        
        // Find class with highest confidence
        var maxIndex = 0
        var maxConfidence: Float = outputArray[0]
        
        for i in 1..<outputArray.count {
            if outputArray[i] > maxConfidence {
                maxConfidence = outputArray[i]
                maxIndex = i
            }
        }
        
        // Log classification details
        let pieceLabels = ["bB", "bK", "bN", "bP", "bQ", "bR", "empty", "wB", "wK", "wN", "wP", "wQ", "wR"]
        let predictedLabel = maxIndex < pieceLabels.count ? pieceLabels[maxIndex] : "unknown"
        
        if maxConfidence > 0.1 {
            os_log("Predicted %@ (index: %d, confidence: %.4f)", log: Self.log, type: .debug, predictedLabel, maxIndex, maxConfidence)
        }
        
        return (maxIndex, maxConfidence)
    }
    
    /// Convert UIImage to normalized tensor data in NHWC format [batch, height, width, channels]
    private func convertImageToInputData(_ image: UIImage) throws -> Data {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "ChessMLPlugin", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }
        
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
            throw NSError(domain: "ChessMLPlugin", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Convert to normalized float data in NHWC format
        var inputData = Data()
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                // Normalize pixel values to [-1, 1] range as expected by model
                var r = Float(pixelData[pixelIndex]) / 127.5 - 1.0
                var g = Float(pixelData[pixelIndex + 1]) / 127.5 - 1.0
                var b = Float(pixelData[pixelIndex + 2]) / 127.5 - 1.0
                
                inputData.append(Data(bytes: &r, count: MemoryLayout<Float>.size))
                inputData.append(Data(bytes: &g, count: MemoryLayout<Float>.size))
                inputData.append(Data(bytes: &b, count: MemoryLayout<Float>.size))
            }
        }
        
        return inputData
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? image
    }
    
    private func testSingleSquareClassification() {
        os_log("=== STARTING SINGLE SQUARE TEST ===", log: Self.log, type: .debug)
        
        guard let interpreter = interpreter else {
            os_log("No interpreter available for test", log: Self.log, type: .default)
            return
        }
        
        do {
            // Create a simple test image (solid black square)
            let size = CGSize(width: 64, height: 64)
            UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let testImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            guard let testImage = testImage,
                  let testData = testImage.pngData() else {
                os_log("Failed to create test image", log: Self.log, type: .default)
                return
            }
            
            // Test the classification
            let (classIndex, confidence) = try classifyImageData(testData, interpreter: interpreter)
            
            // Show results
            let pieceLabels = ["bB", "bK", "bN", "bP", "bQ", "bR", "empty", "wB", "wK", "wN", "wP", "wQ", "wR"]
            let predictedLabel = classIndex < pieceLabels.count ? pieceLabels[classIndex] : "unknown"
            
            os_log("Test square result: %@ (index: %d, confidence: %.3f)", log: Self.log, type: .debug, predictedLabel, classIndex, confidence)
            
        } catch {
            os_log("Test failed: %@", log: Self.log, type: .error, error.localizedDescription)
        }
        
        os_log("=== END SINGLE SQUARE TEST ===", log: Self.log, type: .debug)
    }
    
    private func processChessboardImage(_ imageData: Data, interpreter: Interpreter) throws -> String {
        os_log("Starting chessboard image processing", log: Self.log, type: .debug)
        
        guard let originalImage = UIImage(data: imageData) else {
            throw NSError(domain: "ChessMLPlugin", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create UIImage"])
        }
        
        os_log("Original image size: %@", log: Self.log, type: .debug, NSCoder.string(for:originalImage.size))
        
        // Detect and correct chessboard
        guard let correctedImage = detectAndCorrectChessboard(originalImage) else {
            os_log("Failed to detect chessboard, using fallback position", log: Self.log, type: .default)
            return "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        }
        
        os_log("Board detection successful, corrected size: %@", log: Self.log, type: .debug, NSCoder.string(for:originalImage.size))
        
        // Step 2: Extract 64 squares
        let squares = extractSquaresFromCorrectedBoard(correctedImage)
        os_log("Extracted %d squares", log: Self.log, type: .debug, squares.count)
        
        // Step 3: Classify each square
        var classifications: [Int] = []
        var confidences: [Float] = []
        
        os_log("=== DETAILED SQUARE CLASSIFICATION ===", log: Self.log, type: .debug)
        
        for (index, squareImage) in squares.enumerated() {
            do {
                let (classIndex, confidence) = try classifySquareImage(squareImage, interpreter: interpreter)
                classifications.append(classIndex)
                confidences.append(confidence)
                
                let row = index / 8
                let col = index % 8
                let chessSquare = getChessSquareNotation(row: row, col: col)
                let pieceLabels = ["bB", "bK", "bN", "bP", "bQ", "bR", "empty", "wB", "wK", "wN", "wP", "wQ", "wR"]
                let predictedPiece = classIndex < pieceLabels.count ? pieceLabels[classIndex] : "unknown"
                
                if index < 16 {
                    os_log("Square %d (%@) -> %@ (confidence: %.3f)", log: Self.log, type: .debug, index, chessSquare, predictedPiece, confidence)
                }
            } catch {
                os_log("Error classifying square %d: %@", log: Self.log, type: .error, index, error.localizedDescription)
                classifications.append(6) // Default to empty
                confidences.append(0.0)
            }
        }
        
        // Step 4: Analyze distribution
        var pieceCounts: [Int: Int] = [:]
        for classIndex in classifications {
            pieceCounts[classIndex, default: 0] += 1
        }
        
        os_log("=== PIECE DISTRIBUTION ===", log: Self.log, type: .debug)
        let pieceLabels = ["bB", "bK", "bN", "bP", "bQ", "bR", "empty", "wB", "wK", "wN", "wP", "wQ", "wR"]
        for (classIndex, count) in pieceCounts.sorted(by: { $0.value > $1.value }) {
            let label = classIndex < pieceLabels.count ? pieceLabels[classIndex] : "unknown"
            os_log("%@: %d squares", log: Self.log, type: .debug, label, count)
        }
        
        let emptySquares = pieceCounts[6, default: 0]
        let totalPieces = 64 - emptySquares
        os_log("Empty squares: %d, Pieces: %d", log: Self.log, type: .debug, emptySquares, totalPieces)
        
        if totalPieces > 40 {
            os_log("WARNING: Too many pieces detected (%d), possible misclassification", log: Self.log, type: .default, totalPieces)
        } else if totalPieces < 10 {
            os_log("WARNING: Too few pieces detected (%d), possible misclassification", log: Self.log, type: .default, totalPieces)
        }
        
        // Step 5: Convert to FEN
        let fen = classificationsToFen(classifications)
        os_log("Generated FEN: %@", log: Self.log, type: .info, fen)
        
        return fen
    }
    
    private func detectAndCorrectChessboard(_ image: UIImage) -> UIImage? {
        // Use BoardDetector instead of simple center crop
        let boardDetector = BoardDetector()
        return boardDetector.detectAndCorrect(image)
    }
    
    private func extractSquaresFromCorrectedBoard(_ image: UIImage) -> [UIImage] {
        var squares: [UIImage] = []
        let boardSize = image.size.width
        let squareSize = boardSize / 8
        
        os_log("Extracting squares - Board size: %.1f, Square size: %.1f", log: Self.log, type: .debug, boardSize, squareSize)
        
        guard let cgImage = image.cgImage else {
            return squares
        }
        
        for row in 0..<8 {
            for col in 0..<8 {
                let x = CGFloat(col) * squareSize
                let y = CGFloat(row) * squareSize
                
                let rect = CGRect(x: x, y: y, width: squareSize, height: squareSize)
                
                if let croppedCGImage = cgImage.cropping(to: rect) {
                    let square = UIImage(cgImage: croppedCGImage)
                    let resizedSquare = resizeImage(square, to: CGSize(width: 64, height: 64))
                    squares.append(resizedSquare)
                    
                    if row == 0 {
                        let squareIndex = row * 8 + col
                        let chessSquare = getChessSquareNotation(row: row, col: col)
                        os_log("Square %d at pixel (%.1f,%.1f) -> %@", log: Self.log, type: .debug, squareIndex, x, y, chessSquare)
                    }
                }
            }
        }
        
        os_log("Square extraction completed", log: Self.log, type: .debug)
        return squares
    }
    
    private func classifySquareImage(_ image: UIImage, interpreter: Interpreter) throws -> (Int, Float) {
        guard let imageData = image.pngData() else {
            throw NSError(domain: "ChessMLPlugin", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get image data"])
        }
        
        return try classifyImageData(imageData, interpreter: interpreter)
    }
    
    private func getChessSquareNotation(row: Int, col: Int) -> String {
        let files = "abcdefgh"
        let ranks = "87654321"
        let fileChar = String(files[files.index(files.startIndex, offsetBy: col)])
        let rankChar = String(ranks[ranks.index(ranks.startIndex, offsetBy: row)])
        return "\(fileChar)\(rankChar)"
    }
    
    private func classificationsToFen(_ classifications: [Int]) -> String {
        os_log("Starting FEN generation from classifications", log: Self.log, type: .debug)
        
        // Piece mapping that matches the model's label order
        let pieceMap: [Int: String] = [
            0: "b",   // bB (black bishop)
            1: "k",   // bK (black king)
            2: "n",   // bN (black knight)
            3: "p",   // bP (black pawn)
            4: "q",   // bQ (black queen)
            5: "r",   // bR (black rook)
            6: "",    // empty square
            7: "B",   // wB (white bishop)
            8: "K",   // wK (white king)
            9: "N",   // wN (white knight)
            10: "P",  // wP (white pawn)
            11: "Q",  // wQ (white queen)
            12: "R"   // wR (white rook)
        ]
        
        os_log("Processing %d square classifications", log: Self.log, type: .debug, classifications.count)
        
        var ranks: [String] = []
        
        for rank in 0..<8 {
            var rankStr = ""
            var emptyCount = 0
            
            // Rank processing - reduced logging for performance
            
            for file in 0..<8 {
                let index = rank * 8 + file
                let classIndex = index < classifications.count ? classifications[index] : 6
                let piece = pieceMap[classIndex] ?? ""
                let chessSquare = getChessSquareNotation(row: rank, col: file)
                
                // Square classification logged at higher level for performance
                
                if piece.isEmpty {
                    emptyCount += 1
                } else {
                    if emptyCount > 0 {
                        rankStr += String(emptyCount)
                        emptyCount = 0
                    }
                    rankStr += piece
                }
            }
            
            if emptyCount > 0 {
                rankStr += String(emptyCount)
            }
            
            let rankFen = rankStr
            os_log("Rank %d FEN: %@", log: Self.log, type: .debug, 8-rank, rankFen)
            ranks.append(rankFen)
        }
        
        let fenPosition = ranks.joined(separator: "/")
        let completeFen = "\(fenPosition) w KQkq - 0 1"
        
        os_log("FEN generation complete: %@", log: Self.log, type: .info, completeFen)
        
        return completeFen
    }
    
    private func extractAndSaveSquares(_ imageData: Data) throws -> [String] {
        os_log("Starting square extraction for debugging", log: Self.log, type: .debug)
        
        guard let originalImage = UIImage(data: imageData) else {
            throw NSError(domain: "ChessMLPlugin", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to create UIImage"])
        }
        
        os_log("Original image size: %@", log: Self.log, type: .debug, NSCoder.string(for:originalImage.size))
        
        guard let correctedImage = detectAndCorrectChessboard(originalImage) else {
            os_log("Failed to detect chessboard for square extraction", log: Self.log, type: .error)
            return []
        }
        
        let squares = extractSquaresFromCorrectedBoard(correctedImage)
        os_log("Extracted %d squares for saving", log: Self.log, type: .debug, squares.count)
        
        var squaresPaths: [String] = []
        
        // Get documents directory
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let debugDir = "\(documentsPath)/debug_squares"
        
        // Create directory
        try FileManager.default.createDirectory(atPath: debugDir, withIntermediateDirectories: true, attributes: nil)
        
        for (index, squareImage) in squares.enumerated() {
            let filename = "square_\(index)_row\(index/8)_col\(index%8).png"
            let filePath = "\(debugDir)/\(filename)"
            
            if let imageData = squareImage.pngData() {
                try imageData.write(to: URL(fileURLWithPath: filePath))
                squaresPaths.append(filePath)
                
                // Also classify and log the square
                if let interpreter = interpreter {
                    do {
                        let (classIndex, confidence) = try classifySquareImage(squareImage, interpreter: interpreter)
                        let pieceLabels = ["bB", "bK", "bN", "bP", "bQ", "bR", "empty", "wB", "wK", "wN", "wP", "wQ", "wR"]
                        let predictedPiece = classIndex < pieceLabels.count ? pieceLabels[classIndex] : "unknown"
                        os_log("Debug square %d (%d,%d) -> %@ (confidence: %.3f)", log: Self.log, type: .debug, index, index/8, index%8, predictedPiece, confidence)
                    } catch {
                        os_log("Error classifying saved square %d: %@", log: Self.log, type: .error, index, error.localizedDescription)
                    }
                }
            }
        }
        
        os_log("Saved %d squares to %@", log: Self.log, type: .debug, squaresPaths.count, debugDir)
        return squaresPaths
    }
}

// MARK: - Data Extension
extension Data {
    func toArray<T>(type: T.Type) -> [T] where T: ExpressibleByIntegerLiteral {
        var array = Array<T>(repeating: 0, count: self.count/MemoryLayout<T>.stride)
        _ = array.withUnsafeMutableBytes { self.copyBytes(to: $0) }
        return array
    }
}
