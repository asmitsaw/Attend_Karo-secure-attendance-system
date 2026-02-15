import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data_sources/student_service.dart';

final _studentServiceProvider = Provider((ref) => StudentService());

class StudentScheduleScreen extends ConsumerStatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  ConsumerState<StudentScheduleScreen> createState() =>
      _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends ConsumerState<StudentScheduleScreen> {
  List<Map<String, dynamic>> _lectures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    final service = ref.read(_studentServiceProvider);
    final data = await service.getSchedule();
    setState(() {
      _lectures = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('My Schedule'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lectures.isEmpty
          ? _buildEmpty(theme)
          : _buildSchedule(theme),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy,
            size: 72,
            color: AppTheme.textTertiary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Upcoming Lectures',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your scheduled lectures will appear here',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedule(ThemeData theme) {
    // Group lectures by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final lecture in _lectures) {
      final dateStr =
          lecture['lecture_date']?.toString().split('T').first ?? 'Unknown';
      grouped.putIfAbsent(dateStr, () => []).add(lecture);
    }

    final sortedDates = grouped.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadSchedule,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateStr = sortedDates[index];
          final dayLectures = grouped[dateStr]!;

          String displayDate;
          try {
            final d = DateTime.parse(dateStr);
            final now = DateTime.now();
            if (d.year == now.year &&
                d.month == now.month &&
                d.day == now.day) {
              displayDate = 'Today';
            } else if (d.year == now.year &&
                d.month == now.month &&
                d.day == now.day + 1) {
              displayDate = 'Tomorrow';
            } else {
              displayDate = DateFormat('EEEE, MMM d').format(d);
            }
          } catch (_) {
            displayDate = dateStr;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: 16),
              // Date header
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppTheme.accentPurple,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayDate,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${dayLectures.length} lecture${dayLectures.length > 1 ? 's' : ''}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...dayLectures.map((l) => _ScheduleCard(lecture: l)),
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> lecture;
  const _ScheduleCard({required this.lecture});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = lecture['title'] ?? 'Untitled Lecture';
    final subject = lecture['subject'] ?? '';
    final section = lecture['section'] ?? '';
    final facultyName = lecture['faculty_name'] ?? '';
    final room = lecture['room'];
    final notes = lecture['notes'];
    String startTime = '';
    String endTime = '';
    try {
      final st = lecture['start_time']?.toString() ?? '';
      startTime = st.length >= 5 ? st.substring(0, 5) : st;
      final et = lecture['end_time']?.toString() ?? '';
      endTime = et.length >= 5 ? et.substring(0, 5) : et;
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Time pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentPurple],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$startTime — $endTime',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              if (room != null && room.toString().isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      room.toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$subject — $section',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          if (facultyName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.person,
                  size: 14,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  facultyName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ],
          if (notes != null && notes.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                notes.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
