import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _sectionController = TextEditingController();

  String? _selectedDepartment;
  int? _selectedSemester;
  String? _selectedBatchId;

  bool _isSubmitting = false;
  bool _isLoadingBatches = true;
  List<dynamic> _batches = [];

  final List<String> _departments = [
    'Computer Science',
    'Information Technology',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
  ];

  final List<int> _semesters = [1, 2, 3, 4, 5, 6, 7, 8];

  final _dio = Dio();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  Future<void> _fetchBatches() async {
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      if (token == null) return;

      final response = await _dio.get(
        ApiEndpoints.getFacultyBatches,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          _batches = response.data['batches'];
          _isLoadingBatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBatches = false);
        // Optional: show error toast
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);
      if (token == null) throw Exception('Not authenticated');

      await _dio.post(
        ApiEndpoints.createClass,
        data: {
          'department': _selectedDepartment,
          'subject': _subjectController.text.trim(),
          'semester': _selectedSemester,
          'section': _sectionController.text.trim(),
          'batchId': _selectedBatchId, // Send selected batch ID
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Class created successfully!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String errorMsg = 'Failed to create class';
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data['message'] ?? errorMsg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.dangerColor,
            behavior: SnackBarBehavior.floating,
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
        title: const Text('Create New Class'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Academic Batch Selection ──
              Text(
                'STUDENT BATCH',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingBatches
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.school,
                          color: AppTheme.textTertiary,
                        ),
                        hintText: 'Select Student Class (e.g. CSE A 2024)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      value: _selectedBatchId,
                      items: _batches.map<DropdownMenuItem<String>>((batch) {
                        return DropdownMenuItem(
                          value: batch['id'],
                          child: Text(
                            '${batch['batch_name']} (${batch['department']} - ${batch['section']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedBatchId = v;
                          // Auto-fill form based on batch if user hasn't selected yet?
                          // Maybe department/section logic
                          final batch = _batches.firstWhere(
                            (b) => b['id'] == v,
                            orElse: () => null,
                          );
                          if (batch != null) {
                            if (_selectedDepartment == null &&
                                _departments.contains(batch['department'])) {
                              _selectedDepartment = batch['department'];
                            }
                            // Auto set section if empty
                            if (_sectionController.text.isEmpty) {
                              _sectionController.text = batch['section'] ?? '';
                            }
                          }
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Please select a student batch' : null,
                    ),
              const SizedBox(height: 24),

              // ── Class Details ──
              Container(
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Department
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Department',
                      ),
                      value: _selectedDepartment,
                      items: _departments
                          .map(
                            (dept) => DropdownMenuItem(
                              value: dept,
                              child: Text(dept),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedDepartment = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Subject
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject (e.g. Data Structures)',
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Semester & Section
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Semester',
                            ),
                            value: _selectedSemester,
                            items: _semesters
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('$s'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedSemester = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _sectionController,
                            decoration: const InputDecoration(
                              labelText: 'Section',
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Subject Class'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
