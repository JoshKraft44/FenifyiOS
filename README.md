# Fenify
# Created by Joshua Thomas Kraft

**Fenify** is a mobile chess analysis app that uses computer vision to convert digital chess board photos into interactive positions for analysis with the Stockfish engine. 

---

## Key Features

### **Advanced Image Processing**
- **Board Detection**: Automatically detects and corrects chessboard perspective using computer vision
- **Real-time & On-Devce Processing**: Upload photos from camera or gallery for instant analysis
- **Debug Mode**: Extract individual square image crops for detailed inspection and troubleshooting

### **ML-Powered Piece Recognition**
- **Custom TensorFlow Lite Model**: On-device piece classification
- **High Accuracy**: Trained model specifically optimized for chess piece detection
- **Offline Inference**: No internet required - all ML processing happens locally
- **Auto-Orientation**: Interprets orientation to avoid consistent board flipping

### **Professional Chess Analysis**
- **Stockfish Integration**: Full Stockfish 17 engine running in isolated threads for maximum performance
- **Real-time Analysis**: Continuous position evaluation with multiple depth levels
- **Multi-PV Analysis**: See the top 3 best moves with evaluations
- **Move Navigation**: Step through game history with full move tracking
- **Position Validation**: Comprehensive FEN validation and illegal position detection

### **Interactive Position Editing**
- **Visual Board Editor**: Tap-and-drop piece placement with intuitive controls
- **Multiple Edit Modes**: Tap-to-Replace, place new pieces, or remove pieces
- **Castling Rights**: Full control over castling availability for both sides
- **Turn Selection**: Choose which side to move
- **Smart Validation**: Position validation before saving with descriptive error messages

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
- Board detection algorithms locate and correct chessboard perspective
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

## Supported Platforms

- **iOS**: iOS 11.0+

## Outlook

- **Future Updates**: I will continue to make changes and improvements to the app as time goes on. I am currently in the process of completing the final necessary components and requirements before app store and play store submission. 
- **Contact Me**: For any inquiries, please contact me by email @ joshua.kraft@ucalgary.ca
