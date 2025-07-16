import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_frame_app/frame_vision_app.dart';
import 'package:simple_frame_app/simple_frame_app.dart';
import 'package:frame_msg/tx/plain_text.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
                  color: Colors.grey.withValues(alpha: 0.1),
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
                color: Colors.grey.withValues(alpha: 0.05),
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

// Enhanced heartrate monitoring class for Bluetooth heart rate straps
class HeartRateMonitor {
  static final _log = Logger("HeartRateMonitor");
  
  // Bluetooth Heart Rate Service UUIDs
  static final Guid _heartRateServiceUuid = Guid("0000180D-0000-1000-8000-00805F9B34FB");
  static final Guid _heartRateMeasurementUuid = Guid("00002A37-0000-1000-8000-00805F9B34FB");
  
  // Configuration
  int _threshold = 100; // Default threshold BPM
  bool _isMonitoring = false;
  bool _isInitialized = false;
  bool _isScanning = false;
  
  // Current state
  int? _currentHeartRate;
  DateTime? _lastHeartRateUpdate;
  bool _isConnected = false;
  
  // Bluetooth state
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _heartRateCharacteristic;
  StreamSubscription<List<int>>? _heartRateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  List<BluetoothDevice> _availableDevices = [];
  
  // Enhanced error tracking
  String? _lastError;
  DateTime? _lastErrorTime;
  int _consecutiveErrors = 0;
  int _totalDataPackets = 0;
  int _invalidDataPackets = 0;
  
  // Callbacks
  Function(int)? onHeartRateUpdate;
  Function()? onThresholdExceeded;
  Function(bool)? onConnectionStateChanged;
  Function(List<BluetoothDevice>)? onDevicesFound;
  Function(String)? onError; // New error callback
  
  // Getters
  int get threshold => _threshold;
  bool get isMonitoring => _isMonitoring;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  int? get currentHeartRate => _currentHeartRate;
  DateTime? get lastHeartRateUpdate => _lastHeartRateUpdate;
  List<BluetoothDevice> get availableDevices => _availableDevices;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  String? get lastError => _lastError;
  DateTime? get lastErrorTime => _lastErrorTime;
  int get consecutiveErrors => _consecutiveErrors;
  double get dataQuality => _totalDataPackets > 0 ? ((_totalDataPackets - _invalidDataPackets) / _totalDataPackets) * 100 : 0.0;
  
