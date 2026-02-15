import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data_sources/faculty_service.dart';

final _facultyServiceProvider = Provider((ref) => FacultyService());

class LectureScheduleScreen extends ConsumerStatefulWidget {
  const LectureScheduleScreen({super.key});

  @override
  ConsumerState<LectureScheduleScreen> createState() =>
      _LectureScheduleScreenState();
}

class _LectureScheduleScreenState extends ConsumerState<LectureScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _lectures = [];
  List<Map<String, dynamic>> _liveSessions = [];
  List<Map<String, dynamic>> _sessionHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final service = ref.read(_facultyServiceProvider);
    final results = await Future.wait([
      service.getClasses(),
      service.getScheduledLectures(),
      service.getLiveSessions(),
      service.getSessionHistory(),
    ]);
    setState(() {
      _classes = results[0];
      _lectures = results[1];
      _liveSessions = results[2];
      _sessionHistory = results[3];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Lectures & Sessions'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          tabs: const [
            Tab(text: 'Schedule'),
            Tab(text: 'Live'),
            Tab(text: 'History'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showScheduleDialog(context),
        backgroundColor: AppTheme.accentPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Schedule'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildScheduleTab(theme),
                _buildLiveTab(theme),
                _buildHistoryTab(theme),
              ],
            ),
    );
  }

  // ── Schedule Tab ──
  Widget _buildScheduleTab(ThemeData theme) {
    if (_lectures.isEmpty) {
      return _EmptyState(
        icon: Icons.event_note,
        title: 'No Lectures Scheduled',
        subtitle: 'Tap the + button to schedule a lecture',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _lectures.length,
        itemBuilder: (context, index) {
          final lecture = _lectures[index];
          return _LectureCard(
            lecture: lecture,
            onDelete: () => _deleteLecture(lecture),
          );
        },
      ),
    );
  }

  Future<void> _deleteLecture(Map<String, dynamic> lecture) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete,
                color: AppTheme.dangerColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Lecture'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${lecture['title']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final service = ref.read(_facultyServiceProvider);
    final result = await service.deleteLecture(lecture['id'].toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Done'),
          backgroundColor: result['success'] == true
              ? AppTheme.successColor
              : AppTheme.dangerColor,
        ),
      );
      if (result['success'] == true) _loadAll();
    }
  }

  // ── Live Tab ──
  Widget _buildLiveTab(ThemeData theme) {
    if (_liveSessions.isEmpty) {
      return _EmptyState(
        icon: Icons.sensors_off,
        title: 'No Live Sessions',
        subtitle: 'Start an attendance session from the dashboard',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _liveSessions.length,
        itemBuilder: (context, index) {
          final session = _liveSessions[index];
          return _LiveSessionCard(session: session);
        },
      ),
    );
  }

  // ── History Tab ──
  Widget _buildHistoryTab(ThemeData theme) {
    if (_sessionHistory.isEmpty) {
      return _EmptyState(
        icon: Icons.history,
        title: 'No Session History',
        subtitle: 'Past attendance sessions will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _sessionHistory.length,
        itemBuilder: (context, index) {
          final session = _sessionHistory[index];
          return _HistoryCard(session: session);
        },
      ),
    );
  }

  // ── Schedule Dialog ──
  void _showScheduleDialog(BuildContext context) {
    if (_classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No classes found. Create a class first from the dashboard.',
          ),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedClassId;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.event_available,
                            color: AppTheme.accentPurple,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Schedule Lecture',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Batch / Class selector
                    DropdownButtonFormField<String>(
                      value: selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'SELECT BATCH / CLASS',
                        prefixIcon: Icon(Icons.groups),
                      ),
                      isExpanded: true,
                      items: _classes.map((c) {
                        final classId = c['id']?.toString() ?? '';
                        final subject = c['subject'] ?? 'Unknown';
                        final section = c['section'] ?? '';
                        final department = c['department'] ?? '';
                        final semester = c['semester']?.toString() ?? '';
                        return DropdownMenuItem(
                          value: classId,
                          child: Text(
                            '$subject — $section${department.isNotEmpty ? ' • $department' : ''}${semester.isNotEmpty ? ' (Sem $semester)' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setModalState(() => selectedClassId = v),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'LECTURE TITLE',
                        hintText: 'e.g. Introduction to Networking',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: const Text(
                        'Date',
                        style: TextStyle(fontSize: 11),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setModalState(() => selectedDate = date);
                        }
                      },
                    ),

                    // Time pickers
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.access_time,
                              color: AppTheme.successColor,
                              size: 20,
                            ),
                            title: Text(startTime.format(context)),
                            subtitle: const Text(
                              'Start',
                              style: TextStyle(fontSize: 11),
                            ),
                            onTap: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (t != null) {
                                setModalState(() => startTime = t);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.access_time_filled,
                              color: AppTheme.dangerColor,
                              size: 20,
                            ),
                            title: Text(endTime.format(context)),
                            subtitle: const Text(
                              'End',
                              style: TextStyle(fontSize: 11),
                            ),
                            onTap: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (t != null) {
                                setModalState(() => endTime = t);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Room
                    TextFormField(
                      controller: roomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ROOM (OPTIONAL)',
                        hintText: 'e.g. Room 302',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'NOTES (OPTIONAL)',
                        hintText: 'Additional instructions...',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (selectedClassId == null ||
                                    selectedClassId!.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select a batch/class',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (titleCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a lecture title',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final dateStr = DateFormat(
                                  'yyyy-MM-dd',
                                ).format(selectedDate);
                                final startStr =
                                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                                final endStr =
                                    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                                final service = ref.read(
                                  _facultyServiceProvider,
                                );
                                final result = await service.scheduleLecture(
                                  classId: selectedClassId!,
                                  title: titleCtrl.text.trim(),
                                  lectureDate: dateStr,
                                  startTime: startStr,
                                  endTime: endStr,
                                  room: roomCtrl.text.trim().isEmpty
                                      ? null
                                      : roomCtrl.text.trim(),
                                  notes: notesCtrl.text.trim().isEmpty
                                      ? null
                                      : notesCtrl.text.trim(),
                                );

                                setModalState(() => isSubmitting = false);

                                if (ctx.mounted) Navigator.pop(ctx);

                                if (result['success'] == true) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '✅ Lecture scheduled successfully!',
                                        ),
                                        backgroundColor: AppTheme.successColor,
                                      ),
                                    );
                                  }
                                  _loadAll();
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error: ${result['message'] ?? 'Failed to schedule'}',
                                        ),
                                        backgroundColor: AppTheme.dangerColor,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          isSubmitting ? 'Scheduling...' : 'Schedule Lecture',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Reusable Cards ──

