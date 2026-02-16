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
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Container(
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
            title: Text(
              p['student_name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Distance: ${p['distance']?.toStringAsFixed(1)}m • ${p['subject'] ?? ''}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatDate(p['attempted_at']),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                  <String>['Student', 'Subject', 'Distance', 'Time'],
                  ...proxies.map(
                    (p) => [
                      p['student_name']?.toString() ?? 'Unknown',
                      p['subject']?.toString() ?? '',
                      '${p['distance']?.toStringAsFixed(1) ?? '?'}m',
                      _formatDate(p['attempted_at']),
                    ],
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