  // Initialize Bluetooth heart rate monitoring
  Future<void> initialize() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        throw HeartRateException('Bluetooth is not supported on this device');
      }
      
      _isInitialized = true;
      _clearError();
      _log.info('Bluetooth heart rate monitor initialized');
      
      // Listen to Bluetooth adapter state
      FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        _log.info('Bluetooth adapter state: $state');
        if (state != BluetoothAdapterState.on) {
          _handleError('Bluetooth adapter is not enabled. Please enable Bluetooth to use heart rate monitoring.');
          _updateConnectionState(false);
        }
      });
      
    } catch (e) {
      final errorMsg = 'Failed to initialize Bluetooth heart rate monitor: ${_getSpecificErrorMessage(e)}';
      _handleError(errorMsg);
      _log.severe(errorMsg);
      rethrow;
    }
  }
  
  // Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      return await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
    } catch (e) {
      _handleError('Failed to check Bluetooth status: ${_getSpecificErrorMessage(e)}');
      return false;
    }
  }
  
  // Turn on Bluetooth (Android only)
  Future<void> turnOnBluetooth() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
        _clearError();
      } else {
        throw HeartRateException('Automatic Bluetooth activation is only supported on Android. Please enable Bluetooth manually.');
      }
    } catch (e) {
      final errorMsg = 'Failed to turn on Bluetooth: ${_getSpecificErrorMessage(e)}';
      _handleError(errorMsg);
      throw HeartRateException(errorMsg);
    }
  }
  
  // Scan for heart rate devices
  Future<void> scanForDevices() async {
    if (!_isInitialized) {
      throw HeartRateException('Bluetooth not initialized. Please initialize first.');
    }
    
    if (!await isBluetoothEnabled()) {
      throw HeartRateException('Bluetooth is not enabled. Please enable Bluetooth to scan for devices.');
    }
    
    _isScanning = true;
    _availableDevices.clear();
    _clearError();
    
    try {
      _log.info('Checking for already connected system devices...');

      // Check for devices already connected to the system
      try {
        final systemDevices = await FlutterBluePlus.connectedSystemDevices;
        for (BluetoothDevice device in systemDevices) {
          if (device.platformName != null &&
              (device.platformName!.toLowerCase().contains('hrm') ||
               device.platformName!.toLowerCase().contains('heart'))) {
            _availableDevices.add(device);
            _log.info('Found system-connected HRM: ${device.platformName ?? 'Unknown Device'}');
          }
        }
        onDevicesFound?.call(_availableDevices);
      } catch(e) {
        _log.warning("Could not get system devices: ${_getSpecificErrorMessage(e)}");
      }

      _log.info('Scanning for new heart rate devices...');
      
      // Listen to scan results for new devices
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final device = result.device;
          if (!_availableDevices.any((d) => d.remoteId == device.remoteId)) {
             _availableDevices.add(device);
             _log.info('Found new HRM device: ${device.platformName ?? 'Unknown Device'} (${device.remoteId})');
             onDevicesFound?.call(_availableDevices);
          }
        }
      });
      
      // Start scanning for new devices
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [_heartRateServiceUuid],
      );
      
      // Wait for the scan to finish
      await Future.delayed(const Duration(seconds: 10));
      
      _log.info('Scan completed. Found ${_availableDevices.length} total heart rate devices');
      
    } catch (e) {
      final errorMsg = 'Failed to scan for heart rate devices: ${_getSpecificErrorMessage(e)}';
      _handleError(errorMsg);
      throw HeartRateException(errorMsg);
    } finally {
      _isScanning = false;
    }
  }
  
  // Connect to a specific heart rate device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _clearError();
      _log.info('Connecting to device: ${device.platformName} (${device.remoteId})');
      
      // Disconnect from any existing device
      await disconnect();
      
      // Connect to the new device with timeout
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      
      // Listen to connection state changes
      _connectionSubscription = device.connectionState.listen((BluetoothConnectionState state) {
        _log.info('Connection state changed: $state');
        
        if (state == BluetoothConnectionState.connected) {
          _updateConnectionState(true);
          _clearError();
        } else if (state == BluetoothConnectionState.disconnected) {
          _handleError('Heart rate device disconnected unexpectedly. Please check the device and try reconnecting.');
          _updateConnectionState(false);
          _cleanup();
        }
      });
      
      // Discover services with timeout
      List<BluetoothService> services;
      try {
        services = await device.discoverServices().timeout(const Duration(seconds: 10));
      } catch (e) {
        throw HeartRateException('Failed to discover services on device: ${_getSpecificErrorMessage(e)}');
      }
      
      // Find heart rate service
      BluetoothService? heartRateService;
      for (BluetoothService service in services) {
        if (service.uuid == _heartRateServiceUuid) {
          heartRateService = service;
          break;
        }
      }
      
      if (heartRateService == null) {
        throw HeartRateException('Heart rate service not found on device. This device may not be a compatible heart rate monitor.');
      }
      
      // Find heart rate measurement characteristic
      for (BluetoothCharacteristic characteristic in heartRateService.characteristics) {
        if (characteristic.uuid == _heartRateMeasurementUuid) {
          _heartRateCharacteristic = characteristic;
          break;
        }
      }
      
      if (_heartRateCharacteristic == null) {
        throw HeartRateException('Heart rate measurement characteristic not found. This device may not support standard heart rate monitoring.');
      }
      
      // Check characteristic properties
      if (!_heartRateCharacteristic!.properties.notify) {
        throw HeartRateException('Heart rate characteristic does not support notifications. This device may not be compatible.');
      }
      
      _updateConnectionState(true);
      _log.info('Successfully connected to heart rate device');
      
    } catch (e) {
      final errorMsg = 'Failed to connect to heart rate device: ${_getSpecificErrorMessage(e)}';
      _handleError(errorMsg);
      _log.severe(errorMsg);
      await disconnect();
      throw HeartRateException(errorMsg);
    }
  }
  
  // Disconnect from current device
  Future<void> disconnect() async {
    _log.info('Disconnecting from heart rate device');
    
    try {
      // Stop monitoring if active
      if (_isMonitoring) {
        await stopMonitoring();
      }
      
      _cleanup();
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      
      _clearError();
      _updateConnectionState(false);
      
    } catch (e) {
      _log.warning('Error during disconnect: ${_getSpecificErrorMessage(e)}');
      // Don't throw here as disconnect should always succeed
    }
  }
  
  // Clean up connection resources
  void _cleanup() {
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _heartRateCharacteristic = null;
    _connectedDevice = null;
    _currentHeartRate = null;
    _lastHeartRateUpdate = null;
  }
  
  // Update connection state and notify listeners
  void _updateConnectionState(bool isConnected) {
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      _log.info('Heart rate device connection state changed: $isConnected');
      onConnectionStateChanged?.call(isConnected);
    }
  }
  
  // Start monitoring heartrate
  Future<void> startMonitoring() async {
    if (!_isInitialized) {
      throw HeartRateException('Bluetooth not initialized. Please initialize first.');
    }
    
    if (!_isConnected || _heartRateCharacteristic == null) {
      throw HeartRateException('Heart rate device not connected. Please connect to a device first.');
    }
    
    try {
      _clearError();
      _totalDataPackets = 0;
      _invalidDataPackets = 0;
      
      // Enable notifications for heart rate measurements
      await _heartRateCharacteristic!.setNotifyValue(true);
      
      // Listen to heart rate data
      _heartRateSubscription = _heartRateCharacteristic!.lastValueStream.listen(
        (value) => _handleHeartRateData(value),
        onError: (error) {
          final errorMsg = 'Heart rate data stream error: ${_getSpecificErrorMessage(error)}';
          _handleError(errorMsg);
          _log.severe(errorMsg);
          _updateConnectionState(false);
        },
      );
      
      _isMonitoring = true;
      _log.info('Started heart rate monitoring with threshold: $_threshold BPM');
      
    } catch (e) {
      final errorMsg = 'Failed to start heart rate monitoring: ${_getSpecificErrorMessage(e)}';
      _handleError(errorMsg);
      _log.severe(errorMsg);
      throw HeartRateException(errorMsg);
    }
  }
  
  // Stop monitoring
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    _log.info('Stopped heart rate monitoring');
    
    try {
      // Disable notifications
      if (_heartRateCharacteristic != null) {
        await _heartRateCharacteristic!.setNotifyValue(false);
      }
      
      // Cancel subscription
      _heartRateSubscription?.cancel();
      _heartRateSubscription = null;
      
      _clearError();
      
    } catch (e) {
      _log.warning('Error stopping monitoring: ${_getSpecificErrorMessage(e)}');
      // Don't throw here as stop should always succeed
    }
  }
  
  // Update threshold
  void updateThreshold(int newThreshold) {
    if (newThreshold < 30 || newThreshold > 250) {
      throw HeartRateException('Invalid threshold: $newThreshold. Threshold must be between 30 and 250 BPM.');
    }
    _threshold = newThreshold;
    _log.info('Updated heart rate threshold to: $_threshold BPM');
  }
  
  // Handle incoming heart rate data
  void _handleHeartRateData(List<int> data) {
    _totalDataPackets++;
    
    if (data.isEmpty) {
      _invalidDataPackets++;
      _handleError('Received empty heart rate data packet');
      return;
    }
    
    try {
      // Parse heart rate measurement according to Bluetooth Heart Rate Service specification
      int heartRate;
      
      // Minimum data length check
      if (data.length < 2) {
        _invalidDataPackets++;
        _handleError('Invalid heart rate data: packet too short (${data.length} bytes)');
        return;
      }
      
      // Check if heart rate is in 16-bit format (bit 0 of flags byte)
      bool is16Bit = (data[0] & 0x01) != 0;
      
      if (is16Bit) {
        // 16-bit heart rate value (little endian)
        if (data.length < 3) {
          _invalidDataPackets++;
          _handleError('Invalid 16-bit heart rate data: packet too short (${data.length} bytes)');
          return;
        }
        heartRate = data[1] | (data[2] << 8);
      } else {
        // 8-bit heart rate value
        heartRate = data[1];
      }
      
      // Validate heart rate range
      if (heartRate < 30 || heartRate > 250) {
        _invalidDataPackets++;
        _handleError('Invalid heart rate value: $heartRate BPM (valid range: 30-250)');
        return;
      }
      
      // Check for sensor contact (bit 1 and 2 of flags byte)
      bool sensorContactSupported = (data[0] & 0x02) != 0;
      bool sensorContactDetected = (data[0] & 0x04) != 0;
      
      if (sensorContactSupported && !sensorContactDetected) {
        _handleError('Heart rate sensor contact lost - please adjust your strap');
        return;
      }
      
      _currentHeartRate = heartRate;
      _lastHeartRateUpdate = DateTime.now();
      _consecutiveErrors = 0; // Reset error count on successful data
      
      _log.info('Received heart rate: $heartRate BPM (data quality: ${dataQuality.toStringAsFixed(1)}%)');
      onHeartRateUpdate?.call(heartRate);
      
      // Check if threshold is exceeded
      if (_isMonitoring && heartRate > _threshold) {
        _log.info('Heart rate threshold exceeded: $heartRate > $_threshold');
        onThresholdExceeded?.call();
      }
      
    } catch (e) {
      _invalidDataPackets++;
      final errorMsg = 'Error parsing heart rate data: ${_getSpecificErrorMessage(e)} (data: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')})';
      _handleError(errorMsg);
      _log.warning(errorMsg);
    }
  }
  
  // Handle errors with specific messaging
  void _handleError(String errorMessage) {
    _lastError = errorMessage;
    _lastErrorTime = DateTime.now();
    _consecutiveErrors++;
    
    // Call error callback if set
    onError?.call(errorMessage);
    
    // Log based on error frequency
    if (_consecutiveErrors > 10) {
      _log.severe('Too many consecutive errors ($consecutiveErrors): $errorMessage');
    } else {
      _log.warning('Heart rate error: $errorMessage');
    }
  }
  
  // Clear error state
  void _clearError() {
    _lastError = null;
    _lastErrorTime = null;
    _consecutiveErrors = 0;
  }
  
  // Get specific error message based on exception type
  String _getSpecificErrorMessage(dynamic error) {
    if (error is HeartRateException) {
      return error.message;
    }
    
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('timeout')) {
      return 'Connection timeout - device may be out of range or not responding';
    }
    
    if (errorStr.contains('permission')) {
      return 'Bluetooth permission denied - please grant Bluetooth permissions';
    }
    
    if (errorStr.contains('not supported')) {
      return 'Bluetooth not supported on this device';
    }
    
    if (errorStr.contains('adapter')) {
      return 'Bluetooth adapter error - please restart Bluetooth';
    }
    
    if (errorStr.contains('service')) {
      return 'Heart rate service not available on device';
    }
    
    if (errorStr.contains('characteristic')) {
      return 'Heart rate measurement not supported by device';
    }
    
    if (errorStr.contains('connection')) {
      return 'Bluetooth connection failed - device may be paired with another device';
    }
    
    if (errorStr.contains('disconnected')) {
      return 'Device disconnected unexpectedly';
    }
    
    return error.toString();
  }
  
  // Check if heartrate data is stale (no update in last 30 seconds)
  bool get isHeartRateDataStale {
    if (_lastHeartRateUpdate == null) return true;
    return DateTime.now().difference(_lastHeartRateUpdate!).inSeconds > 30;
  }
  
  // Get a status message about heartrate monitoring
  String get statusMessage {
    if (_lastError != null) return 'Error: $_lastError';
    if (!_isInitialized) return 'Bluetooth not initialized';
    if (!_isConnected) return 'Heart rate strap not connected';
    if (!_isMonitoring) return 'Monitoring disabled';
    if (_currentHeartRate == null) return 'Waiting for heart rate data...';
    if (isHeartRateDataStale) return 'Heart rate data is stale';
    return 'Monitoring active';
  }
  
  // Get a detailed status message with instructions
  String get detailedStatusMessage {
    if (_lastError != null) {
      return 'Error: $_lastError${_lastErrorTime != null ? ' (${DateTime.now().difference(_lastErrorTime!).inSeconds}s ago)' : ''}';
    }
    if (!_isInitialized) return 'Bluetooth heart rate monitor not initialized';
    if (!_isConnected) {
      return 'Heart rate strap not connected. Make sure your Bluetooth heart rate strap is on and in pairing mode, then tap "Connect" to scan for devices.';
    }
    if (!_isMonitoring) return 'Heart rate monitoring is disabled';
    if (_currentHeartRate == null) return 'Connected to heart rate strap, waiting for data...';
    if (isHeartRateDataStale) return 'Heart rate data is stale - check your strap connection';
    return 'Monitoring active - current HR: $_currentHeartRate BPM (threshold: $_threshold BPM, data quality: ${dataQuality.toStringAsFixed(1)}%)';
  }
}

