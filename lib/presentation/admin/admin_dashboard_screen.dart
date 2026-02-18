import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import 'upload_batch_screen.dart';
import 'batch_details_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentNavIndex,
        children: const [
          _AdminHomePage(),
          _DeviceRequestsPage(),
          _SystemStatsPage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    // Count pending device requests for badge
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                icon: Icons.dashboard_rounded,
                label: 'Batches',
                isActive: _currentNavIndex == 0,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 0);
                },
              ),
              _BottomNavItem(
                icon: Icons.swap_horiz_rounded,
                label: 'Requests',
                isActive: _currentNavIndex == 1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 1);
                },
              ),
              _BottomNavItem(
                icon: Icons.insights_rounded,
                label: 'System',
                isActive: _currentNavIndex == 2,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentNavIndex = 2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Admin Home (Batch Management) – Enhanced
// ═══════════════════════════════════════════════
class _AdminHomePage extends ConsumerStatefulWidget {
  const _AdminHomePage();

  @override
  ConsumerState<_AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<_AdminHomePage> {
  final _dio = Dio();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<dynamic> _batches = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBatches() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      if (token == null) return;

      final response = await _dio.get(
        ApiEndpoints.getBatches,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          _batches = response.data['batches'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredBatches {
    if (_searchQuery.isEmpty) return _batches;
    final q = _searchQuery.toLowerCase();
    return _batches.where((b) {
      final name = (b['batch_name'] ?? '').toString().toLowerCase();
      final dept = (b['department'] ?? '').toString().toLowerCase();
      final section = (b['section'] ?? '').toString().toLowerCase();
      return name.contains(q) || dept.contains(q) || section.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final totalStudents = _batches.fold<int>(
      0,
      (sum, b) => sum + (int.tryParse('${b['student_count']}') ?? 0),
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF2B3D8F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Admin Panel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showLogoutDialog(context, ref);
                        },
                        icon: Icon(
                          Icons.logout,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hello, ${user?.name ?? 'Admin'}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderStat(
                          icon: Icons.groups,
                          value: '${_batches.length}',
                          label: 'Batches',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeaderStat(
                          icon: Icons.people,
                          value: '$totalStudents',
                          label: 'Students',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeaderStat(
                          icon: Icons.view_in_ar,
                          value:
                              '${_batches.where((b) {
                                final sec = b['section'];
                                return sec != null && sec.toString().isNotEmpty;
                              }).length}',
                          label: 'Sections',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Search Bar ──
            if (_batches.length > 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search batches...',
                    hintStyle: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppTheme.textTertiary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 18,
                              color: AppTheme.textTertiary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Batch List ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchBatches,
                      child: _filteredBatches.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.2,
                                ),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        _searchQuery.isNotEmpty
                                            ? Icons.search_off
                                            : Icons.school_outlined,
                                        size: 56,
                                        color: AppTheme.textTertiary.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No matching batches'
                                            : 'No Student Batches',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'Try a different search term'
                                            : 'Tap + to upload a new batch',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textTertiary,
                                            ),
                                      ),
                                      if (_searchQuery.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                          child: const Text('Clear Search'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _filteredBatches.length,
                              itemBuilder: (context, index) {
                                final batch = _filteredBatches[index];
                                return _BatchCard(
                                  batch: batch,
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final result = await Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (_, __, ___) =>
                                            BatchDetailsScreen(batch: batch),
                                        transitionsBuilder:
                                            (_, anim, __, child) =>
                                                SlideTransition(
                                                  position:
                                                      Tween<Offset>(
                                                        begin: const Offset(
                                                          0.05,
                                                          0,
                                                        ),
                                                        end: Offset.zero,
                                                      ).animate(
                                                        CurvedAnimation(
                                                          parent: anim,
                                                          curve: Curves.easeOut,
                                                        ),
                                                      ),
                                                  child: FadeTransition(
                                                    opacity: anim,
                                                    child: child,
                                                  ),
                                                ),
                                        transitionDuration: const Duration(
                                          milliseconds: 250,
                                        ),
                                      ),
                                    );
                                    if (result == true) _fetchBatches();
                                  },
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const UploadBatchScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 250),
            ),
          );
          _fetchBatches();
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Batch'),
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
                color: AppTheme.dangerColor.withValues(alpha: 0.1),
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
        content: const Text('Are you sure you want to logout?'),
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
}

// ═══════════════════════════════════════════════
//  Device Change Requests Page – Enhanced
// ═══════════════════════════════════════════════
class _DeviceRequestsPage extends ConsumerStatefulWidget {
  const _DeviceRequestsPage();

  @override
  ConsumerState<_DeviceRequestsPage> createState() =>
      _DeviceRequestsPageState();
}

class _DeviceRequestsPageState extends ConsumerState<_DeviceRequestsPage> {
  final _dio = Dio();
  final _storage = const FlutterSecureStorage();
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  int get _pendingCount => _requests
      .where((r) => r['status']?.toString().toUpperCase() == 'PENDING')
      .length;

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      if (token == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await _dio.get(
        ApiEndpoints.getDeviceRequests,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          _requests = response.data['requests'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load device requests error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRequest(String requestId, String action) async {
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      if (token == null) return;

      await _dio.put(
        ApiEndpoints.approveDeviceRequest(requestId),
        data: {'action': action},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'APPROVED'
                  ? 'Request approved. Device cleared.'
                  : 'Request rejected.',
            ),
            backgroundColor: action == 'APPROVED'
                ? AppTheme.successColor
                : AppTheme.dangerColor,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Device Requests'),
            if (_pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_pendingCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: _requests.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 56,
                                color: AppTheme.textTertiary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No Pending Requests',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Device change requests will appear here',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final req = _requests[index];
                        return _DeviceRequestCard(
                          request: req,
                          onApprove: () {
                            HapticFeedback.mediumImpact();
                            _handleRequest(req['id'].toString(), 'APPROVED');
                          },
                          onReject: () {
                            HapticFeedback.lightImpact();
                            _handleRequest(req['id'].toString(), 'REJECTED');
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════
//  System Stats Page (New Tab) – Admin Overview
// ═══════════════════════════════════════════════
class _SystemStatsPage extends ConsumerStatefulWidget {
  const _SystemStatsPage();

  @override
  ConsumerState<_SystemStatsPage> createState() => _SystemStatsPageState();
}

class _SystemStatsPageState extends ConsumerState<_SystemStatsPage> {
  final _dio = Dio();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      if (token == null) return;

      final response = await _dio.get(
        ApiEndpoints.getSystemStats,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          _stats = response.data ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load system stats';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('System Overview'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.dangerColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppTheme.dangerColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.dangerColor,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadStats,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Overview Cards Grid ──
                    Text(
                      'Real-time Overview',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _SystemStatCard(
                            icon: Icons.people_rounded,
                            label: 'Total Students',
                            value: '${_stats['totalStudents'] ?? 0}',
                            color: AppTheme.primaryColor,
                            gradient: const [
                              AppTheme.primaryColor,
                              Color(0xFF3042A3),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SystemStatCard(
                            icon: Icons.school_rounded,
                            label: 'Total Faculty',
                            value: '${_stats['totalFaculty'] ?? 0}',
                            color: AppTheme.accentPurple,
                            gradient: const [
                              AppTheme.accentPurple,
                              Color(0xFF7C4DFF),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SystemStatCard(
                            icon: Icons.sensors_rounded,
                            label: 'Active Sessions',
                            value: '${_stats['activeSessions'] ?? 0}',
                            color: AppTheme.successColor,
                            gradient: const [
                              AppTheme.successColor,
                              Color(0xFF4CAF50),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SystemStatCard(
                            icon: Icons.devices_rounded,
                            label: 'Pending Requests',
                            value: '${_stats['pendingDeviceRequests'] ?? 0}',
                            color: AppTheme.warningColor,
                            gradient: const [
                              AppTheme.warningColor,
                              Color(0xFFFFA726),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Today's Attendance ──
                    Text(
                      "Today's Attendance",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.04),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Circular Progress
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: CircularProgressIndicator(
                                    value:
                                        (_stats['todayAttendanceRate'] ?? 0) /
                                        100,
                                    strokeWidth: 8,
                                    backgroundColor: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppTheme.primaryColor,
                                        ),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_stats['todayAttendanceRate'] ?? 0}%',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primaryColor,
                                          ),
                                    ),
                                    Text(
                                      'Rate',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: AppTheme.textTertiary,
                                            fontSize: 9,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Present Today',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                                Text(
                                  '${_stats['presentToday'] ?? 0} / ${_stats['totalStudents'] ?? 0}',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'students marked present',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value:
                                        (_stats['todayAttendanceRate'] ?? 0) /
                                        100,
                                    minHeight: 6,
                                    backgroundColor: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppTheme.primaryColor,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Quick Insights ──
                    Text(
                      'Quick Insights',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _InsightCard(
                      icon: Icons.trending_up,
                      iconColor: AppTheme.successColor,
                      title: 'Active sessions right now',
                      value: '${_stats['activeSessions'] ?? 0} sessions',
                      subtitle: 'Faculty are currently taking attendance',
                    ),
                    const SizedBox(height: 8),
                    _InsightCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: AppTheme.warningColor,
                      title: 'Pending device requests',
                      value: '${_stats['pendingDeviceRequests'] ?? 0} requests',
                      subtitle: 'Students awaiting device change approval',
                    ),
                    const SizedBox(height: 8),
                    _InsightCard(
                      icon: Icons.person_add_alt_1,
                      iconColor: AppTheme.primaryColor,
                      title: 'System users',
                      value:
                          '${(_stats['totalStudents'] ?? 0) + (_stats['totalFaculty'] ?? 0)} total users',
                      subtitle:
                          '${_stats['totalStudents'] ?? 0} students + ${_stats['totalFaculty'] ?? 0} faculty',
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Private Widgets
// ═══════════════════════════════════════════════

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final List<Color> gradient;

  const _SystemStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _InsightCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 9,
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

// _StatBadge removed - unused

class _BatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  final VoidCallback onTap;

  const _BatchCard({required this.batch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = batch['batch_name'] ?? 'Unknown';
    final dept = batch['department'] ?? '';
    final section = batch['section'] ?? '';
    final year = batch['start_year']?.toString() ?? '';
    final endYear = (int.tryParse(year) != null
        ? (int.parse(year) + 4).toString()
        : '');
    final count = batch['student_count'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentPurple],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$dept${section.isNotEmpty ? ' • $section' : ''} • $year–$endYear',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textTertiary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DeviceRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentName = request['student_name'] ?? 'Unknown';
    final rollNo = request['roll_number'] ?? '';
    final reason = request['reason'] ?? '';
    final status = request['status'] ?? 'PENDING';
    final isPending = status.toString().toUpperCase() == 'PENDING';

    String dateStr = '';
    try {
      final d = DateTime.parse(request['created_at'].toString());
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
      dateStr = '${months[d.month]} ${d.day}, ${d.year}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? AppTheme.warningColor.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentPurple],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Roll: $rollNo',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPending
                      ? AppTheme.warningColor.withValues(alpha: 0.1)
                      : status.toString().toUpperCase() == 'APPROVED'
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : AppTheme.dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toString().toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isPending
                        ? AppTheme.warningColor
                        : status.toString().toUpperCase() == 'APPROVED'
                        ? AppTheme.successColor
                        : AppTheme.dangerColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Requested: $dateStr',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 9,
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerColor,
                      side: const BorderSide(color: AppTheme.dangerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Reject', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
