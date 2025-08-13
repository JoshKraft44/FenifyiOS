# Fenify

# Created by Joshua Thomas Kraft - May 17 2025

**Fenify** is a powerful offline mobile chess analysis app that uses computer vision to convert digital chess board photos into interactive positions for deep analysis with the Stockfish engine. 

---

## Key Features

### **Advanced Image Processing**
- **Smart Board Detection**: Automatically detects and corrects chessboard perspective using sophisticated computer vision algorithms
- **Intelligent Cropping**: Advanced cropping algorithms that find optimal board boundaries
- **Real-time Processing**: Upload photos from camera or gallery for instant analysis
- **Debug Mode**: Extract individual squares for detailed inspection and troubleshooting

### **AI-Powered Piece Recognition**
- **Custom TensorFlow Lite Model**: On-device piece classification with 13 classes (6 black pieces, 6 white pieces, + empty squares)
- **High Accuracy**: Trained model specifically optimized for chess piece detection
- **Offline Inference**: No internet required - all ML processing happens locally
- **Auto-Orientation**: Automatically detects correct board orientation for accurate analysis

### **Professional Chess Analysis**
- **Stockfish Integration**: Full Stockfish 17 engine running in isolated threads for maximum performance
- **Real-time Analysis**: Continuous position evaluation with multiple depth levels
- **Multi-PV Analysis**: See the top 3 best moves with evaluations
- **Move Navigation**: Step through game history with full move tracking
- **Position Validation**: Comprehensive FEN validation and illegal position detection

### **Interactive Position Editing**
- **Visual Board Editor**: Tap-and-drop piece placement with intuitive controls
- **Multiple Edit Modes**: Tap & Replace, place new pieces, or remove pieces
- **Castling Rights**: Full control over castling availability for both sides
- **Turn Selection**: Choose which side to move
- **Smart Validation**: Real-time position validation while editing with helpful error messages

### **Position Management**
- **Save Positions**: Store analyzed positions for later review
- **Position History**: Browse through saved games and positions
- **FEN Support**: Manual FEN input for direct position analysis
- **Quick Positions**: Access common openings and positions instantly

---

## Getting Started

### **Prerequisites**
- Flutter SDK (>=3.0.0)
- Xcode for device deployment

### **Installation**

1. **Clone the repository**
   ```bash
   git clone https://github.com/joshkraft44/Fenify.git
   cd fenify
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run on device**
   ```bash
   flutter run
   ```

### **Build for Production**

```bash
flutter build ios --release
```
---

## How It Works

### **1. Image Capture & Processing**
- User uploads chess position photo from camera or gallery
- Advanced board detection algorithms locate and correct chessboard perspective
- Image is automatically oriented and cropped for optimal square extraction

### **2. AI Piece Recognition**
- Board is divided into 64 individual squares
- Each square is processed by the custom TensorFlow Lite model
- Model classifies pieces with confidence scores and validates piece distribution

### **3. Position Validation & Analysis**
- Generated FEN is validated for chess rule compliance
- Invalid positions are flagged with detailed error messages and editing suggestions
- Valid positions are immediately sent to Stockfish for analysis

### **4. Real-time Chess Analysis**
- Stockfish engine provides continuous position evaluation
- Multiple lines of analysis with move recommendations
- Interactive board with move highlighting and navigation

---

## Design Philosophy

Fenify combines computer vision with professional chess analysis tools, wrapped in an intuitive mobile interface. The app prioritizes:

- **Offline Functionality**: Complete independence from internet connectivity
- **Performance**: Optimized ML models and efficient engine integration
- **Usability**: Clean, modern interface with professional chess features
- **Reliability**: Comprehensive error handling and validation throughout

---

## Supported Platforms

- **iOS**: iOS 11.0+

---

## Acknowledgments

- **Stockfish Team**: For the incredible chess engine
- **TensorFlow Team**: For the machine learning framework
- **Flutter Community**: For the amazing cross-platform framework
- **Chess.com & Lichess**: For inspiration and the wonderful dartchess package. 

## Outlook

- **Future Updates**: I will continue to make changes and improvements to the app as time goes on. I am currently in the process of completing the final necessary components and requirements before app store and play store submission. 
- **Contact Me**: For any inquiries, please contact me by email @ joshua.kraft@ucalgary.ca