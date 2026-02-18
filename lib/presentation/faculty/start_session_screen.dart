import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../data/data_sources/location_service.dart';

class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({super.key});

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedTimeSlot;
  bool _sessionStarted = false;
  bool _isLoading = false;
  int _scannedCount = 0;
  String _sessionCode = '';
  String? _sessionId;
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _liveStatsTimer;
  Timer? _sessionTimer;
  int _sessionSeconds = 0;

  // Classes loaded from backend: [{id, name}]
  List<Map<String, String>> _classes = [];
  bool _classesLoading = true;

  final List<Map<String, String>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _liveStatsTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  /// Load classes from backend for the logged-in faculty
  Future<void> _loadClasses() async {
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      if (token == null) {
        setState(() => _classesLoading = false);
        return;
      }

      final response = await _dio.get(
        '${ApiEndpoints.baseUrl}/faculty/classes',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final List classData = response.data['classes'] ?? [];
      setState(() {
        _classes = classData.map<Map<String, String>>((c) {
          return {
            'id': c['id'].toString(),
            'name': '${c['subject']} - Sem ${c['semester']} - ${c['section']}',
          };
        }).toList();
        _classesLoading = false;
      });
    } catch (e) {
      setState(() => _classesLoading = false);
    }
  }

  Future<void> _startSession() async {
    if (_selectedClassId == null) {
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

    setState(() => _isLoading = true);

    // Step 1: Get faculty's REAL GPS location
    final locationService = LocationService();
    final hasPermission = await locationService.checkAndRequestPermission();
    if (!hasPermission) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Location permission is required to start attendance session. Please enable location access.',
          ),
          backgroundColor: AppTheme.dangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final position = await locationService.getCurrentLocation();
    if (position == null) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to get your location. Please ensure:\n'
            '• GPS is enabled (toggle OFF/ON to reset)\n'
            '• Mock/fake location apps are disabled\n'
            '• You are in an open area for GPS signal',
          ),
          duration: const Duration(seconds: 6),
          backgroundColor: AppTheme.dangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);

      final response = await _dio.post(
        ApiEndpoints.startSession,
        data: {
          'classId': _selectedClassId,
          'timeSlot': _selectedTimeSlot,
          'latitude': position.latitude, // Use REAL faculty GPS
          'longitude': position.longitude, // Use REAL faculty GPS
          'radius': 30,
        },
        options: token != null
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final sessionData = response.data['session'];

      setState(() {
        _isLoading = false;
        _sessionStarted = true;
        _scannedCount = 0;
        _sessionSeconds = 0;
        _recentScans.clear();
        _sessionId = sessionData['id'];
        _sessionCode = sessionData['sessionCode'] ?? '';
      });
    } catch (e) {
      setState(() => _isLoading = false);

      String errorMsg = 'Failed to start session. Check backend connection.';
      if (e is DioException && e.response != null) {
        errorMsg = e.response?.data['message'] ?? errorMsg;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppTheme.dangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _sessionSeconds++);
    });

    // Poll live stats every 5 seconds
    _liveStatsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchLiveStats();
    });
  }

  /// Fetch fresh live stats from backend
  Future<void> _fetchLiveStats() async {
    if (_sessionId != null) {
      try {
        final token = await _storage.read(key: AppConstants.keyAuthToken);
        final res = await _dio.get(
          '${ApiEndpoints.baseUrl}/faculty/session/$_sessionId/live-count',
          options: token != null
              ? Options(headers: {'Authorization': 'Bearer $token'})
              : null,
        );

        if (mounted) {
          // ── Check if session was ended from the web display ──
          final bool isActive = res.data['isActive'] ?? true;
          if (!isActive) {
            // Session was ended externally (from web display)
            _liveStatsTimer?.cancel();
            _sessionTimer?.cancel();
            setState(() {
              _sessionStarted = false;
              _sessionId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Session was ended from the web display'),
                backgroundColor: AppTheme.warningColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            return;
          }

          final students = res.data['students'] as List;
          setState(() {
            _scannedCount = res.data['count'] ?? 0;
            _recentScans.clear();
            _recentScans.addAll(
              students.map<Map<String, String>>(
                (s) => {
                  'name': s['name'].toString(),
                  'time': _formatTimeFromIso(s['timestamp']),
                },
              ),
            );
          });
        }
      } catch (_) {
        // Silent catch for polling
      }
    }
  }

  String _formatTimeFromIso(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final m = dt.minute.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (e) {
      return '';
    }
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Generate dynamic time slots based on current time
  List<String> _generateTimeSlots() {
    final now = TimeOfDay.now();
    final slots = <String>[];

    // Start from 2 hours before current hour (min 7 AM), go until 7 PM
    final startHour = (now.hour - 2).clamp(7, 19);
    const endHour = 19; // 7 PM

    for (int h = startHour; h < endHour; h++) {
      final fromHour = h;
      final toHour = h + 1;
      slots.add('${_formatHour(fromHour)} - ${_formatHour(toHour)}');
    }

    return slots;
  }

  String _formatHour(int hour24) {
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0
        ? 12
        : hour24 > 12
        ? hour24 - 12
        : hour24;
    return '${hour12.toString().padLeft(2, '0')}:00 $period';
  }

  Future<void> _endSession() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Session'),
        content: Text(
          'Total students present: $_scannedCount\n\n'
          'Are you sure you want to stop the session? This will also stop the display on the web.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _liveStatsTimer?.cancel();
    _sessionTimer?.cancel();

    // Call backend
    if (_sessionId != null) {
      try {
        final token = await _storage.read(key: AppConstants.keyAuthToken);
        await _dio.post(
          '${ApiEndpoints.baseUrl}/faculty/session/$_sessionId/end',
          options: token != null
              ? Options(headers: {'Authorization': 'Bearer $token'})
              : null,
        );
      } catch (_) {
        // Ignore error on session end call best-effort
      }
    }

    if (mounted) {
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
      setState(() {
        _sessionStarted = false;
        _sessionId = null;
      });
    }
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
                _classesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _classes.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.warningColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.warningColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No classes found. Create a class first.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.warningColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Choose Class',
                          prefixIcon: const Icon(Icons.class_),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        value: _selectedClassId,
                        items: _classes.map((c) {
                          return DropdownMenuItem(
                            value: c['id'],
                            child: Text(c['name']!),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() {
                          _selectedClassId = v;
                          _selectedClassName = _classes.firstWhere(
                            (c) => c['id'] == v,
                          )['name'];
                        }),
                      ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Time Slot',
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  value: _selectedTimeSlot,
                  items: _generateTimeSlots().map((slot) {
                    return DropdownMenuItem(value: slot, child: Text(slot));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedTimeSlot = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startSession,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(_isLoading ? 'Starting...' : 'Start Session'),
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
          // ── Session Code Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'SESSION CODE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _sessionCode.isNotEmpty ? _sessionCode : '------',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Display on Classroom Screen',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Stats ──
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 24,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(_sessionSeconds),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Elapsed Time', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 24,
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_scannedCount',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Students Present',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Student List ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Student List',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_recentScans.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Live',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_recentScans.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 48,
                            color: AppTheme.textTertiary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No students joined yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentScans.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final scan = _recentScans[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  (idx + 1).toString(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                scan['name'] ?? 'Student',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              scan['time'] ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Stop Session Button ──
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _endSession,
              icon: const Icon(Icons.stop_circle_outlined, size: 24),
              label: const Text('Stop Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppTheme.dangerColor.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
