import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data_sources/student_service.dart';
import '../auth/auth_provider.dart';
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
    // Check device binding immediately, then every 5 seconds
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
            color: Colors.black.withOpacity(0.05),
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
                onTap: () => setState(() => _currentNavIndex = 0),
              ),
              _BottomNavItem(
                icon: Icons.calendar_today_rounded,
                label: 'Schedule',
                isActive: _currentNavIndex == 1,
                onTap: () => setState(() => _currentNavIndex = 1),
              ),
              // Center QR Scan button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QRScanScreen()),
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
                        color: AppTheme.primaryColor.withOpacity(0.3),
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
                onTap: () => setState(() => _currentNavIndex = 3),
              ),
              _BottomNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isActive: _currentNavIndex == 4,
                onTap: () => setState(() => _currentNavIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Student Home Page (Tab 0)
// ═══════════════════════════════════════════════
class _StudentHomePage extends ConsumerStatefulWidget {
  const _StudentHomePage();

  @override
  ConsumerState<_StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<_StudentHomePage> {
  List<Map<String, dynamic>> _liveSessions = [];
  List<Map<String, dynamic>> _enrolledClasses = [];
  Map<String, dynamic>? _report;
  bool _isLoadingLive = true;
  bool _isLoadingClasses = true;
  final StudentService _studentService = StudentService();
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 5 seconds for real-time updates
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshSilently();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Silent refresh — updates data without showing the loading spinner
  Future<void> _refreshSilently() async {
    try {
      _loadLiveSessions();
      _loadClasses();
      _loadReport();
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  Future<void> _loadData() async {
    _loadLiveSessions();
    _loadClasses();
    _loadReport();
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
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
                      const SizedBox(width: 12),
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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

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
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withOpacity(0.1),
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
                        const SizedBox(height: 12),
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
                              color: Colors.black.withOpacity(0.04),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.sensors_off,
                                size: 40,
                                color: AppTheme.textTertiary.withOpacity(0.4),
                              ),
                              const SizedBox(height: 12),
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

                      const SizedBox(height: 28),

                      // ── Quick Stats ──
                      Row(
                        children: [
                          Expanded(
                            child: _QuickStatCard(
                              icon: Icons.check_circle,
                              iconColor: AppTheme.successColor,
                              label: 'Present',
                              value: '${_report?['overall']?['present'] ?? 0}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickStatCard(
                              icon: Icons.cancel,
                              iconColor: AppTheme.dangerColor,
                              label: 'Absent',
                              value: '${_report?['overall']?['absent'] ?? 0}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickStatCard(
                              icon: Icons.percent,
                              iconColor: AppTheme.primaryColor,
                              label: 'Overall',
                              value:
                                  '${_report?['overall']?['percentage'] ?? 0}%',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Your Classes ──
                      Text(
                        'Your Classes',
                        style: theme.textTheme.titleLarge?.copyWith(
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
                              color: Colors.black.withOpacity(0.04),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.class_,
                                size: 40,
                                color: AppTheme.textTertiary.withOpacity(0.4),
                              ),
                              const SizedBox(height: 12),
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

  Widget _buildSessionCard(ThemeData theme, Map<String, dynamic> session) {
    final subject = session['subject'] ?? 'Unknown';
    final section = session['section'] ?? '';
    final facultyName = session['faculty_name'] ?? '';
    final alreadyMarked = session['already_marked'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
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
            color: AppTheme.primaryColor.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.class_,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$section • $facultyName',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.7),
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
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.2),
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
                      'LIVE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: alreadyMarked
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QRScanScreen()),
                      );
                    },
              icon: Icon(
                alreadyMarked ? Icons.check_circle : Icons.qr_code_scanner,
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClassesList(ThemeData theme) {
    // Build class cards from report data if available
    final reportClasses = List<Map<String, dynamic>>.from(
      _report?['classes'] ?? [],
    );

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

    // Fallback to enrolled classes
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

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ═══════════════════════════════════════════════
//  Private Widgets
// ═══════════════════════════════════════════════

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                code,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
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

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _QuickStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelSmall),
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
