import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_frame_app/frame_vision_app.dart';
import 'package:simple_frame_app/simple_frame_app.dart';
import 'package:frame_msg/tx/plain_text.dart';

void main() => runApp(const MainApp());

final _log = Logger("MainApp");

// Enhanced photo metadata structure
class PhotoMetadata {
  final DateTime timestamp;
  final ImageMetadata imageMetadata;
  
  PhotoMetadata({required this.timestamp, required this.imageMetadata});
  
  @override
  String toString() {
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')} ${timestamp.day}/${timestamp.month}/${timestamp.year}';
    return 'Captured: $timeStr\nExposure: ${imageMetadata.toString()}';
  }
}

// Custom widget to display photo metadata
class PhotoMetadataWidget extends StatefulWidget {
  final PhotoMetadata meta;
  
  const PhotoMetadataWidget({super.key, required this.meta});
  
  @override
  State<PhotoMetadataWidget> createState() => _PhotoMetadataWidgetState();
}

class _PhotoMetadataWidgetState extends State<PhotoMetadataWidget> {
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    final timeStr = '${widget.meta.timestamp.hour.toString().padLeft(2, '0')}:${widget.meta.timestamp.minute.toString().padLeft(2, '0')}:${widget.meta.timestamp.second.toString().padLeft(2, '0')} ${widget.meta.timestamp.day}/${widget.meta.timestamp.month}/${widget.meta.timestamp.year}';
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always visible timestamp
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Captured: $timeStr',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Collapsible camera info section
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              children: [
                const Icon(Icons.camera_alt, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  'Camera Info',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          // Expandable camera details
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.meta.imageMetadata.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> with SimpleFrameAppState, FrameVisionAppState {
  // main state of photo request/processing on/off
  bool _processing = false;
  
  // track previous connection state to detect changes
  bool _wasConnected = false;
  
  // track if we're in the middle of auto-starting
  bool _autoStarting = false;

  // the list of images to show in the scolling list view
  final List<Image> _imageList = [];
  final List<PhotoMetadata> _photoMeta = [];
  final List<Uint8List> _jpegBytes = [];

  MainAppState() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  @override
  void initState() {
    super.initState();

    // start the automatic connection process
    _startAutoConnection();
  }

  /// Automatically handle connection and start the app
  Future<void> _startAutoConnection() async {
    try {
      // continuously try to connect and start until successful
      await tryScanAndConnectAndStart(andRun: true);
    } catch (e) {
      _log.warning('Auto-connection failed: $e');
      // Retry after a short delay
      Timer(const Duration(seconds: 2), _startAutoConnection);
    }
  }

  /// Monitor connection state changes and auto-start/stop
  void _checkConnectionState() {
    final isConnected = frame != null;
    
    if (isConnected != _wasConnected) {
      _wasConnected = isConnected;
      
      if (isConnected && !_autoStarting) {
        _log.info('Device connected - auto-starting app');
        _autoStarting = true;
        _autoStart();
      } else if (!isConnected) {
        _log.info('Device disconnected - stopping app');
        _autoStarting = false;
        _autoStop();
      }
    }
  }

  /// Auto start the app when connected
  Future<void> _autoStart() async {
    try {
      await run();
      _autoStarting = false;
    } catch (e) {
      _log.warning('Auto-start failed: $e');
      _autoStarting = false;
    }
  }

  /// Auto stop the app when disconnected
  Future<void> _autoStop() async {
    try {
      await cancel();
    } catch (e) {
      _log.warning('Auto-stop failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check connection state on every build
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConnectionState());
    
    return MaterialApp(
      title: 'Heartbeat Camera',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Heartbeat Camera"),
          actions: [
            // Connection status indicator
            _buildConnectionStatus(),
            getBatteryWidget(),
          ]
        ),
        drawer: getCameraDrawer(),
        onDrawerChanged: (isOpened) {
          if (!isOpened) {
            // if the user closes the camera settings, send the updated settings to Frame
            sendExposureSettings();
          }
        },
        body: Column(
          children: [
            // Status bar showing connection and app state
            _buildStatusBar(),
            // Main content area
            Expanded(
              child: _imageList.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => _shareImage(_imageList[index], _photoMeta[index], _jpegBytes[index]),
                                child: _imageList[index]
                              ),
                              PhotoMetadataWidget(meta: _photoMeta[index]),
                            ],
                          )
                        );
                      },
                      separatorBuilder: (context, index) => const Divider(height: 30),
                      itemCount: _imageList.length,
                    ),
            ),
          ]
        ),
        // Keep the floating action button for manual connection if needed
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  /// Build connection status indicator
  Widget _buildConnectionStatus() {
    final isConnected = frame != null;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Icon(
        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
        color: isConnected ? Colors.green : Colors.red,
      ),
    );
  }

  /// Build status bar showing current state
  Widget _buildStatusBar() {
    final isConnected = frame != null;
    String statusText;
    Color statusColor;
    
    if (!isConnected) {
      statusText = 'Searching for Frame glasses...';
      statusColor = Colors.orange;
    } else if (_autoStarting) {
      statusText = 'Starting camera app...';
      statusColor = Colors.blue;
    } else {
      statusText = 'Ready to capture your precious moments';
      statusColor = Colors.green;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: statusColor.withOpacity(0.1),
      child: Text(
        statusText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build empty state when no photos are captured
  Widget _buildEmptyState() {
    final isConnected = frame != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 100,
            color: Colors.grey.withOpacity(0.6),
          ),
          const SizedBox(height: 24),
          Text(
            isConnected 
                ? 'You do not have any moments yet.'
                : 'Connect your Frame glasses to start capturing moments',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Build floating action button for manual connection control
  Widget? _buildFloatingActionButton() {
    final isConnected = frame != null;
    
    // Only show if not connected, to allow manual connection attempts
    if (isConnected) {
      return FloatingActionButton(
        onPressed: _triggerCapture,
        tooltip: 'Capture Photo',
        child: const Icon(Icons.photo_camera),
      );
    }
    
    return FloatingActionButton(
      onPressed: _startAutoConnection,
      tooltip: 'Connect to Frame',
      child: const Icon(Icons.bluetooth_searching),
    );
  }

  @override
  Future<void> onRun() async {
    // initial message to display when running
    var msg = TxPlainText(text: 'Ready! Welcome to Heartbeat Camera');
    await frame!.sendMessage(0x0a, msg.pack());
  }

  @override
  Future<void> onCancel() async {
    // cleanup when app stops
    setState(() {
      _autoStarting = false;
    });
  }

  /// Manual capture method that can be called from button or tap
  Future<void> _triggerCapture() async {
    // check if there's processing in progress already and drop the request if so
    if (!_processing) {
      _processing = true;
      // synchronously call the capture and processing (just display) of the photo
      await capture().then(process);
    }
  }

  @override
  Future<void> onTap(int taps) async {
    switch (taps) {
      case 2:
        await _triggerCapture();
        break;
      default:
    }
  }

  /// The vision pipeline to run when a photo is captured
  /// Which in this case is just displaying
  FutureOr<void> process((Uint8List, ImageMetadata) photo) async {
    var imageData = photo.$1;
    var meta = photo.$2;

    // update the image reel
    setState(() {
      _imageList.insert(0, Image.memory(imageData, gaplessPlayback: true,));
      _photoMeta.insert(0, PhotoMetadata(timestamp: DateTime.now(), imageMetadata: meta));
      _jpegBytes.insert(0, imageData);
    });

    _processing = false;
  }

  void _shareImage(Image image, PhotoMetadata metadata, Uint8List jpegBytes) async {
    await Share.shareXFiles(
      [XFile.fromData(Uint8List.fromList(jpegBytes), mimeType: 'image/jpeg', name: 'image.jpg')],
      text: 'Frame camera image:\n$metadata',
    );
  }
}