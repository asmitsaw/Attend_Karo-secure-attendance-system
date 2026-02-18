import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data_sources/faculty_service.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import 'create_class_screen.dart';
import 'start_session_screen.dart';
import 'analytics_screen.dart';
import 'students_screen.dart';
import 'lecture_schedule_screen.dart';

class FacultyDashboard extends ConsumerStatefulWidget {
  const FacultyDashboard({super.key});

  @override
  ConsumerState<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends ConsumerState<FacultyDashboard> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentNavIndex,
        children: const [
          _FacultyHomePage(),
          AnalyticsScreen(),
          SizedBox(), // QR placeholder
          StudentsScreen(),
          LectureScheduleScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
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
                icon: Icons.analytics_rounded,
                label: 'Analytics',
                isActive: _currentNavIndex == 1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 1);
                },
              ),
              // Center Start Session button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const StartSessionScreen(),
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
                    Icons.sensors,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              _BottomNavItem(
                icon: Icons.people_rounded,
                label: 'Students',
                isActive: _currentNavIndex == 3,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 3);
                },
              ),
              _BottomNavItem(
                icon: Icons.event_note_rounded,
                label: 'Lectures',
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
//  Faculty Home Page (Tab 0) – Enhanced
// ═══════════════════════════════════════════════
class _FacultyHomePage extends ConsumerStatefulWidget {
  const _FacultyHomePage();

  @override
  ConsumerState<_FacultyHomePage> createState() => _FacultyHomePageState();
}

class _FacultyHomePageState extends ConsumerState<_FacultyHomePage> {
  final FacultyService _service = FacultyService();
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _liveSessions = [];
  List<Map<String, dynamic>> _todayLectures = [];
  List<Map<String, dynamic>> _sessionHistory = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;
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
    await Future.wait([
      _loadClasses(),
      _loadLiveSessions(),
      _loadTodayLectures(),
      _loadSessionHistory(),
      _loadAnalytics(),
    ]);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _refreshSilently();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadClasses() async {
    final classes = await _service.getClasses();
    if (mounted) setState(() => _classes = classes);
  }

  Future<void> _loadLiveSessions() async {
    final sessions = await _service.getLiveSessions();
    if (mounted) setState(() => _liveSessions = sessions);
  }

  Future<void> _loadTodayLectures() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lectures = await _service.getScheduledLectures(date: dateStr);
    if (mounted) setState(() => _todayLectures = lectures);
  }

  Future<void> _loadSessionHistory() async {
    final history = await _service.getSessionHistory();
    if (mounted) setState(() => _sessionHistory = history);
  }

  Future<void> _loadAnalytics() async {
    final data = await _service.getAnalytics();
    if (mounted) setState(() => _analytics = data);
  }

  // ── Computed Stats ──
  int get _totalSessionsThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _sessionHistory.where((s) {
      try {
        final d = DateTime.parse(s['created_at'] ?? '');
        return d.isAfter(weekStart.subtract(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).length;
  }

  int get _totalSessionsThisMonth {
    final now = DateTime.now();
    return _sessionHistory.where((s) {
      try {
        final d = DateTime.parse(s['created_at'] ?? '');
        return d.month == now.month && d.year == now.year;
      } catch (_) {
        return false;
      }
    }).length;
  }

  List<Map<String, dynamic>> get _recentActivity {
    // Return last 5 sessions with student count
    return _sessionHistory.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final classPerformance = List<Map<String, dynamic>>.from(
      _analytics['classPerformance'] ?? [],
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Compact Header ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF2B3D8F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & Logout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formattedDate(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showLogoutDialog(context, ref);
                        },
                        icon: Icon(
                          Icons.logout,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Welcome + Live badge
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user?.name ?? 'Professor'}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_liveSessions.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    const LectureScheduleScreen(
                                      initialTabIndex: 1,
                                    ),
                                transitionsBuilder: (_, anim, __, child) =>
                                    FadeTransition(opacity: anim, child: child),
                                transitionDuration: const Duration(
                                  milliseconds: 250,
                                ),
                              ),
                            ).then((_) => _refreshSilently());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF5252,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF5252),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_liveSessions.length} Live',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 9,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Stat Summary Row ──
                  Row(
                    children: [
                      _HeaderStat(
                        icon: Icons.class_,
                        value: '${_classes.length}',
                        label: 'Classes',
                      ),
                      const SizedBox(width: 8),
                      _HeaderStat(
                        icon: Icons.today,
                        value: '$_totalSessionsThisWeek',
                        label: 'This Week',
                      ),
                      const SizedBox(width: 8),
                      _HeaderStat(
                        icon: Icons.calendar_month,
                        value: '$_totalSessionsThisMonth',
                        label: 'This Month',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable Content ──
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Quick Actions ──
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.add_circle_outline,
                              label: 'Create Class',
                              color: AppTheme.primaryColor,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) =>
                                        const CreateClassScreen(),
                                    transitionsBuilder: (_, anim, __, child) =>
                                        SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0, 0.1),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: anim,
                                                  curve: Curves.easeOut,
                                                ),
                                              ),
                                          child: FadeTransition(
                                            opacity: anim,
                                            child: child,
                                          ),
                                        ),
                                    transitionDuration: const Duration(
                                      milliseconds: 300,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.sensors,
                              label: 'Start Session',
                              color: AppTheme.accentPurple,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) =>
                                        const StartSessionScreen(),
                                    transitionsBuilder: (_, anim, __, child) =>
                                        FadeTransition(
                                          opacity: anim,
                                          child: child,
                                        ),
                                    transitionDuration: const Duration(
                                      milliseconds: 250,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Today's Classes ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Today's Classes",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_todayLectures.length} scheduled',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_todayLectures.isEmpty)
                        _EmptyCard(
                          icon: Icons.event_busy,
                          title: 'No Classes Scheduled Today',
                          subtitle: 'Go to Lectures tab to schedule classes',
                        )
                      else
                        ..._todayLectures.map(
                          (lec) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TodayClassCard(
                              time: _formatTime(lec['start_time']),
                              title: lec['subject'] ?? lec['title'] ?? '',
                              subtitle:
                                  '${lec['section'] ?? ''} • ${lec['department'] ?? ''}',
                              location: lec['room'] ?? '',
                              isActive: _isLectureActive(lec),
                              onStartAttendance: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) =>
                                        const StartSessionScreen(),
                                    transitionsBuilder: (_, anim, __, child) =>
                                        FadeTransition(
                                          opacity: anim,
                                          child: child,
                                        ),
                                    transitionDuration: const Duration(
                                      milliseconds: 250,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // ── Class Performance ──
                      if (classPerformance.isNotEmpty) ...[
                        Text(
                          'Class Attendance',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...classPerformance.map((cp) {
                          final pct = cp['percentage'] ?? 0;
                          final totalSessions =
                              int.tryParse('${cp['total_sessions']}') ?? 0;
                          final badgeColor = pct >= 75
                              ? AppTheme.successColor
                              : pct >= 50
                              ? AppTheme.warningColor
                              : AppTheme.dangerColor;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.04),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Circular % indicator
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: pct / 100,
                                          strokeWidth: 4,
                                          backgroundColor: badgeColor
                                              .withValues(alpha: 0.15),
                                          valueColor: AlwaysStoppedAnimation(
                                            badgeColor,
                                          ),
                                        ),
                                        Text(
                                          '$pct%',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: badgeColor,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cp['subject'] ?? '',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          '${cp['section'] ?? ''} • $totalSessions sessions',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: AppTheme.textTertiary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      pct >= 75
                                          ? 'Good'
                                          : pct >= 50
                                          ? 'Low'
                                          : 'Critical',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: badgeColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],

                      // ── Recent Activity ──
                      if (_recentActivity.isNotEmpty) ...[
                        Text(
                          'Recent Activity',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Column(
                            children: _recentActivity.asMap().entries.map((
                              entry,
                            ) {
                              final idx = entry.key;
                              final session = entry.value;
                              final subject =
                                  session['subject'] ??
                                  session['class_subject'] ??
                                  'Session';
                              final count =
                                  session['attendance_count'] ??
                                  session['present_count'] ??
                                  '—';
                              final totalStudents =
                                  session['total_students'] ?? '';
                              String timeAgo = '';
                              try {
                                final d = DateTime.parse(
                                  session['created_at'] ?? '',
                                );
                                final diff = DateTime.now().difference(d);
                                if (diff.inMinutes < 60) {
                                  timeAgo = '${diff.inMinutes}m ago';
                                } else if (diff.inHours < 24) {
                                  timeAgo = '${diff.inHours}h ago';
                                } else {
                                  timeAgo = '${diff.inDays}d ago';
                                }
                              } catch (_) {}

                              return Column(
                                children: [
                                  if (idx > 0)
                                    Divider(
                                      height: 1,
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check_circle_outline,
                                            size: 16,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                subject,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppTheme.textPrimary,
                                                    ),
                                              ),
                                              Text(
                                                totalStudents
                                                        .toString()
                                                        .isNotEmpty
                                                    ? '$count/$totalStudents attended'
                                                    : '$count attended',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color:
                                                          AppTheme.textTertiary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          timeAgo,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: AppTheme.textTertiary,
                                                fontSize: 10,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── My Classes ──
                      Text(
                        'My Classes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_classes.isEmpty && !_isLoading)
                        _EmptyCard(
                          icon: Icons.class_,
                          title: 'No Classes Created',
                          subtitle: 'Tap Create Class to get started',
                          action: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateClassScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Create First Class'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        )
                      else
                        ..._classes.map((cls) {
                          final code = (cls['subject'] ?? 'XX')
                              .toString()
                              .split(' ')
                              .map((w) => w.isNotEmpty ? w[0] : '')
                              .take(2)
                              .join()
                              .toUpperCase();
                          final studentCount =
                              cls['student_count'] ??
                              cls['enrolled_count'] ??
                              0;

                          // Find attendance % from analytics
                          final perf = classPerformance.firstWhere(
                            (cp) =>
                                cp['id']?.toString() == cls['id']?.toString(),
                            orElse: () => {},
                          );
                          final pct = perf['percentage'] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SubjectTile(
                              code: code,
                              title: cls['subject'] ?? '',
                              subtitle:
                                  '${cls['section'] ?? ''} • $studentCount Students',
                              studentCount: '$studentCount',
                              attendancePct: pct is int ? pct : 0,
                            ),
                          );
                        }),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLectureActive(Map<String, dynamic> lec) {
    try {
      final now = TimeOfDay.now();
      final startParts = (lec['start_time'] ?? '00:00').split(':');
      final endParts = (lec['end_time'] ?? '00:00').split(':');
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final nowMinutes = now.hour * 60 + now.minute;
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } catch (_) {
      return false;
    }
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

  String _formattedDate() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month]} ${now.day}';
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

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
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
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: AppTheme.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

class _TodayClassCard extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final String location;
  final bool isActive;
  final VoidCallback? onStartAttendance;

  const _TodayClassCard({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.location,
    this.isActive = false,
    this.onStartAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(
                color: AppTheme.successColor.withValues(alpha: 0.3),
                width: 2,
              )
            : Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  time,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
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
                        'ACTIVE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.place, size: 12, color: AppTheme.textTertiary),
                const SizedBox(width: 3),
                Text(
                  location,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
          if (isActive && onStartAttendance != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStartAttendance,
                icon: const Icon(Icons.sensors, size: 16),
                label: const Text('Start Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String code;
  final String title;
  final String subtitle;
  final String studentCount;
  final int attendancePct;

  const _SubjectTile({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.studentCount,
    this.attendancePct = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = attendancePct >= 75
        ? AppTheme.successColor
        : attendancePct >= 50
        ? AppTheme.warningColor
        : attendancePct > 0
        ? AppTheme.dangerColor
        : AppTheme.textTertiary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
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
          if (attendancePct > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$attendancePct%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, size: 12, color: AppTheme.primaryColor),
                  const SizedBox(width: 3),
                  Text(
                    studentCount,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
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
