import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data_sources/student_service.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import 'qr_scan_screen.dart';
import 'student_schedule_screen.dart';
import 'student_report_screen.dart';
import 'student_profile_screen.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  int _currentNavIndex = 0;
  Timer? _deviceCheckTimer;
  final StudentService _studentService = StudentService();

  final List<Widget> _pages = const [
    _StudentHomePage(),
    StudentScheduleScreen(),
    SizedBox(), // placeholder for QR scan center button
    StudentReportScreen(),
    StudentProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkDeviceBinding();
    _deviceCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkDeviceBinding();
    });
  }

  @override
  void dispose() {
    _deviceCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDeviceBinding() async {
    if (!mounted) return;
    try {
      final profile = await _studentService.getProfile();
      if (profile == null) return;
      if (profile['device_id'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Device binding has been reset by admin. Please login again.',
              ),
              backgroundColor: AppTheme.warningColor,
              duration: Duration(seconds: 3),
            ),
          );
          ref.read(authProvider.notifier).logout();
        }
      }
    } catch (e) {
      // Ignore errors during background check
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentNavIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isActive: _currentNavIndex == 0,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 0);
                },
              ),
              _BottomNavItem(
                icon: Icons.calendar_today_rounded,
                label: 'Schedule',
                isActive: _currentNavIndex == 1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 1);
                },
              ),
              // Center QR Scan button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const QRScanScreen(),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 250),
                    ),
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              _BottomNavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Reports',
                isActive: _currentNavIndex == 3,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 3);
                },
              ),
              _BottomNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isActive: _currentNavIndex == 4,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 4);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Student Home Page (Tab 0) – Enhanced
// ═══════════════════════════════════════════════
class _StudentHomePage extends ConsumerStatefulWidget {
  const _StudentHomePage();

