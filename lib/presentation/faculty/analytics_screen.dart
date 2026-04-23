import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _selectedClassId; // null means 'All Classes'
  bool _proxyExpanded = false; // collapse proxy list by default

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      if (token == null) return;

      final response = await _dio.get(
        ApiEndpoints.getAnalytics,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          _data = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _data == null ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(context),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: AppTheme.textTertiary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load analytics',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final List<dynamic> classPerf = _data?['classPerformance'] ?? [];
    final List<dynamic> proxies = _data?['proxyAttempts'] ?? [];
    final int totalClasses = _data?['totalClasses'] ?? 0;
    final int totalSessions = _data?['totalSessions'] ?? 0;
    final Map<String, dynamic> riskInsights =
        (_data?['riskInsights'] as Map<String, dynamic>?) ?? {};

    // Filter/Select logic
    final selectedClass = _selectedClassId == null
        ? null
        : classPerf.firstWhere(
            (c) => c['id'].toString() == _selectedClassId,
            orElse: () => null,
          );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Class Selector ──
          if (classPerf.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedClassId,
                  hint: const Text('All Classes'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Classes'),
                    ),
                    ...classPerf.map(
                      (c) => DropdownMenuItem(
                        value: c['id'].toString(),
                        child: Text(
                          '${c['subject']} (${c['section']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedClassId = v),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // ── Summary Cards ──
          if (_selectedClassId == null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Classes',
                    '$totalClasses',
                    Icons.class_,
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Sessions',
                    '$totalSessions',
                    Icons.history,
                    AppTheme.accentPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildOverallChart(classPerf),
          ] else if (selectedClass != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Sessions',
                    '${selectedClass['total_sessions']}',
                    Icons.history,
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Avg Attendance',
                    '${selectedClass['percentage']}%',
                    Icons.percent,
                    AppTheme.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Present',
                    '${selectedClass['total_present'] ?? 0}',
                    Icons.check_circle,
                    AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Absent',
                    '${selectedClass['total_absent'] ?? 0}',
                    Icons.cancel,
                    AppTheme.dangerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildClassDetailChart(selectedClass),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Proxy Attempts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (proxies.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${proxies.length}',
                    style: TextStyle(
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProxyList(proxies),

          // ── AI Risk Intelligence ──
          const SizedBox(height: 32),
          _buildRiskIntelligenceSection(riskInsights),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── AI Risk Intelligence Section ──────────────────────────────────────────

  Widget _buildRiskIntelligenceSection(Map<String, dynamic> ri) {
    final totals = (ri['totals'] as Map<String, dynamic>?) ?? {};
    final dist   = (ri['distribution'] as Map<String, dynamic>?) ?? {};
    final risky  = (ri['topRiskyStudents'] as List<dynamic>?) ?? [];
    final sessRisk = (ri['sessionRisk'] as List<dynamic>?) ?? [];

    final suspicious = totals['suspicious'] as int? ?? 0;
    final clean      = totals['clean'] as int? ?? 0;
    final totalMarks = totals['total'] as int? ?? 0;
    final avgRisk    = (totals['avgRisk'] as num?)?.toDouble() ?? 0.0;

    final low      = dist['low'] as int? ?? 0;
    final moderate = dist['moderate'] as int? ?? 0;
    final elevated = dist['elevated'] as int? ?? 0;
    final high     = dist['high'] as int? ?? 0;
    final distTotal = (low + moderate + elevated + high).clamp(1, 999999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology, color: Colors.deepPurpleAccent, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🧠 AI Risk Intelligence',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Heuristic proxy detection engine · v1.0',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (suspicious > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.dangerColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    '$suspicious FLAGGED',
                    style: const TextStyle(
                      color: AppTheme.dangerColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Overview stats row
        Row(
          children: [
            Expanded(child: _buildStatCard('Suspicious', '$suspicious',
                Icons.gpp_bad, AppTheme.dangerColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Clean Marks', '$clean',
                Icons.verified_user, AppTheme.successColor)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Scans', '$totalMarks',
                Icons.qr_code_scanner, AppTheme.primaryColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Avg Risk', '${avgRisk.toStringAsFixed(0)}%',
                Icons.analytics, const Color(0xFF9C27B0))),
          ],
        ),
        const SizedBox(height: 20),

        // Risk Score Distribution Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Risk Score Distribution',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Based on $totalMarks total scan records',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
              const SizedBox(height: 16),
              _buildRiskDistributionBar('Low (0–24)', low, distTotal, const Color(0xFF4CAF50)),
              const SizedBox(height: 8),
              _buildRiskDistributionBar('Moderate (25–49)', moderate, distTotal, const Color(0xFFFF9800)),
              const SizedBox(height: 8),
              _buildRiskDistributionBar('Elevated (50–74)', elevated, distTotal, const Color(0xFFFF5722)),
              const SizedBox(height: 8),
              _buildRiskDistributionBar('High ≥75 (SUSPICIOUS)', high, distTotal, AppTheme.dangerColor),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Top Risky Students
        if (risky.isNotEmpty) ...[
          Row(
            children: [
              const Text('Flagged Students', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${risky.length}',
                    style: TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...risky.map((s) => _buildRiskyStudentCard(s)),
          const SizedBox(height: 20),
        ],

        // Session Risk Heatmap
        if (sessRisk.isNotEmpty) ...[
          const Text('High-Risk Sessions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...sessRisk.map((s) => _buildSessionRiskCard(s)),
        ],

        // Empty state when no risk data yet
        if (suspicious == 0 && risky.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.shield_outlined, size: 48, color: AppTheme.successColor.withOpacity(0.6)),
                const SizedBox(height: 12),
                const Text('No suspicious activity detected yet',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 6),
                Text(
                  'The AI engine will flag students after analyzing scan patterns, IP addresses, and timing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRiskDistributionBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Text('$count (${(pct * 100).round()}%)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskyStudentCard(dynamic s) {
    final name    = s['student_name']?.toString() ?? 'Unknown';
    final roll    = s['roll_number']?.toString() ?? '';
    final subject = s['subject']?.toString() ?? '';
    final section = s['section']?.toString() ?? '';
    final count   = s['flagged_count'] as int? ?? 0;
    final avgScore = s['avg_risk_score'] as int? ?? 0;
    final maxScore = s['max_risk_score'] as int? ?? 0;

    Color scoreColor = avgScore >= 75
        ? AppTheme.dangerColor
        : avgScore >= 50
            ? AppTheme.warningColor
            : const Color(0xFFFF9800);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dangerColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: AppTheme.dangerColor.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Row(
        children: [
          _buildRiskScoreBadge(avgScore, scoreColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (roll.isNotEmpty)
                  Text(roll, style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                const SizedBox(height: 4),
                Text(
                  '$subject${section.isNotEmpty ? ' · $section' : ''}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count flag${count == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppTheme.dangerColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text('Peak: $maxScore', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskScoreBadge(int score, Color color) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$score', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          Text('risk', style: TextStyle(color: color.withOpacity(0.7), fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildSessionRiskCard(dynamic s) {
    final subject    = s['subject']?.toString() ?? 'Session';
    final section    = s['section']?.toString() ?? '';
    final flagCount  = s['suspicious_count'] as int? ?? 0;
    final totalMarks = s['total_marks'] as int? ?? 0;
    final peakRisk   = s['peak_risk'] as int? ?? 0;
    final startRaw   = s['start_time']?.toString();
    String dateStr = '';
    if (startRaw != null) {
      try {
        final dt = DateTime.parse(startRaw).toLocal();
        dateStr = '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_fire_department, color: AppTheme.warningColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$subject${section.isNotEmpty ? ' ($section)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$flagCount / $totalMarks flagged',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.dangerColor)),
              Text('Peak risk: $peakRisk',
                  style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallChart(List<dynamic> classPerf) {
    if (classPerf.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Class Attendance Overview',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: classPerf.asMap().entries.map((e) {
                  final idx = e.key;
                  final c = e.value;
                  final pct = (c['percentage'] ?? 0).toDouble();
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: pct,
                        color: pct > 75
                            ? AppTheme.successColor
                            : pct > 50
                            ? AppTheme.warningColor
                            : AppTheme.dangerColor,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                maxY: 100,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
                      interval: 25,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= classPerf.length) {
                          return const Text('');
                        }
                        final subj = classPerf[idx]['subject'].toString();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            subj.length > 4 ? subj.substring(0, 4) : subj,
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassDetailChart(dynamic cls) {
    final present = (cls['total_present'] ?? 0).toDouble();
    final absent = (cls['total_absent'] ?? 0).toDouble();
    final total = present + absent;

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No attendance data available')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${cls['subject']} Attendance',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 45,
                sections: [
                  PieChartSectionData(
                    value: present,
                    title: '${((present / total) * 100).round()}%',
                    color: AppTheme.successColor,
                    radius: 55,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  PieChartSectionData(
                    value: absent,
                    title: '${((absent / total) * 100).round()}%',
                    color: AppTheme.dangerColor,
                    radius: 55,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(
                'Present (${present.toInt()})',
                AppTheme.successColor,
              ),
              const SizedBox(width: 24),
              _legendItem('Absent (${absent.toInt()})', AppTheme.dangerColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildProxyList(List<dynamic> proxies) {
    if (proxies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.verified_user,
              size: 40,
              color: AppTheme.successColor.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No suspicious activity detected',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All attendance records appear legitimate',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: proxies.length,
      itemBuilder: (ctx, i) {
        final p = proxies[i];
        final name = p['student_name'] ?? 'Unknown';
        final rollNo = p['roll_number'] ?? '';
        final reason = p['reason'] ?? 'Unknown reason';
        final subject = p['subject'] ?? '';
        final section = p['section'] ?? '';
        final distance = p['distance'];
        final distanceStr = distance != null
            ? '${double.tryParse(distance.toString())?.toStringAsFixed(0) ?? distance}m away'
            : null;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber,
                    color: AppTheme.warningColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatDate(p['attempted_at']),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                      if (rollNo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          rollNo,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.dangerColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (subject.isNotEmpty)
                            Text(
                              '$subject${section.isNotEmpty ? ' ($section)' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          if (subject.isNotEmpty && distanceStr != null)
                            Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          if (distanceStr != null)
                            Text(
                              distanceStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final classPerf = _data?['classPerformance'] as List<dynamic>? ?? [];
    final proxies = _data?['proxyAttempts'] as List<dynamic>? ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Attendance Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Attend Karo',
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated on: ${DateTime.now().toString().split('.')[0]}',
              style: const pw.TextStyle(color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 20),

            if (_selectedClassId != null) ...[
              pw.Text(
                'Class Report: ${_getSelectedClassName()}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              // Single class detail table
              _buildSingleClassPdfTable(classPerf),
            ] else ...[
              pw.Text(
                'Overall Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Total Classes: ${_data?['totalClasses'] ?? 0}',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                },
                data: <List<String>>[
                  <String>[
                    'Subject',
                    'Section',
                    'Sessions',
                    'Present',
                    'Absent',
                    'Attendance %',
                  ],
                  ...classPerf.map(
                    (c) => [
                      c['subject']?.toString() ?? '',
                      c['section']?.toString() ?? '',
                      c['total_sessions']?.toString() ?? '0',
                      c['total_present']?.toString() ?? '0',
                      c['total_absent']?.toString() ?? '0',
                      '${c['percentage'] ?? 0}%',
                    ],
                  ),
                ],
              ),
            ],

            // Proxy attempts section
            if (proxies.isNotEmpty) ...[
              pw.SizedBox(height: 24),
              pw.Text(
                'Proxy Attempts (${proxies.length})',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.red50,
                ),
                data: <List<String>>[
                  <String>['Student', 'Roll No', 'Reason', 'Subject', 'Distance', 'Time'],
                  ...proxies.map(
                    (p) {
                      final dist = p['distance'];
                      final distStr = dist != null
                          ? '${double.tryParse(dist.toString())?.toStringAsFixed(0) ?? dist}m'
                          : 'N/A';
                      return [
                        p['student_name']?.toString() ?? 'Unknown',
                        p['roll_number']?.toString() ?? '',
                        p['reason']?.toString() ?? 'Unknown',
                        p['subject']?.toString() ?? '',
                        distStr,
                        _formatDate(p['attempted_at']),
                      ];
                    },
                  ),
                ],
              ),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildSingleClassPdfTable(List<dynamic> classPerf) {
    final cls = classPerf.firstWhere(
      (c) => c['id'].toString() == _selectedClassId,
      orElse: () => null,
    );
    if (cls == null) return pw.Text('Class data not found');

    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      data: <List<String>>[
        <String>['Metric', 'Value'],
        ['Subject', cls['subject']?.toString() ?? ''],
        ['Section', cls['section']?.toString() ?? ''],
        ['Total Sessions', cls['total_sessions']?.toString() ?? '0'],
        ['Total Present', cls['total_present']?.toString() ?? '0'],
        ['Total Absent', cls['total_absent']?.toString() ?? '0'],
        ['Attendance %', '${cls['percentage'] ?? 0}%'],
      ],
    );
  }

  String _getSelectedClassName() {
    if (_selectedClassId == null) return 'All Classes';
    final classPerf = _data?['classPerformance'] as List? ?? [];
    final c = classPerf.firstWhere(
      (e) => e['id'].toString() == _selectedClassId,
      orElse: () => {'subject': 'Unknown'},
    );
    return c['subject']?.toString() ?? 'Unknown';
  }
}
