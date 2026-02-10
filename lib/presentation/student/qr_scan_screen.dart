import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/data_sources/qr_service.dart';
import '../../data/data_sources/location_service.dart';
import '../../data/data_sources/device_service.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final QRService _qrService = QRService();
  final LocationService _locationService = LocationService();
  final DeviceService _deviceService = DeviceService();

  bool _isProcessing = false;
  bool _scanComplete = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleQRScan(BarcodeCapture capture) async {
    if (_isProcessing || _scanComplete) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrData = barcodes.first.rawValue;
    if (qrData == null) return;

    setState(() => _isProcessing = true);

    // Step 1: Client-side QR validation
    if (!_qrService.validateQRTimestamp(qrData)) {
      _showError('QR code expired. Please scan a fresh code.');
      return;
    }

    // Step 2: Check location permission
    bool hasLocationPermission = await _locationService
        .checkAndRequestPermission();
    if (!hasLocationPermission) {
      _showError('Location permission denied. Cannot mark attendance.');
      return;
    }

    // Step 3: Check for mock location
    bool isMock = await _locationService.isMockLocation();
    if (isMock) {
      _showError('Fake GPS detected. Please disable mock location.');
      return;
    }

    // Step 4: Get current location
    final position = await _locationService.getCurrentLocation();
    if (position == null) {
      _showError('Unable to get your location. Please try again.');
      return;
    }

    // Step 5: Check location accuracy
    if (!_locationService.isAccuracyAcceptable(position.accuracy)) {
      _showError('Location accuracy too low. Please move to an open area.');
      return;
    }

    // Step 6: Get device ID
    final deviceId = await _deviceService.getDeviceId();

    // Step 7: Check if emulator
    final isEmulator = await _deviceService.isEmulator();
    if (isEmulator) {
      _showError('Attendance not allowed from emulator.');
      return;
    }

    // Step 8: Extract session ID
    final sessionId = _qrService.extractSessionId(qrData);
    if (sessionId == null) {
      _showError('Invalid QR code format.');
      return;
    }

    // Step 9: Send to backend for validation
    // TODO: Call backend API with:
    // - sessionId
    // - deviceId: $deviceId
    // - latitude: position.latitude
    // - longitude: position.longitude
    // Backend will validate:
    // - QR signature
    // - Geo-fence
    // - Device binding
    // - Duplicate check

    // Simulate backend call
    await Future.delayed(const Duration(seconds: 2));

    // Simulate success
    setState(() => _scanComplete = true);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Success!'),
        content: const Text('Attendance marked successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to dashboard
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    setState(() => _isProcessing = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 64),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleQRScan,
          ),

          // Scan Frame Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isProcessing
                    ? 'Processing...'
                    : 'Position QR code within frame to scan',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