class _LectureCard extends StatelessWidget {
  final Map<String, dynamic> lecture;
  final VoidCallback? onDelete;
  const _LectureCard({required this.lecture, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = lecture['title'] ?? 'Untitled';
    final subject = lecture['subject'] ?? '';
    final section = lecture['section'] ?? '';
    final department = lecture['department'] ?? '';
    final semester = lecture['semester']?.toString() ?? '';
    final room = lecture['room'] ?? 'TBD';
    final status = lecture['status'] ?? 'SCHEDULED';
    final dateStr = lecture['lecture_date']?.toString().split('T').first ?? '';
    final startTime = lecture['start_time']?.toString().substring(0, 5) ?? '';
    final endTime = lecture['end_time']?.toString().substring(0, 5) ?? '';

    String displayDate;
    try {
      final d = DateTime.parse(dateStr);
      displayDate = DateFormat('EEE, MMM d').format(d);
    } catch (_) {
      displayDate = dateStr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
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
          // Time pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  startTime,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  color: AppTheme.textTertiary.withOpacity(0.3),
                ),
                Text(
                  endTime,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subject — $section${department.isNotEmpty ? ' • $department' : ''}${semester.isNotEmpty ? ' Sem $semester' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      displayDate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      room,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'COMPLETED'
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: status == 'COMPLETED'
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTheme.dangerColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _LiveSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = session['subject'] ?? '';
    final section = session['section'] ?? '';
    final code = session['session_code'] ?? '';
    final presentCount = session['present_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, Color(0xFF2B3D8F)],
        ),
        borderRadius: BorderRadius.circular(18),
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
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.successColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE NOW',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Code: $code',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            section,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: Colors.white.withOpacity(0.8),
              ),
              const SizedBox(width: 6),
              Text(
                '$presentCount students marked',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _HistoryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = session['subject'] ?? '';
    final section = session['section'] ?? '';
    final present = int.tryParse('${session['present_count']}') ?? 0;
    final absent = int.tryParse('${session['absent_count']}') ?? 0;
    final isActive = session['is_active'] == true;
    final code = session['session_code'] ?? '';

    String dateStr = '';
    try {
      final d = DateTime.parse(session['start_time']);
      dateStr = DateFormat('MMM d, yyyy • h:mm a').format(d);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(
                color: AppTheme.successColor.withOpacity(0.3),
                width: 1.5,
              )
            : Border.all(color: Colors.black.withOpacity(0.04)),
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
              color: isActive
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActive ? Icons.sensors : Icons.history,
              color: isActive ? AppTheme.successColor : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$subject — $section',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                if (code.isNotEmpty)
                  Text(
                    'Code: $code',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$present',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel, size: 14, color: AppTheme.dangerColor),
                  const SizedBox(width: 2),
                  Text(
                    '$absent',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.dangerColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppTheme.textTertiary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}
