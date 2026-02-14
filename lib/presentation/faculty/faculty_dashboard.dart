import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';
import 'create_class_screen.dart';
import 'start_session_screen.dart';
import 'analytics_screen.dart';

class FacultyDashboard extends ConsumerStatefulWidget {
  const FacultyDashboard({super.key});

  @override
  ConsumerState<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends ConsumerState<FacultyDashboard> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Row(
                        children: [
                          // Notification bell
                          IconButton(
                            onPressed: () {},
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  color: Colors.white.withOpacity(0.85),
                                  size: 24,
                                ),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF5252),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          // Logout
                          IconButton(
                            onPressed: () async {
                              await ref.read(authProvider.notifier).logout();
                            },
                            icon: Icon(
                              Icons.logout,
                              color: Colors.white.withOpacity(0.85),
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Logout',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Welcome name
                  Text(
                    'Welcome,',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Text(
                    user?.name ?? 'Professor',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Secure Mode badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
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
                        const SizedBox(width: 6),
                        Text(
                          'Secure Mode Active',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Quick Action Buttons ──
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.qr_code_2,
                          label: 'Create New Class',
                          sublabel: 'Generate QR Code',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateClassScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.sensors,
                          label: 'Active Sessions',
                          sublabel: '• 1 Live Now',
                          sublabelColor: AppTheme.successColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StartSessionScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Today's Classes ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today's Classes",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'See All',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Class cards
                    _TodayClassCard(
                      time: '10:00 AM',
                      title: 'Computer Networks',
                      subtitle: 'CS-A (Batch 2024)',
                      location: 'Lab Complex 2, Room 304',
                      attendance: '49/52 Present',
                      isActive: true,
                      onStartAttendance: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StartSessionScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _TodayClassCard(
                      time: '08:30 AM',
                      title: 'Operating Systems',
                      subtitle: 'CS-B (Batch 2024)',
                      location: 'Room 201',
                      attendance: '',
                      isActive: false,
                    ),

                    const SizedBox(height: 28),

                    // ── My Subjects ──
                    Text(
                      'My Subjects',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _SubjectTile(
                      code: 'CN',
                      title: 'Computer Networks',
                      subtitle: 'CS-A • 3 Classes/Week',
                      percentage: '92%',
                      percentageColor: AppTheme.successColor,
                    ),
                    const SizedBox(height: 10),
                    _SubjectTile(
                      code: 'OS',
                      title: 'Operating Systems',
                      subtitle: 'CS-B • 4 Classes/Week',
                      percentage: '88%',
                      percentageColor: AppTheme.warningColor,
                    ),
                    const SizedBox(height: 10),
                    _SubjectTile(
                      code: 'DS',
                      title: 'Data Structures',
                      subtitle: 'CS-A • 2 Classes/Week',
                      percentage: '75%',
                      percentageColor: AppTheme.dangerColor,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBar: Container(
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
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  isActive: _currentNavIndex == 1,
                  onTap: () {
                    setState(() => _currentNavIndex = 1);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnalyticsScreen(),
                      ),
                    );
                  },
                ),
                // Center fab placeholder
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StartSessionScreen(),
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
                  icon: Icons.people_rounded,
                  label: 'Students',
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
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
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
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${months[now.month]} ${now.day}, ${days[now.weekday]}';
  }
}

// ═══════════════════════════════════════════════
//  Private Widgets
// ═══════════════════════════════════════════════

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color? sublabelColor;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    this.sublabelColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: sublabelColor ?? Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayClassCard extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final String location;
  final String attendance;
  final bool isActive;
  final VoidCallback? onStartAttendance;

  const _TodayClassCard({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.attendance,
    this.isActive = false,
    this.onStartAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isActive
            ? Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1.5,
              )
            : Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left time pill
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  time,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Vertical divider
          Container(
            width: 3,
            height: 60,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (attendance.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        attendance,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String code;
  final String title;
  final String subtitle;
  final String percentage;
  final Color percentageColor;

  const _SubjectTile({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.percentage,
    required this.percentageColor,
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
          // Code badge
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
          // Percentage
          Text(
            '$percentage Avg',
            style: theme.textTheme.titleSmall?.copyWith(
              color: percentageColor,
              fontWeight: FontWeight.w700,
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
