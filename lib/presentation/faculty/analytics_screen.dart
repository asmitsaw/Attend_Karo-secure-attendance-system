import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPI Cards ──
            Row(
              children: [
                Expanded(
                  child: _KPICard(
                    icon: Icons.people,
                    iconColor: AppTheme.successColor,
                    title: 'Present Today',
                    value: '45/52',
                    trend: '+5%',
                    trendUp: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KPICard(
                    icon: Icons.percent,
                    iconColor: AppTheme.primaryColor,
                    title: 'Avg Attendance',
                    value: '87%',
                    trend: '+2.4%',
                    trendUp: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _KPICard(
              icon: Icons.warning_amber_rounded,
              iconColor: AppTheme.dangerColor,
              title: 'Proxy Attempts Blocked',
              value: '3',
              trend: '-12%',
              trendUp: false,
              fullWidth: true,
            ),
            const SizedBox(height: 24),

            // ── Attendance Trend Chart ──
            Text(
              'Attendance Trend',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last 7 sessions',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 220,
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
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
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 10,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          if (value.toInt() >= 0 &&
                              value.toInt() < labels.length) {
                            return Text(
                              labels[value.toInt()],
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textTertiary,
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 60,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 82),
                        FlSpot(1, 85),
                        FlSpot(2, 78),
                        FlSpot(3, 90),
                        FlSpot(4, 87),
                        FlSpot(5, 92),
                        FlSpot(6, 88),
                      ],
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: AppTheme.primaryColor,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.15),
                            AppTheme.primaryColor.withOpacity(0.02),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Late Scan Distribution ──
            Text(
              'Late Scan Distribution',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 200,
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
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
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 2,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = [
                            '0-1m',
                            '1-3m',
                            '3-5m',
                            '5-10m',
                            '10m+',
                          ];
                          if (value.toInt() >= 0 &&
                              value.toInt() < labels.length) {
                            return Text(
                              labels[value.toInt()],
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppTheme.textTertiary,
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  maxY: 10,
                  barGroups: [
                    _buildBarGroup(0, 8, AppTheme.successColor),
                    _buildBarGroup(1, 5, AppTheme.successColor),
                    _buildBarGroup(2, 3, AppTheme.warningColor),
                    _buildBarGroup(3, 2, AppTheme.warningColor),
                    _buildBarGroup(4, 1, AppTheme.dangerColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Security Logs ──
            Text(
              'Security Logs',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            _SecurityLogCard(
              icon: Icons.phone_android,
              title: 'Device Mismatch',
              student: 'John Doe (2023CS012)',
              time: '10:32 AM',
              severity: 'High',
              severityColor: AppTheme.dangerColor,
            ),
            const SizedBox(height: 10),
            _SecurityLogCard(
              icon: Icons.location_off,
              title: 'Outside Geo-fence',
              student: 'Jane Smith (2023CS045)',
              time: '10:28 AM',
              severity: 'Medium',
              severityColor: AppTheme.warningColor,
            ),
            const SizedBox(height: 10),
            _SecurityLogCard(
              icon: Icons.gps_off,
              title: 'Fake GPS Detected',
              student: 'Mike Johnson (2023EC019)',
              time: '09:55 AM',
              severity: 'Critical',
              severityColor: AppTheme.dangerColor,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 28,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  Private Widgets
// ═══════════════════════════════════════════════

class _KPICard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String trend;
  final bool trendUp;
  final bool fullWidth;

  const _KPICard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.trend,
    required this.trendUp,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trendColor = trendUp ? AppTheme.successColor : AppTheme.dangerColor;

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: trendColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 10,
                            color: trendColor,
                          ),
                          Text(
                            trend,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: trendColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityLogCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String student;
  final String time;
  final String severity;
  final Color severityColor;

  const _SecurityLogCard({
    required this.icon,
    required this.title,
    required this.student,
    required this.time,
    required this.severity,
    required this.severityColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: severityColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: severityColor, size: 20),
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
                  student,
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
                time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  severity,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: severityColor,
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
