# Heartbeat Smart Glass

A Flutter application that integrates with Frame smart glasses to automatically capture photos when your heart rate exceeds a configurable threshold. Perfect for capturing those high-intensity moments during workouts, exciting events, or any situation where your heart rate spikes.

## 🚀 Features

### Smart Heart Rate Monitoring
- **Bluetooth Heart Rate Strap Support**: Compatible with popular heart rate monitors (Garmin, Polar, Wahoo, etc.)
- **Real-time Heart Rate Display**: Live BPM monitoring with data quality indicators
- **Configurable Threshold**: Set custom heart rate thresholds (60-200 BPM)
- **Auto-capture**: Automatically takes photos when heart rate exceeds threshold
- **Data Quality Monitoring**: Track connection stability and data accuracy

### Frame Smart Glass Integration
- **Seamless Connection**: Auto-connects to Frame smart glasses
- **Manual & Auto Capture**: Double-tap gesture or automatic heart rate triggered capture
- **Live Preview**: Real-time display on Frame glasses
- **Battery Monitoring**: Track Frame device battery status

### Photo Management
- **Instant Gallery**: View captured photos with metadata
- **Detailed Metadata**: Timestamp, exposure settings, and capture context
- **Easy Sharing**: Share photos with metadata via system share sheet
- **JPEG Output**: High-quality image storage and sharing

## 📱 Screenshots

*Note: Add screenshots of the app interface, Frame glasses, and heart rate monitoring in action*

## 🛠️ Setup & Installation

### Prerequisites
- Flutter SDK (3.0.6 or higher)
- Frame smart glasses
- Bluetooth heart rate monitor strap
- Android/iOS device with Bluetooth LE support

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/heartbeat-smart-glass.git
   cd heartbeat-smart-glass
   ```

2. **Install Flutter dependencies**
   ```bash
   cd flutter_app
   flutter pub get
   ```

3. **Configure Frame SDK**
   - Ensure your Frame glasses are paired and connected
   - Follow [Frame SDK documentation](https://frame.readme.io) for device setup

4. **Run the application**
   ```bash
   flutter run
   ```

## 📋 Dependencies

The app uses the following key dependencies:

- `simple_frame_app: ^7.1.0` - Frame smart glass SDK
- `flutter_blue_plus: ^1.35.5` - Bluetooth Low Energy communication
- `frame_msg: ^2.0.0` - Frame messaging protocol
- `share_plus: ^11.0.0` - System sharing capabilities
- `logging: ^1.3.0` - Logging framework
- `image: ^4.5.4` - Image processing

## 🔧 Configuration

### Heart Rate Monitor Setup

1. **Put your heart rate strap in pairing mode**
   - Turn on your Bluetooth heart rate monitor
   - Ensure it's in pairing/discoverable mode

2. **Connect through the app**
   - Open the app and tap the heart icon in the top-right
   - Or use the Settings drawer → Heart Rate Settings → Connect Heart Rate Strap
   - Select your device from the list

3. **Configure threshold**
   - Go to Settings → Heart Rate Settings → Configure Threshold
   - Set your desired BPM threshold (default: 100 BPM)
   - Enable monitoring to activate auto-capture

### Frame Glasses Setup

1. **Pair your Frame glasses** with your phone via Bluetooth
2. **Launch the app** - it will automatically detect and connect to Frame
3. **Follow on-screen instructions** for initial setup

## 🎯 Usage

### Basic Operation

1. **Start the app** - it will automatically connect to Frame glasses
2. **Connect heart rate monitor** using the heart icon or settings
3. **Enable monitoring** to activate automatic photo capture
4. **Set your threshold** based on your target heart rate zone

### Capture Methods

- **Automatic**: Photos are captured when heart rate exceeds threshold
- **Manual**: Use the camera button in the app
- **Gesture**: Double-tap on Frame glasses

### Viewing Photos

- **Gallery**: Scroll through captured photos in the main screen
- **Metadata**: Tap photos to view detailed capture information
- **Share**: Tap any photo to share via system share sheet

## 📊 Heart Rate Zones

Common heart rate zones for reference:

- **Resting**: 60-100 BPM
- **Fat Burn**: 60-70% of max HR
- **Cardio**: 70-85% of max HR
- **Peak**: 85-100% of max HR

*Calculate your max HR: 220 - your age*

## 🛡️ Troubleshooting

### Common Issues

**Heart Rate Monitor Not Connecting**
- Ensure Bluetooth is enabled on your phone
- Check that your heart rate strap is in pairing mode
- Try restarting the app and re-scanning for devices

**Frame Glasses Not Detected**
- Verify Frame glasses are charged and powered on
- Check Bluetooth connection in phone settings
- Restart the app to retry auto-connection

**No Photos Capturing**
- Verify heart rate monitoring is enabled
- Check that your heart rate exceeds the set threshold
- Ensure Frame glasses are properly connected

**Poor Heart Rate Data Quality**
- Ensure heart rate strap is properly positioned
- Check for interference from other Bluetooth devices
- Verify strap battery level

## 🔋 Battery Management

- **Frame Glasses**: Monitor battery level via the app status bar
- **Heart Rate Monitor**: Check your device's battery indicator
- **Phone**: Heart rate monitoring may increase battery usage

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Frame team](https://frame.readme.io) for the smart glasses SDK
- Simple_frame_app by CitizenOneX

---

**Note**: This app requires physical hardware (Frame smart glasses and Bluetooth heart rate monitor) to function fully. Demo mode may be available for development purposes.