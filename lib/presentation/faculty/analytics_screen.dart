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
          ? const Center(child: Text('Failed to load data'))
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final List<dynamic> classPerf = _data?['classPerformance'] ?? [];
    final List<dynamic> proxies = _data?['proxyAttempts'] ?? [];
    final int totalClasses = _data?['totalClasses'] ?? 0;

    // Filter/Select logic
    final selectedClass = _selectedClassId == null
        ? null
        : classPerf.firstWhere(
            (c) => c['id'].toString() == _selectedClassId,
            orElse: () => null,
          );

    return SingleChildScrollView(
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
                        child: Text('${c['subject']} (${c['section']})'),
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
            _buildStatCard(
              'Total Classes',
              '$totalClasses',
              Icons.class_,
              AppTheme.primaryColor,
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
                const SizedBox(width: 16),
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
            const SizedBox(height: 20),
            _buildClassDetailChart(selectedClass),
          ],

          const SizedBox(height: 24),
          const Text(
            'Proxy Attempts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(20),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallChart(List<dynamic> classPerf) {
    if (classPerf.isEmpty) return const SizedBox.shrink();

    // Bar chart showing avg % for each class
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Class Attendance Overview',
            style: TextStyle(fontWeight: FontWeight.bold),
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
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= classPerf.length)
                          return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            classPerf[idx]['subject'].toString().substring(
                              0,
                              3,
                            ),
                            style: const TextStyle(fontSize: 10),
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
                gridData: const FlGridData(show: false),
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
      return const Center(child: Text('No attendance data available'));
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '${cls['subject']} Attendance Distribution',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: present,
                    title: '${((present / total) * 100).round()}%',
                    color: AppTheme.successColor,
                    radius: 50,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: absent,
                    title: '${((absent / total) * 100).round()}%',
                    color: AppTheme.dangerColor,
                    radius: 50,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
              _legendItem('Present', AppTheme.successColor),
              const SizedBox(width: 20),
              _legendItem('Absent', AppTheme.dangerColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  Widget _buildProxyList(List<dynamic> proxies) {
    if (proxies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('No suspicious activity detected')),
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
            leading: const Icon(
              Icons.warning_amber,
              color: AppTheme.warningColor,
            ),
            title: Text(p['student_name'] ?? 'Unknown'),
            subtitle: Text(
              'Distance: ${p['distance']?.toStringAsFixed(1)}m • ${p['subject']}',
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
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final classPerf = _data?['classPerformance'] as List<dynamic>? ?? [];

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Attendance Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
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
                // Add specific class details here
              ] else ...[
                pw.Text(
                  'Overall Summary',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    <String>[
                      'Subject',
                      'Section',
                      'Total Sessions',
                      'Present',
                      'Absent',
                      '%',
                    ],
                    ...classPerf.map(
                      (c) => [
                        c['subject'].toString(),
                        c['section'].toString(),
                        c['total_sessions'].toString(),
                        c['total_present'].toString(),
                        c['total_absent'].toString(),
                        '${c['percentage'] ?? 0}%',
                      ],
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  String _getSelectedClassName() {
    if (_selectedClassId == null) return 'All Classes';
    final c = (_data?['classPerformance'] as List).firstWhere(
      (e) => e['id'].toString() == _selectedClassId,
      orElse: () => {'subject': 'Unknown'},
    );
    return c['subject'];
  }
}