// Custom exception for heart rate specific errors
class HeartRateException implements Exception {
  final String message;
  HeartRateException(this.message);
  
  @override
  String toString() => 'HeartRateException: $message';
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

  // Heartrate monitoring
  final HeartRateMonitor _heartRateMonitor = HeartRateMonitor();
  bool _heartRateMonitoringEnabled = false;

  // UI state for strap connection/errors
  bool _isConnectingStrap = false;
  String? _heartRateError;

  MainAppState() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  @override
  void initState() {
    super.initState();

    // Initialize heartrate monitoring
    _initializeHeartRateMonitoring();

    // start the automatic connection process
    _startAutoConnection();
  }

  /// Initialize heartrate monitoring
  Future<void> _initializeHeartRateMonitoring() async {
    // Set up callbacks
    _heartRateMonitor.onHeartRateUpdate = (heartRate) {
      setState(() {
        // UI will update with new heartrate
      });
    };
    
    _heartRateMonitor.onThresholdExceeded = () {
      _log.info('Heartrate threshold exceeded - triggering capture');
      _triggerCapture();
    };
    
    _heartRateMonitor.onConnectionStateChanged = (isConnected) {
      setState(() {
        // UI will update with connection state
      });
    };
    
    _heartRateMonitor.onError = (errorMessage) {
      setState(() {
        _heartRateError = errorMessage;
      });
      
      // Show error snackbar for critical errors
      if (errorMessage.toLowerCase().contains('disconnected') || 
          errorMessage.toLowerCase().contains('timeout') ||
          errorMessage.toLowerCase().contains('failed')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        });
      }
    };
    
    // Initialize the monitor
    try {
      await _heartRateMonitor.initialize();
    } catch (e) {
      setState(() {
        _heartRateError = 'Failed to initialize heart rate monitor: $e';
      });
    }
  }

  /// Toggle heartrate monitoring
  void _toggleHeartRateMonitoring() async {
    if (!_heartRateMonitoringEnabled) {
      // Enabling monitoring - check if heart rate strap is connected
      if (!_heartRateMonitor.isConnected) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Please connect your heart rate strap first'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    
    setState(() {
      _heartRateMonitoringEnabled = !_heartRateMonitoringEnabled;
    });
    
    if (_heartRateMonitoringEnabled) {
      try {
        await _heartRateMonitor.startMonitoring();
      } catch (e) {
        setState(() {
          _heartRateMonitoringEnabled = false;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Failed to start monitoring: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      _heartRateMonitor.stopMonitoring();
    }
  }

  /// Show heartrate threshold configuration dialog
  void _showHeartRateConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => _HeartRateConfigDialog(
        currentThreshold: _heartRateMonitor.threshold,
        onThresholdChanged: (newThreshold) {
          _heartRateMonitor.updateThreshold(newThreshold);
          setState(() {});
        },
      ),
    );
  }

  /// Connect to heart rate strap - simplified auto-connection
  Future<void> _connectHeartRateStrap() async {
    if (!super.mounted) return;
    setState(() {
      _isConnectingStrap = true;
      _heartRateError = null;
    });

    try {
      // Check if Bluetooth is enabled FIRST
      if (!await _heartRateMonitor.isBluetoothEnabled()) {
        if (!super.mounted) return;
        setState(() {
          _isConnectingStrap = false;
          _heartRateError = 'Bluetooth is disabled – please enable it in Settings to connect a heart-rate strap.';
        });
        return;
      }

      // Scan for devices
      await _heartRateMonitor.scanForDevices();
      
      if (!super.mounted) return;
      
      // Get available devices
      final devices = _heartRateMonitor.availableDevices;
      
      if (devices.isEmpty) {
        setState(() {
          _isConnectingStrap = false;
          _heartRateError = 'No heart rate devices found. Make sure your strap is on and in pairing mode.';
        });
        return;
      }
      
      // If only one device, connect automatically
      if (devices.length == 1) {
        await _heartRateMonitor.connectToDevice(devices.first);
        if (!super.mounted) return;
        setState(() {
          _isConnectingStrap = false;
        });
        _showSuccessMessage('Connected to ${devices.first.platformName ?? "heart rate device"}');
        return;
      }
      
      // If multiple devices, show simple selection
      if (!super.mounted) return;
      _showDeviceSelection(devices);

    } catch (e) {
      if (!super.mounted) return;
      setState(() {
        _isConnectingStrap = false;
        _heartRateError = 'Error while connecting: $e';
      });
    }
  }

  /// Show simple device selection bottom sheet
  void _showDeviceSelection(List<BluetoothDevice> devices) {
    setState(() {
      _isConnectingStrap = false;
    });
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Heart Rate Device',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...devices.map((device) => ListTile(
              leading: const Icon(Icons.monitor_heart, color: Colors.red),
              title: Text(device.platformName ?? 'Unknown Device'),
              subtitle: Text(device.remoteId.toString()),
              onTap: () async {
                Navigator.pop(context);
                await _connectToSpecificDevice(device);
              },
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Connect to a specific device
  Future<void> _connectToSpecificDevice(BluetoothDevice device) async {
    setState(() {
      _isConnectingStrap = true;
      _heartRateError = null;
    });

    try {
      await _heartRateMonitor.connectToDevice(device);
      if (!super.mounted) return;
      setState(() {
        _isConnectingStrap = false;
      });
      _showSuccessMessage('Connected to ${device.platformName ?? "heart rate device"}');
    } catch (e) {
      if (!super.mounted) return;
      setState(() {
        _isConnectingStrap = false;
        _heartRateError = 'Failed to connect to ${device.platformName ?? "device"}: $e';
      });
    }
  }

  /// Show success message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Clear heart rate error
  void _clearHeartRateError() {
    setState(() {
      _heartRateError = null;
    });
  }

  /// Get detailed heart rate status for debugging
  String _getHeartRateDebugInfo() {
    if (!_heartRateMonitor.isInitialized) {
      return 'Heart Rate Monitor not initialized';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Heart Rate Monitor Status:');
    buffer.writeln('- Initialized: ${_heartRateMonitor.isInitialized}');
    buffer.writeln('- Connected: ${_heartRateMonitor.isConnected}');
    buffer.writeln('- Monitoring: ${_heartRateMonitor.isMonitoring}');
    buffer.writeln('- Current HR: ${_heartRateMonitor.currentHeartRate ?? 'N/A'}');
    buffer.writeln('- Threshold: ${_heartRateMonitor.threshold} BPM');
    buffer.writeln('- Data Quality: ${_heartRateMonitor.dataQuality.toStringAsFixed(1)}%');
    buffer.writeln('- Last Update: ${_heartRateMonitor.lastHeartRateUpdate?.toString() ?? 'N/A'}');
    buffer.writeln('- Consecutive Errors: ${_heartRateMonitor.consecutiveErrors}');
    buffer.writeln('- Last Error: ${_heartRateMonitor.lastError ?? 'None'}');
    if (_heartRateMonitor.connectedDevice != null) {
      buffer.writeln('- Device: ${_heartRateMonitor.connectedDevice!.platformName ?? 'Unknown'} (${_heartRateMonitor.connectedDevice!.remoteId})');
    }
    
    return buffer.toString();
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
            // Heartrate monitoring toggle
            _buildHeartRateToggle(),
            // Connection status indicator
            _buildConnectionStatus(),
            getBatteryWidget(),
          ]
        ),
        drawer: _buildDrawer(),
        onDrawerChanged: (isOpened) {
          if (!isOpened && frame != null) {
            // if the user closes the camera settings, send the updated settings to Frame
            sendExposureSettings();
          }
        },
        body: Column(
          children: [
            // Heartrate status bar
            _buildHeartRateStatusBar(),
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

  /// Build heartrate monitoring toggle button
  Widget _buildHeartRateToggle() {
    // Decide icon appearance based on connection and monitoring state
    IconData iconData;
    Color iconColor;
    String tooltip;

    if (!_heartRateMonitor.isConnected) {
      // Not connected – show an outlined heart in orange to hint action required
      iconData = Icons.favorite_outline;
      iconColor = Colors.orange;
      tooltip = 'Connect Heart Rate Strap';
    } else {
      // Connected – use filled/outlined heart to indicate monitoring state
      iconData = _heartRateMonitoringEnabled ? Icons.favorite : Icons.favorite_outline;
      iconColor = _heartRateMonitoringEnabled ? Colors.red : Colors.grey;
      tooltip = _heartRateMonitoringEnabled ? 'Disable HR monitoring' : 'Enable HR monitoring';
    }

    return IconButton(
      icon: Icon(iconData, color: iconColor),
      tooltip: tooltip,
      onPressed: () {
        if (_heartRateMonitor.isConnected) {
          // Strap already connected – toggle monitoring
          _toggleHeartRateMonitoring();
        } else {
          // Not connected – start the connection flow
          _connectHeartRateStrap();
        }
      },
    );
  }

  /// Build drawer with camera settings and heartrate configuration
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text(
              'Settings',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          // Camera settings - integrate the existing camera drawer
          ExpansionTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera Settings'),
            children: [
              // Get the original camera drawer content
              ...(_getCameraDrawerContent()),
            ],
          ),
          // Heartrate settings
          ExpansionTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Heart Rate Settings'),
            children: [
              if (!_heartRateMonitor.isConnected)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bluetooth, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          const Text('Setup Instructions', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'To connect your heart rate strap:\n'
                        '1. Put on your Bluetooth heart rate strap\n'
                        '2. Make sure it\'s in pairing mode\n'
                        '3. Ensure Bluetooth is enabled on your phone\n'
                        '4. Tap "Connect Heart Rate Strap" below',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              // Error display section
              if (_heartRateMonitor.lastError != null)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          const Text('Error Details', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _heartRateMonitor.lastError!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (_heartRateMonitor.lastErrorTime != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Last error: ${DateTime.now().difference(_heartRateMonitor.lastErrorTime!).inSeconds} seconds ago',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                      if (_heartRateMonitor.consecutiveErrors > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Consecutive errors: ${_heartRateMonitor.consecutiveErrors}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              // Data quality section
              if (_heartRateMonitor.isConnected && _heartRateMonitoringEnabled)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          const Text('Data Quality', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Quality:', style: TextStyle(fontSize: 12)),
                          Text(
                            '${_heartRateMonitor.dataQuality.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: _heartRateMonitor.dataQuality > 95 ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_heartRateMonitor.lastHeartRateUpdate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Last update:', style: TextStyle(fontSize: 12)),
                            Text(
                              '${DateTime.now().difference(_heartRateMonitor.lastHeartRateUpdate!).inSeconds}s ago',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                      if (_heartRateMonitor.currentHeartRate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current HR:', style: TextStyle(fontSize: 12)),
                            Text(
                              '${_heartRateMonitor.currentHeartRate} BPM',
                              style: TextStyle(
                                fontSize: 12,
                                color: _heartRateMonitor.currentHeartRate! > _heartRateMonitor.threshold 
                                  ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ListTile(
                leading: Icon(
                  _heartRateMonitor.isConnected ? Icons.monitor_heart : Icons.monitor_heart_outlined,
                  color: _heartRateMonitor.isConnected ? Colors.green : Colors.grey,
                ),
                title: Text(_heartRateMonitor.isConnected 
                    ? 'Heart Rate Strap Connected' 
                    : 'Connect Heart Rate Strap'),
                subtitle: Text(_heartRateMonitor.isConnected 
                    ? (_heartRateMonitor.connectedDevice?.platformName ?? 'Unknown Device')
                    : 'Supports Bluetooth heart rate straps (Garmin, Polar, etc.)'),
                trailing: _isConnectingStrap ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ) : null,
                onTap: _isConnectingStrap ? null : _connectHeartRateStrap,
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Configure Threshold'),
                subtitle: Text('Current: ${_heartRateMonitor.threshold} BPM'),
                onTap: _showHeartRateConfigDialog,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.monitor_heart),
                title: const Text('Enable Monitoring'),
                subtitle: Text(_heartRateMonitoringEnabled 
                    ? 'Auto-capture when threshold exceeded'
                    : 'Manual capture only'),
                value: _heartRateMonitoringEnabled,
                onChanged: (value) => _toggleHeartRateMonitoring(),
              ),
              // Debug info option
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Debug Info'),
                subtitle: const Text('View detailed heart rate monitor status'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Heart Rate Debug Info'),
                      content: SingleChildScrollView(
                        child: Text(
                          _getHeartRateDebugInfo(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get camera drawer content as a list of widgets
  List<Widget> _getCameraDrawerContent() {
    // For now, return the basic camera settings
    // This should be replaced with the actual camera drawer content
    return [
      ListTile(
        leading: const Icon(Icons.settings),
        title: const Text('Camera Configuration'),
        onTap: () {
          // Camera settings logic
        },
      ),
    ];
  }

  /// Build heartrate status bar
  Widget _buildHeartRateStatusBar() {
    // Show the bar if connected, monitoring is enabled, connecting, or there's an error
    if (!(_heartRateMonitor.isConnected || _heartRateMonitoringEnabled || _isConnectingStrap || _heartRateError != null)) {
      return const SizedBox.shrink();
    }
    
    // Handle different states
    if (_heartRateError != null) {
      return _buildErrorStatusBar();
    }
    
    if (_isConnectingStrap) {
      return _buildConnectingStatusBar();
    }
    
    if (!_heartRateMonitor.isConnected) {
      return _buildNotConnectedStatusBar();
    }
    
    // Connected - show heart rate prominently
    return _buildConnectedStatusBar();
  }

  /// Build error status bar
  Widget _buildErrorStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _heartRateError!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearHeartRateError,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build connecting status bar
  Widget _buildConnectingStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.blue.withValues(alpha: 0.1),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
          ),
          SizedBox(width: 12),
          Text(
            'Connecting to heart rate strap...',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Build not connected status bar
  Widget _buildNotConnectedStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_disabled, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Heart rate strap not connected',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: _connectHeartRateStrap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Connect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build connected status bar with prominent heart rate display
  Widget _buildConnectedStatusBar() {
    final hr = _heartRateMonitor.currentHeartRate;
    final threshold = _heartRateMonitor.threshold;
    final isStale = _heartRateMonitor.isHeartRateDataStale;
    final deviceName = _heartRateMonitor.connectedDevice?.platformName ?? 'Unknown Device';
    
    Color statusColor;
    String statusText;
    
    if (hr == null) {
      statusColor = Colors.orange;
      statusText = 'Waiting for data...';
    } else if (isStale) {
      statusColor = Colors.orange;
      statusText = 'Data stale';
    } else if (hr > threshold) {
      statusColor = Colors.red;
      statusText = 'Above threshold';
    } else {
      statusColor = Colors.green;
      statusText = 'Normal';
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: statusColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          // Heart rate display - prominent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: statusColor, size: 24),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hr != null ? '$hr BPM' : '-- BPM',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Device info and threshold
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  deviceName,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Threshold: $threshold BPM',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                  ),
                ),
                if (_heartRateMonitoringEnabled) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Auto-capture ON',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Settings button
          GestureDetector(
            onTap: _showHeartRateConfigDialog,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.settings,
                color: statusColor,
                size: 16,
              ),
            ),
          ),
        ],
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
      color: statusColor.withValues(alpha: 0.1),
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
            color: Colors.grey.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 24),
          Text(
            isConnected 
                ? 'You do not have any moments yet.'
                : 'Connect your Frame glasses to start capturing moments',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withValues(alpha: 0.8),
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

// Heartrate configuration dialog
class _HeartRateConfigDialog extends StatefulWidget {
  final int currentThreshold;
  final Function(int) onThresholdChanged;
  
  const _HeartRateConfigDialog({
    required this.currentThreshold,
    required this.onThresholdChanged,
  });
  
  @override
  _HeartRateConfigDialogState createState() => _HeartRateConfigDialogState();
}

class _HeartRateConfigDialogState extends State<_HeartRateConfigDialog> {
  late int _threshold;
  
  @override
  void initState() {
    super.initState();
    _threshold = widget.currentThreshold;
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Heartrate Threshold'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current threshold: $_threshold BPM'),
          const SizedBox(height: 16),
          Slider(
            value: _threshold.toDouble(),
            min: 60,
            max: 200,
            divisions: 140,
            label: '$_threshold BPM',
            onChanged: (value) {
              setState(() {
                _threshold = value.round();
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Photos will be automatically captured when your heartrate exceeds this threshold.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onThresholdChanged(_threshold);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

