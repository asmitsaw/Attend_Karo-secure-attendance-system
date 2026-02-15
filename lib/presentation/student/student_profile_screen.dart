import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data_sources/student_service.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  final StudentService _service = StudentService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _currentDeviceId;
  String? _error;
  List<Map<String, dynamic>> _enrolledClasses = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await Future.wait([
      _loadProfile(),
      _loadEnrolledClasses(),
      _loadDeviceId(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _service.getProfile();
      if (mounted) {
        setState(() => _profile = profile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to load profile: $e');
      }
    }
  }

  Future<void> _loadDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _currentDeviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _currentDeviceId = iosInfo.identifierForVendor;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _currentDeviceId = windowsInfo.deviceId;
      }
    } catch (_) {}
  }

  Future<void> _loadEnrolledClasses() async {
    try {
      final classes = await _service.getEnrolledClasses();
      if (mounted) setState(() => _enrolledClasses = classes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(context, ref),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _profile == null
          ? _buildErrorView(theme)
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Avatar & Name ──
                    _buildProfileHeader(theme, authUser),
                    const SizedBox(height: 24),

                    // ── Info Cards ──
                    _buildInfoSection(theme, authUser),
                    const SizedBox(height: 24),

                    // ── Device Section ──
                    _buildDeviceSection(theme),
                    const SizedBox(height: 24),

                    // ── Logout Button ──
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showLogoutDialog(context, ref),
                        icon: const Icon(
                          Icons.logout,
                          color: AppTheme.dangerColor,
                        ),
                        label: const Text(
                          'Logout',
                          style: TextStyle(color: AppTheme.dangerColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.dangerColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.dangerColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load profile',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, dynamic authUser) {
    // Use data from API profile, fallback to auth user
    final name = _profile?['name']?.toString() ?? authUser?.name ?? 'Student';
    final rollNo = _profile?['roll_number']?.toString() ?? '';
    final dept = _profile?['department']?.toString() ?? '';

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.accentPurple],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (rollNo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            rollNo,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
        if (dept.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            dept,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoSection(ThemeData theme, dynamic authUser) {
    // Combine profile API data with auth user fallback
    final name = _profile?['name']?.toString() ?? authUser?.name ?? '-';
    final username =
        _profile?['username']?.toString() ?? authUser?.username ?? '-';
    final rollNo = _profile?['roll_number']?.toString() ?? '-';
    final email = _profile?['email']?.toString() ?? 'Not set';
    final department =
        _profile?['department']?.toString() ??
        authUser?.department ??
        'Not set';
    final enrolledClassesCount = _enrolledClasses.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Information',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _infoRow(theme, Icons.person, 'Name', name),
          _infoRow(theme, Icons.account_circle, 'Username', username),
          _infoRow(theme, Icons.badge, 'Roll Number', rollNo),
          _infoRow(
            theme,
            Icons.email,
            'Email',
            email == 'null' ? 'Not set' : email,
          ),
          _infoRow(
            theme,
            Icons.school,
            'Department',
            department == 'null' ? 'Not set' : department,
          ),
          _infoRow(
            theme,
            Icons.class_,
            'Enrolled Classes',
            '$enrolledClassesCount',
          ),
          if (_enrolledClasses.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Your Classes:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textTertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._enrolledClasses.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_right,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    Expanded(
                      child: Text(
                        '${c['subject']} (${c['section'] ?? ''})',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(ThemeData theme) {
    final boundDeviceId = _profile?['device_id']?.toString();
    final hasPendingRequest = _profile?['pending_device_request'] != null;
    final isBound = boundDeviceId != null && boundDeviceId.isNotEmpty;
    final isCurrentDevice =
        isBound &&
        _currentDeviceId != null &&
        boundDeviceId == _currentDeviceId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_android,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Device Binding',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Status Chip ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isBound
                  ? AppTheme.successColor.withOpacity(0.06)
                  : AppTheme.warningColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isBound ? Icons.check_circle : Icons.warning_amber,
                  size: 20,
                  color: isBound
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBound ? 'Device Bound' : 'No Device Bound',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isBound
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBound
                            ? 'ID: ${_truncateId(boundDeviceId)}'
                            : 'Scan a QR code to automatically bind your device.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isBound) ...[
            const SizedBox(height: 10),
            // Show whether current device matches bound device
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrentDevice
                    ? AppTheme.successColor.withOpacity(0.04)
                    : AppTheme.dangerColor.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isCurrentDevice ? Icons.verified : Icons.warning,
                    size: 16,
                    color: isCurrentDevice
                        ? AppTheme.successColor
                        : AppTheme.dangerColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCurrentDevice
                          ? 'This is your bound device ✓'
                          : 'This device does NOT match your bound device',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isCurrentDevice
                            ? AppTheme.successColor
                            : AppTheme.dangerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isBound && _profile?['device_bound_at'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Bound on: ${_formatDate(_profile!['device_bound_at'])}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Always show Request Change if bound (or even if unbound but user wants to fix it)
          // But technically only bound users need to change.
          // If not bound, they bind by logging in.
          if (hasPendingRequest)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warningColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.hourglass_top,
                    size: 18,
                    color: AppTheme.warningColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Device change request pending admin approval.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeviceChangeDialog(context),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Request Device Change'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
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

  String _truncateId(String? id) {
    if (id == null) return 'Unknown';
    if (id.length > 16) {
      return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
    }
    return id;
  }

  void _showDeviceChangeDialog(BuildContext context) {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.swap_horiz,
                color: AppTheme.warningColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Change Device'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for requesting a device change. The admin will review your request.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Lost my phone, Got a new device...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid reason (min 5 chars)'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final result = await _service.requestDeviceChange(reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: result['success']
                        ? AppTheme.successColor
                        : AppTheme.dangerColor,
                  ),
                );
                if (result['success']) _loadAll();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                Icons.logout,
                color: AppTheme.dangerColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout from Attend Karo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final d = DateTime.parse(dateStr.toString());
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
      return '${months[d.month]} ${d.day}, ${d.year}';
    } catch (_) {
      return dateStr.toString();
    }
  }
}
