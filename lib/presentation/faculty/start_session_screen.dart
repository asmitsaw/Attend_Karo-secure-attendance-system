import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';

class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({super.key});

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedClass;
  bool _sessionStarted = false;
  int _scannedCount = 0;
  final int _lateCount = 2;
  String _qrData = '';
  Timer? _qrRefreshTimer;
  Timer? _sessionTimer;
  int _sessionSeconds = 0;

  late AnimationController _pulseController;

  final List<String> _classes = [
    'Data Structures - Sem 3 - A',
    'Algorithms - Sem 4 - B',
    'Database Systems - Sem 3 - C',
  ];

  final List<Map<String, String>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    _sessionTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a class first'),
          backgroundColor: AppTheme.dangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _sessionStarted = true;
      _scannedCount = 0;
      _sessionSeconds = 0;
      _recentScans.clear();
      _generateQRCode();
    });

    // Timer
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _sessionSeconds++);
    });

    // Refresh QR every 10s
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _generateQRCode();
    });

    // Simulate scans
    _simulateScans();
  }

  void _generateQRCode() {
    final timestamp = DateTime.now().toIso8601String();
    setState(() {
      _qrData =
          '{"session_id":"SESSION_123","timestamp":"$timestamp","signature":"MOCK_SIG"}';
    });
  }

  void _simulateScans() {
    final names = [
      'Arjun Mehta',
      'Priya Sen',
      'Rahul Verma',
      'Sneha Das',
      'Karan K.',
    ];
    int idx = 0;
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_sessionStarted || !mounted || idx >= names.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _scannedCount++;
        _recentScans.insert(0, {
          'name': names[idx],
          'time': _formatTime(_sessionSeconds),
        });
      });
      idx++;
    });
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endSession() async {
    _qrRefreshTimer?.cancel();
    _sessionTimer?.cancel();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Session'),
        content: Text(
          'Total students scanned: $_scannedCount\n\n'
          'Remaining students will be marked as ABSENT. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Session ended successfully'),
                  backgroundColor: AppTheme.successColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Live Attendance'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: !_sessionStarted ? _buildSetupView(theme) : _buildLiveView(theme),
    );
  }

  Widget _buildSetupView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Class selection
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Class',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Choose Class',
                    prefixIcon: const Icon(Icons.class_),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  initialValue: _selectedClass,
                  items: _classes.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedClass = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _startSession,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // ── QR Code Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // QR
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  child: QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppTheme.primaryColor,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'QR refreshes every 10 seconds',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),

                // Timer
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(
                          0.05 + 0.04 * _pulseController.value,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.successColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(_sessionSeconds),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: [
                                const FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                // GPS lock
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gps_fixed,
                      size: 14,
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'GPS Lock Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Statistics ──
          Row(
            children: [
              Expanded(
                child: _LiveStatCard(
                  icon: Icons.people,
                  iconColor: AppTheme.successColor,
                  value: '$_scannedCount',
                  label: 'Students Present',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LiveStatCard(
                  icon: Icons.schedule,
                  iconColor: AppTheme.warningColor,
                  value: '$_lateCount',
                  label: 'Late Arrivals',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LiveStatCard(
                  icon: Icons.timer,
                  iconColor: AppTheme.primaryColor,
                  value: '4.2s',
                  label: 'Avg Time',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Recent Scans ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Scans',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_recentScans.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Waiting for students to scan...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                  )
                else
                  ..._recentScans
                      .take(5)
                      .map(
                        (scan) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: AppTheme.successColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  scan['name'] ?? '',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                scan['time'] ?? '',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Stop Session Button ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _endSession,
              icon: const Icon(Icons.stop_circle, size: 22),
              label: const Text('Stop Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: AppTheme.dangerColor.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LiveStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _LiveStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
