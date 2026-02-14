import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'create_class_screen.dart';
import 'start_session_screen.dart';
import 'analytics_screen.dart';

class FacultyDashboard extends ConsumerWidget {
  const FacultyDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main scrollable content
            Column(
              children: [
                // Header (greeting + profile + logout)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good ${_timeOfDayGreeting()},',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.name != null
                                ? 'Prof. ${user!.name}'
                                : 'Professor',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) {
                                Navigator.of(context)
                                    .pushReplacementNamed('/login');
                              }
                            },
                            icon: const Icon(Icons.logout),
                            tooltip: 'Logout',
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                theme.primaryColor.withOpacity(0.15),
                            child: Text(
                              (user?.name.isNotEmpty ?? false)
                                  ? user!.name[0].toUpperCase()
                                  : 'F',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Stats row (cards like in design)
                        SizedBox(
                          height: 120,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _StatCard(
                                icon: Icons.class_outlined,
                                label: 'Active Today',
                                value: '3',
                                iconBackgroundColor:
                                    theme.primaryColor.withOpacity(0.1),
                                iconColor: theme.primaryColor,
                              ),
                              _StatCard(
                                icon: Icons.groups_outlined,
                                label: 'Total Students',
                                value: '142',
                                iconBackgroundColor:
                                    Colors.purple.withOpacity(0.08),
                                iconColor: Colors.purple,
                              ),
                              _StatCard(
                                icon: Icons.warning_amber_rounded,
                                label: 'Proxy Alerts',
                                value: '2',
                                iconBackgroundColor:
                                    Colors.orange.withOpacity(0.08),
                                iconColor: Colors.orange,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Recent classes header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Classes',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // Placeholder for full list
                              },
                              child: Text(
                                'View All',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Ongoing class -> primary CTA: Start Attendance (StartSessionScreen)
                        _ClassCard(
                          statusLabel: 'Ongoing',
                          statusColor: theme.primaryColor,
                          title: 'CS101 - Data Structures',
                          subtitle: 'B.Tech CS - Year 2',
                          timeText: '09:00 AM',
                          locationText: 'Room 304',
                          primaryButtonText: 'Start Attendance',
                          primaryIcon: Icons.qr_code_scanner_rounded,
                          onPrimaryPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StartSessionScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Upcoming class -> view details (could reuse CreateClassScreen for now)
                        _ClassCard(
                          statusLabel: 'Upcoming',
                          statusColor: Colors.grey.shade600,
                          statusBackground: Colors.grey.shade200,
                          title: 'CS202 - DBMS',
                          subtitle: 'B.Tech CS - Year 3',
                          timeText: '11:00 AM',
                          locationText: 'Lab 2',
                          primaryButtonText: 'View Details',
                          primaryIcon: Icons.visibility_outlined,
                          onPrimaryPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CreateClassScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Completed class -> analytics
                        _ClassCard(
                          statusLabel: 'Completed',
                          statusColor: Colors.green,
                          statusBackground: Colors.green.withOpacity(0.1),
                          title: 'CS305 - Network Security',
                          subtitle: 'M.Tech - Year 1',
                          timeText: 'Yesterday',
                          locationText: 'Room 101',
                          showFooter: true,
                          footerText: '45/50 Present',
                          footerActionText: 'View Report',
                          onFooterActionPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AnalyticsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Floating action button (create class)
            Positioned(
              right: 24,
              bottom: 80,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateClassScreen(),
                    ),
                  );
                },
                backgroundColor: theme.primaryColor,
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),

            // Bottom navigation style bar (non-routing visual only for now)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BottomNavItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      isActive: true,
                      onTap: () {},
                    ),
                    _BottomNavItem(
                      icon: Icons.menu_book_rounded,
                      label: 'Classes',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateClassScreen(),
                          ),
                        );
                      },
                    ),
                    _BottomNavItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Analytics',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnalyticsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeOfDayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Morning';
  if (hour < 17) return 'Afternoon';
  return 'Evening';
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconBackgroundColor;
  final Color iconColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconBackgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String statusLabel;
  final Color statusColor;
  final Color? statusBackground;
  final String title;
  final String subtitle;
  final String timeText;
  final String locationText;
  final String? primaryButtonText;
  final IconData? primaryIcon;
  final VoidCallback? onPrimaryPressed;
  final bool showFooter;
  final String? footerText;
  final String? footerActionText;
  final VoidCallback? onFooterActionPressed;

  const _ClassCard({
    required this.statusLabel,
    required this.statusColor,
    this.statusBackground,
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.locationText,
    this.primaryButtonText,
    this.primaryIcon,
    this.onPrimaryPressed,
    this.showFooter = false,
    this.footerText,
    this.footerActionText,
    this.onFooterActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground ??
                            statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locationText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (primaryButtonText != null && onPrimaryPressed != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPrimaryPressed,
                icon: Icon(primaryIcon ?? Icons.arrow_forward_rounded),
                label: Text(primaryButtonText!),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
          if (showFooter && (footerText != null || footerActionText != null))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (footerText != null)
                    Text(
                      footerText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (footerActionText != null &&
                      onFooterActionPressed != null)
                    TextButton(
                      onPressed: onFooterActionPressed,
                      child: Text(
                        footerActionText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
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
    final theme = Theme.of(context);

    final Color activeColor = theme.primaryColor;
    final Color inactiveColor = Colors.grey.shade500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: isActive ? activeColor : inactiveColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
