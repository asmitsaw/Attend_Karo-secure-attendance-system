import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class BatchDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> batch;

  const BatchDetailsScreen({super.key, required this.batch});

  @override
  State<BatchDetailsScreen> createState() => _BatchDetailsScreenState();
}

class _BatchDetailsScreenState extends State<BatchDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _batchNameController;
  late TextEditingController _startYearController;
  late TextEditingController _endYearController;
  late TextEditingController _sectionController;

  String? _selectedDepartment;
  int? _selectedSemester;

  bool _isSaving = false;
  bool _isDownloading = false;
  bool _isRegenerating = false;
  bool _isDeleting = false;

  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = true;

  final _dio = Dio();
  final _storage = const FlutterSecureStorage();

  final List<String> _departments = [
    'Computer Science',
    'Information Technology',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
  ];

  final List<int> _semesters = [1, 2, 3, 4, 5, 6, 7, 8];

  @override
  void initState() {
    super.initState();
    final b = widget.batch;
    _batchNameController = TextEditingController(text: b['batch_name']);
    _startYearController = TextEditingController(
      text: b['start_year'].toString(),
    );
    _endYearController = TextEditingController(
      text: b['end_year'] != null
          ? b['end_year'].toString()
          : (b['start_year'] + 4).toString(),
    );
    _sectionController = TextEditingController(text: b['section']);

    _selectedDepartment = b['department'];
    if (!_departments.contains(_selectedDepartment)) {
      if (_selectedDepartment != null &&
          !_departments.contains(_selectedDepartment)) {
        _selectedDepartment = null;
      }
    }

    _selectedSemester = b['current_semester'];
    _loadStudents();
  }

  @override
  void dispose() {
    _batchNameController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);

      await _dio.put(
        '${ApiEndpoints.updateBatch}/${widget.batch['id']}',
        data: {
          'batchName': _batchNameController.text.trim(),
          'department': _selectedDepartment,
          'startYear': _startYearController.text.trim(),
          'endYear': _endYearController.text.trim(),
          'semester': _selectedSemester,
          'section': _sectionController.text.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _downloadCredentials() async {
    setState(() => _isDownloading = true);
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);

      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      }

      var downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) throw 'Downloads folder not found';

      final fileName = 'credentials_${widget.batch['id']}.csv';
      final filePath = '${downloadsDir.path}/$fileName';

      await _dio.download(
        '${ApiEndpoints.downloadCredentials}/${widget.batch['id']}/credentials',
        filePath,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        _showDownloadSuccess(filePath);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Download failed';
        if (e is DioException) {
          if (e.response?.statusCode == 404) {
            msg = 'Credentials file not found. Please regenerate credentials.';
          } else {
            msg = e.message ?? msg;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _confirmRegenerate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Credentials?'),
        content: const Text(
          '⚠️ This will RESET passwords for ALL students in this batch.\n\nA new CSV file will be generated and downloaded.\n\nUse this only if original credentials are lost.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Regenerate & Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _regenerateCredentials();
    }
  }

  Future<void> _regenerateCredentials() async {
    setState(() => _isRegenerating = true);
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);

      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      }

      final response = await _dio.post(
        '${ApiEndpoints.regenerateCredentials}/${widget.batch['id']}/regenerate',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final csvContent = response.data['credentialsCSV'];

      var downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) throw 'Downloads folder not found';

      final fileName = 'credentials_${widget.batch['id']}_new.csv';
      final filePath = '${downloadsDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(csvContent);

      if (mounted) {
        _showDownloadSuccess(filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Batch Permanently?'),
        content: const Text(
          '⚠️ CRITICAL WARNING ⚠️\n\n'
          'This will delete:\n'
          '• This Batch (Name, Dept, etc)\n'
          '• ALL Students in this batch\n'
          '• ALL Class Enrollments for these students\n'
          '• ALL Attendance records for these students\n\n'
          'This action CANNOT be undone.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[900],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteBatch();
    }
  }

  Future<void> _deleteBatch() async {
    setState(() => _isDeleting = true);
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);

      await _dio.delete(
        '${ApiEndpoints.updateBatch}/${widget.batch['id']}', // Reusing base endpoint, differs by verb
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Return true to refresh list (which will now omit this batch)
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _loadStudents() async {
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      final response = await _dio.get(
        '${ApiEndpoints.updateBatch}/${widget.batch['id']}/students',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(
            response.data['students'],
          );
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      debugPrint('Load students error: $e');
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _resetDevice(String studentId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Device Binding?'),
        content: Text(
          'This will unbind $name\'s device. They will be logged out and can bind a new device on next login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      await _dio.put(
        '${ApiEndpoints.baseUrl}/admin/students/$studentId/reset-device',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device reset successfully')),
        );
      }
      _loadStudents(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showDownloadSuccess(String path) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Download Complete'),
        content: Text('Credentials saved to:\n$path'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.school,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Edit Batch Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _batchNameController,
                decoration: const InputDecoration(labelText: 'Batch Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: const InputDecoration(labelText: 'Department'),
                items: _departments
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedDepartment = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startYearController,
                      decoration: const InputDecoration(
                        labelText: 'Start Year',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _endYearController,
                      decoration: const InputDecoration(labelText: 'End Year'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedSemester,
                      decoration: const InputDecoration(labelText: 'Semester'),
                      items: _semesters
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text('$s')),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSemester = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _sectionController,
                      decoration: const InputDecoration(labelText: 'Section'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _isDownloading ? null : _downloadCredentials,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      )
                    : const Icon(Icons.download),
                label: const Text('Download Credentials CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 16),

              TextButton.icon(
                onPressed: _isRegenerating ? null : _confirmRegenerate,
                icon: _isRegenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: Colors.orange),
                label: Text(
                  'Regenerate Credentials (Resets Passwords)',
                  style: TextStyle(
                    color: _isRegenerating ? Colors.grey : Colors.orange,
                  ),
                ),
              ),

              const Divider(height: 32),

              ElevatedButton.icon(
                onPressed: _isDeleting ? null : _confirmDelete,
                label: const Text('Delete Batch Permanently'),
                icon: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.delete_forever),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              Text(
                'Enrolled Students (${_students.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              if (_isLoadingStudents)
                const Center(child: CircularProgressIndicator())
              else if (_students.isEmpty)
                const Center(child: Text('No students found.'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final isBound = student['device_id'] != null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(student['name'] ?? 'Unknown'),
                        subtitle: Text(student['roll_number'] ?? ''),
                        trailing: isBound
                            ? OutlinedButton(
                                onPressed: () => _resetDevice(
                                  student['id'],
                                  student['name'],
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                ),
                                child: const Text('Reset Device'),
                              )
                            : const Text(
                                'Unbound',
                                style: TextStyle(color: Colors.grey),
                              ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
