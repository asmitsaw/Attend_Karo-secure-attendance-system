import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';
import 'qr_scan_screen.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
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
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                      Text(
                        user?.name ?? 'Student',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                        },
                        icon: const Icon(Icons.logout, size: 22),
                        tooltip: 'Logout',
                      ),
                      const SizedBox(width: 4),
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
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Active Session Header ──
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
                                'Live Now',
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

                    // ── Active Session Card ──
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
                                      'Computer\nNetworks',
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            height: 1.2,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Room 302, Engineering Block',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Timer
                              Column(
                                children: [
                                  Text(
                                    'Ends in',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '15m',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Scan QR Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const QRScanScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.qr_code_scanner, size: 22),
                              label: const Text('Scan QR to Mark Attendance'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 4,
                                shadowColor: AppTheme.accentPurple.withOpacity(
                                  0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: AppTheme.successColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Device location verified',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Your Courses ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Courses',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'View All',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    _CourseCard(
                      code: 'DS',
                      title: 'Data Structures',
                      subtitle: 'CS-201 • 34/40 Sessions',
                      percentage: 85,
                      badgeLabel: 'Safe',
                      badgeColor: AppTheme.successColor,
                    ),
                    const SizedBox(height: 10),
                    _CourseCard(
                      code: 'OS',
                      title: 'Operating Systems',
                      subtitle: 'CS-204 • 26/40 Sessions',
                      percentage: 65,
                      badgeLabel: 'Critical',
                      badgeColor: AppTheme.dangerColor,
                    ),
                    const SizedBox(height: 10),
                    _CourseCard(
                      code: 'LA',
                      title: 'Linear Algebra',
                      subtitle: 'MA-102 • 38/41 Sessions',
                      percentage: 92,
                      badgeLabel: 'Excellent',
                      badgeColor: AppTheme.successColor,
                    ),
                    const SizedBox(height: 28),

                    // ── Quick Stats ──
                    Row(
                      children: [
                        Expanded(
                          child: _QuickStatCard(
                            icon: Icons.check_circle,
                            iconColor: AppTheme.successColor,
                            label: 'Total Present',
                            value: '98',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickStatCard(
                            icon: Icons.cancel,
                            iconColor: AppTheme.dangerColor,
                            label: 'Total Absent',
                            value: '12',
                          ),
                        ),
                      ],
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
      ),
    );
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
      padding: const EdgeInsets.all(20),
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
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
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