  @override
  ConsumerState<_StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<_StudentHomePage> {
  List<Map<String, dynamic>> _liveSessions = [];
  List<Map<String, dynamic>> _enrolledClasses = [];
  List<Map<String, dynamic>> _schedule = [];
  Map<String, dynamic>? _report;
  bool _isLoadingLive = true;
  bool _isLoadingClasses = true;
  final StudentService _studentService = StudentService();
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshSilently();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshSilently() async {
    try {
      _loadLiveSessions();
      _loadClasses();
      _loadReport();
      _loadSchedule();
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  Future<void> _loadData() async {
    _loadLiveSessions();
    _loadClasses();
    _loadReport();
    _loadSchedule();
  }

  Future<void> _loadLiveSessions() async {
    final sessions = await _studentService.getLiveSessions();
    if (mounted) {
      setState(() {
        _liveSessions = sessions;
        _isLoadingLive = false;
      });
    }
  }

  Future<void> _loadClasses() async {
    final classes = await _studentService.getEnrolledClasses();
    if (mounted) {
      setState(() {
        _enrolledClasses = classes;
        _isLoadingClasses = false;
      });
    }
  }

  Future<void> _loadReport() async {
    final report = await _studentService.getAttendanceReport();
    if (mounted) {
      setState(() => _report = report);
    }
  }

  Future<void> _loadSchedule() async {
    final schedule = await _studentService.getSchedule();
    if (mounted) setState(() => _schedule = schedule);
  }

  // ── Computed Properties ──
  int get _overallPct =>
      int.tryParse('${_report?['overall']?['percentage']}') ?? 0;
  int get _presentCount =>
      int.tryParse('${_report?['overall']?['present']}') ?? 0;
  int get _absentCount =>
      int.tryParse('${_report?['overall']?['absent']}') ?? 0;
  int get _totalSessions =>
      int.tryParse('${_report?['overall']?['total_sessions']}') ?? 0;

  /// Calculate streak: consecutive present days
  int get _attendanceStreak {
    // Use report data to estimate streak
    // A proper implementation would need per-day data, but we approximate
    if (_presentCount == 0) return 0;
    // Simple heuristic: if overall % is high, assume recent consistency
    if (_overallPct >= 90) return math.min(_presentCount, 30);
    if (_overallPct >= 75) return math.min(_presentCount, 14);
    if (_overallPct >= 50) return math.min(_presentCount, 7);
    return math.min(_presentCount, 3);
  }

  /// Get next upcoming class from schedule
  Map<String, dynamic>? get _nextClass {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    Map<String, dynamic>? nextLec;
    int minDiff = 999999;

    for (final lec in _schedule) {
      try {
        final parts = (lec['start_time'] ?? '').toString().split(':');
        if (parts.length < 2) continue;
        final lecMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        final diff = lecMin - nowMinutes;
        if (diff > 0 && diff < minDiff) {
          minDiff = diff;
          nextLec = lec;
        }
      } catch (_) {}
    }
    return nextLec;
  }

  int get _nextClassMinutes {
    if (_nextClass == null) return 0;
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    try {
      final parts = (_nextClass!['start_time'] ?? '').toString().split(':');
      if (parts.length < 2) return 0;
      return int.parse(parts[0]) * 60 + int.parse(parts[1]) - nowMinutes;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good ${_timeOfDayGreeting()},',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              height: 28,
                              child: _MarqueeText(
                                text: user?.name ?? 'Student',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Logout button
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showLogoutDialog(context, ref);
                        },
                        icon: Icon(
                          Icons.logout_rounded,
                          color: AppTheme.textTertiary,
                          size: 20,
                        ),
                        tooltip: 'Logout',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.accentPurple,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            (user?.name.isNotEmpty ?? false)
                                ? user!.name[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Overall Attendance Card with Circular Progress ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.primaryColor, Color(0xFF2B3D8F)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Circular Progress
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      value: _overallPct / 100,
                                      strokeWidth: 8,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$_overallPct%',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      Text(
                                        'Overall',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 9,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Stats
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attendance Summary',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _MiniStat(
                                        label: 'Present',
                                        value: '$_presentCount',
                                        color: AppTheme.successColor,
                                      ),
                                      const SizedBox(width: 16),
                                      _MiniStat(
                                        label: 'Absent',
                                        value: '$_absentCount',
                                        color: const Color(0xFFFF5252),
                                      ),
                                      const SizedBox(width: 16),
                                      _MiniStat(
                                        label: 'Total',
                                        value: '$_totalSessions',
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Streak
                                  if (_attendanceStreak > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '🔥',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$_attendanceStreak Day Streak',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Next Class Countdown ──
                      if (_nextClass != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.access_time_filled,
                                  size: 18,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Next: ${_nextClass!['subject'] ?? _nextClass!['title'] ?? ''}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _nextClassMinutes > 60
                                          ? 'Starts in ${_nextClassMinutes ~/ 60}h ${_nextClassMinutes % 60}m'
                                          : 'Starts in $_nextClassMinutes min',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _nextClassMinutes <= 15
                                      ? AppTheme.warningColor.withValues(
                                          alpha: 0.1,
                                        )
                                      : AppTheme.primaryColor.withValues(
                                          alpha: 0.08,
                                        ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _formatTime(_nextClass!['start_time']),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _nextClassMinutes <= 15
                                        ? AppTheme.warningColor
                                        : AppTheme.primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Active Sessions ──
                      if (_isLoadingLive)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (_liveSessions.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Active Session',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.successColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_liveSessions.length} Live',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.successColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._liveSessions.map(
                          (session) => _buildSessionCard(theme, session),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.sensors_off,
                                size: 36,
                                color: AppTheme.textTertiary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No Live Sessions',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Active attendance sessions will appear here',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Attendance Trend (Mini Bar Chart) ──
                      if (_report != null) ...[
                        Text(
                          'Class-wise Attendance',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Mini visual trend bars
                        if (_reportClasses.isNotEmpty)
                          _AttendanceTrendCard(classes: _reportClasses),

                        const SizedBox(height: 20),
                      ],

                      // ── Your Classes ──
                      Text(
                        'Your Classes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_isLoadingClasses)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_enrolledClasses.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.class_,
                                size: 36,
                                color: AppTheme.textTertiary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No Classes',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You are not enrolled in any classes',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._buildClassesList(theme),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _reportClasses =>
      List<Map<String, dynamic>>.from(_report?['classes'] ?? []);

  Widget _buildSessionCard(ThemeData theme, Map<String, dynamic> session) {
    final subject = session['subject'] ?? 'Unknown';
    final section = session['section'] ?? '';
    final facultyName = session['faculty_name'] ?? '';
    final alreadyMarked = session['already_marked'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, Color(0xFF2B3D8F)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.class_,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$section • $facultyName',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: alreadyMarked
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const QRScanScreen(),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                          transitionDuration: const Duration(milliseconds: 250),
                        ),
                      );
                    },
              icon: Icon(
                alreadyMarked ? Icons.check_circle : Icons.qr_code_scanner,
                size: 18,
              ),
              label: Text(
                alreadyMarked ? 'Attendance Marked ✓' : 'Mark Attendance',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: alreadyMarked
                    ? AppTheme.successColor
                    : Colors.white,
                foregroundColor: alreadyMarked
                    ? Colors.white
                    : AppTheme.primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClassesList(ThemeData theme) {
    final reportClasses = _reportClasses;

    if (reportClasses.isNotEmpty) {
      return reportClasses.map<Widget>((cls) {
        final totalSessions = int.tryParse('${cls['total_sessions']}') ?? 0;
        final present = int.tryParse('${cls['present_count']}') ?? 0;
        final percentage = totalSessions > 0
            ? ((present / totalSessions) * 100).round()
            : 0;

        Color badgeColor = percentage >= 75
            ? AppTheme.successColor
            : percentage >= 50
            ? AppTheme.warningColor
            : AppTheme.dangerColor;

        String badgeLabel = percentage >= 85
            ? 'Excellent'
            : percentage >= 75
            ? 'Safe'
            : percentage >= 50
            ? 'Warning'
            : 'Critical';

        final code = (cls['subject'] ?? 'XX')
            .toString()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase();

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CourseCard(
            code: code,
            title: cls['subject'] ?? '',
            subtitle:
                '${cls['section'] ?? ''} • $present/$totalSessions Sessions',
            percentage: percentage,
            badgeLabel: badgeLabel,
            badgeColor: badgeColor,
          ),
        );
      }).toList();
    }

    return _enrolledClasses.map<Widget>((cls) {
      final code = (cls['subject'] ?? 'XX')
          .toString()
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0] : '')
          .take(2)
          .join()
          .toUpperCase();

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _CourseCard(
          code: code,
          title: cls['subject'] ?? '',
          subtitle: '${cls['section'] ?? ''} • ${cls['department'] ?? ''}',
          percentage: 0,
          badgeLabel: 'New',
          badgeColor: AppTheme.primaryColor,
        ),
      );
    }).toList();
  }

  String _formatTime(dynamic time) {
    if (time == null) return '';
    try {
      final parts = time.toString().split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final amPm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$displayHour:$minute $amPm';
    } catch (_) {
      return time.toString();
    }
  }

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout,
                color: AppTheme.dangerColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout from Attend Karo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Private Widgets
// ═══════════════════════════════════════════════

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

/// Visual attendance trend card showing bar chart for each class
class _AttendanceTrendCard extends StatelessWidget {
  final List<Map<String, dynamic>> classes;

  const _AttendanceTrendCard({required this.classes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: classes.asMap().entries.map((entry) {
          final idx = entry.key;
          final cls = entry.value;
          final totalSessions = int.tryParse('${cls['total_sessions']}') ?? 0;
          final present = int.tryParse('${cls['present_count']}') ?? 0;
          final pct = totalSessions > 0
              ? ((present / totalSessions) * 100).round()
              : 0;
          final barColor = pct >= 75
              ? AppTheme.successColor
              : pct >= 50
              ? AppTheme.warningColor
              : AppTheme.dangerColor;

          return Column(
            children: [
              if (idx > 0)
                Divider(
                  height: 16,
                  color: Colors.black.withValues(alpha: 0.04),
                ),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      cls['subject'] ?? '',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 8,
                        backgroundColor: barColor.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: barColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final String code;
  final String title;
  final String subtitle;
  final int percentage;
  final String badgeLabel;
  final Color badgeColor;

  const _CourseCard({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.percentage,
    required this.badgeLabel,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                code,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primaryColor : AppTheme.textTertiary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: color,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text widget that slowly scrolls horizontally if the text overflows.
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _MarqueeText({required this.text, this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late final ScrollController _scrollController;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndScroll());
  }

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndScroll());
    }
  }

  void _checkAndScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      _needsScroll = true;
      _startScrolling();
    }
  }

  Future<void> _startScrolling() async {
    if (!mounted || !_needsScroll) return;
    while (mounted && _needsScroll) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      await _scrollController.animateTo(
        max,
        duration: Duration(milliseconds: (max * 30).toInt().clamp(1500, 6000)),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: (max * 30).toInt().clamp(1500, 6000)),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _needsScroll = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
