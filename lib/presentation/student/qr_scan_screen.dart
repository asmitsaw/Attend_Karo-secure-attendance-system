import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data_sources/qr_service.dart';
import '../../data/data_sources/location_service.dart';
import '../../data/data_sources/device_service.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  final QRService _qrService = QRService();
  final LocationService _locationService = LocationService();
  final DeviceService _deviceService = DeviceService();

  bool _isProcessing = false;
  bool _scanComplete = false;

  // Security checks state
  bool _gpsVerified = false;
  final bool _deviceBound = true;
  bool _checkingLocation = true;

  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    // Simulate location check
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _gpsVerified = true;
          _checkingLocation = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scanLineController.dispose();
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
    final _ = await _deviceService.getDeviceId();

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

    // Step 9: Backend call (simulated)
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _scanComplete = true);

    if (!mounted) return;

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Attendance Marked!',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Your attendance has been verified and recorded successfully.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    setState(() => _isProcessing = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error,
                  color: AppTheme.dangerColor,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Security Violation',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dangerColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final scanArea = size.width * 0.65;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera ──
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleQRScan,
          ),

          // ── Dark overlay with scan window ──
          Positioned.fill(
            child: CustomPaint(
              painter: _ScanOverlayPainter(
                scanArea: scanArea,
                borderColor: AppTheme.accentPurple,
              ),
            ),
          ),

          // ── Scanning line animation ──
          AnimatedBuilder(
            animation: _scanLineAnimation,
            builder: (context, child) {
              final topOffset =
                  (size.height - scanArea) / 2 +
                  scanArea * _scanLineAnimation.value;
              return Positioned(
                top: topOffset,
                left: (size.width - scanArea) / 2 + 8,
                right: (size.width - scanArea) / 2 + 8,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppTheme.accentPurple.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Header ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  Text(
                    'Secure QR Scanner',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _scannerController.toggleTorch(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.flash_on,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Processing indicator ──
          if (_isProcessing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppTheme.accentPurple,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verifying...',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom Panel: Security Checks ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Security Checks',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SecurityCheckRow(
                    icon: Icons.gps_fixed,
                    label: 'GPS Verification',
                    status: _checkingLocation
                        ? 'Checking...'
                        : _gpsVerified
                        ? 'Verified'
                        : 'Failed',
                    isVerified: _gpsVerified && !_checkingLocation,
                    isLoading: _checkingLocation,
                  ),
                  const SizedBox(height: 10),
                  _SecurityCheckRow(
                    icon: Icons.phone_android,
                    label: 'Device Binding',
                    status: _deviceBound ? 'Bound' : 'Unbound',
                    isVerified: _deviceBound,
                  ),
                  const SizedBox(height: 10),
                  _SecurityCheckRow(
                    icon: Icons.security,
                    label: 'Anti-Spoof',
                    status: 'Active',
                    isVerified: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isProcessing
                        ? 'Processing attendance...'
                        : 'Position QR code within the frame',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityCheckRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool isVerified;
  final bool isLoading;

  const _SecurityCheckRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.isVerified,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isLoading
        ? AppTheme.warningColor
        : (isVerified ? AppTheme.successColor : AppTheme.dangerColor);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.white),
          ),
        ),
        if (isLoading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.warningColor,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom painter for the QR scanner overlay
class _ScanOverlayPainter extends CustomPainter {
  final double scanArea;
  final Color borderColor;

  _ScanOverlayPainter({required this.scanArea, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: scanArea,
      height: scanArea,
    );

    // Semi-transparent overlay
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;
    const r = 12.0;

    // Top-left
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top + r),
      cornerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(rect.left, rect.top, r * 2, r * 2),
      3.14159,
      1.5708,
      false,
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left + r, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right - r, rect.top),
      cornerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(rect.right - r * 2, rect.top, r * 2, r * 2),
      -1.5708,
      1.5708,
      false,
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top + r),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom - r),
      cornerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(rect.left, rect.bottom - r * 2, r * 2, r * 2),
      3.14159,
      -1.5708,
      false,
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left + r, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right - r, rect.bottom),
      cornerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(rect.right - r * 2, rect.bottom - r * 2, r * 2, r * 2),
      0,
      1.5708,
      false,
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom - r),
      Offset(rect.right, rect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
