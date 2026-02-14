import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({super.key});

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  String? _selectedClass;
  bool _sessionStarted = false;
  int _scannedCount = 0;
  String _qrData = '';
  Timer? _qrRefreshTimer;

  final List<String> _classes = [
    'Data Structures - Sem 3 - A',
    'Algorithms - Sem 4 - B',
    'Database Systems - Sem 3 - C',
  ];

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a class first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Get faculty location and call backend to start session
    // For now, simulate with mock data
    setState(() {
      _sessionStarted = true;
      _scannedCount = 0;
      _generateQRCode();
    });

    // Refresh QR code every 10 seconds
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _generateQRCode();
      }
    });

    // Simulate students scanning
    _simulateScans();
  }

  void _generateQRCode() {
    // In real app, backend generates this with signature
    final timestamp = DateTime.now().toIso8601String();
    setState(() {
      _qrData =
          '{"session_id":"SESSION_123","timestamp":"$timestamp","signature":"MOCK_SIG"}';
    });
  }

  void _simulateScans() {
    // Simulate students scanning over time
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_sessionStarted || !mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _scannedCount++;
      });
    });
  }

  Future<void> _endSession() async {
    // TODO: Call backend to end session and mark absents
    _qrRefreshTimer?.cancel();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: Text(
          'Total students scanned: $_scannedCount\n\n'
          'Remaining students will be marked as ABSENT. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return to dashboard

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session ended successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Attendance Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_sessionStarted) ...[
              // Class Selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Class',
                  prefixIcon: Icon(Icons.class_),
                ),
                initialValue: _selectedClass,
                items: _classes.map((classItem) {
                  return DropdownMenuItem(
                    value: classItem,
                    child: Text(classItem),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedClass = value);
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _startSession,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Session'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else ...[
              // Session Active View
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Session Active',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_selectedClass ?? ''),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // QR Code
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Scan QR Code',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: _qrData,
                          version: QrVersions.auto,
                          size: 250,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'QR refreshes every 10 seconds',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Live Count
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, size: 32, color: Colors.blue),
                      const SizedBox(width: 12),
                      Text(
                        '$_scannedCount Students Scanned',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // End Session Button
              ElevatedButton.icon(
                onPressed: _endSession,
                icon: const Icon(Icons.stop),
                label: const Text('End Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
