import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'upload_students_screen.dart';

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
  bool _isSubmitting = false;

  final List<String> _departments = [
    'Computer Science',
    'Information Technology',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
  ];

  final List<int> _semesters = [1, 2, 3, 4, 5, 6, 7, 8];

  // Simulated file upload state
  bool _fileUploaded = false;
  String _uploadedFileName = '';
  int _studentCount = 0;

  @override
  void dispose() {
    _subjectController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _simulateFileUpload() {
    setState(() {
      _fileUploaded = true;
      _uploadedFileName = 'CS_A_2024_students.csv';
      _studentCount = 52;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    await Future.delayed(const Duration(seconds: 2)); // Simulate API

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Create Class'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadStudentsScreen()),
              );
            },
            child: Text(
              'Upload List',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Info Section Header
              Text(
                'Class Information',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill in the details to create a new class',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 20),

              // ── Form Fields ──
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
                    Text(
                      'DEPARTMENT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.business,
                          color: AppTheme.textTertiary,
                        ),
                        hintText: 'Select Department',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.backgroundLight,
                      ),
                      initialValue: _selectedDepartment,
                      items: _departments.map((dept) {
                        return DropdownMenuItem(value: dept, child: Text(dept));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedDepartment = v),
                      validator: (v) =>
                          v == null ? 'Please select a department' : null,
                    ),
                    const SizedBox(height: 20),

                    // Subject
                    Text(
                      'SUBJECT NAME',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.book,
                          color: AppTheme.textTertiary,
                        ),
                        hintText: 'e.g., Data Structures',
                        fillColor: AppTheme.backgroundLight,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter subject name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Semester & Section row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SEMESTER',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.calendar_today,
                                    color: AppTheme.textTertiary,
                                  ),
                                  hintText: 'Sem',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.backgroundLight,
                                ),
                                initialValue: _selectedSemester,
                                items: _semesters.map((sem) {
                                  return DropdownMenuItem(
                                    value: sem,
                                    child: Text('$sem'),
                                  );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedSemester = v),
                                validator: (v) =>
                                    v == null ? 'Select semester' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SECTION',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _sectionController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.groups,
                                    color: AppTheme.textTertiary,
                                  ),
                                  hintText: 'e.g., A',
                                  fillColor: AppTheme.backgroundLight,
                                ),
                                textCapitalization:
                                    TextCapitalization.characters,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter section';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Upload Student List ──
              Text(
                'Student List',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload a CSV or XLSX file with student details',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 12),

              // Drag and drop zone
              GestureDetector(
                onTap: _simulateFileUpload,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _fileUploaded
                          ? AppTheme.successColor.withOpacity(0.3)
                          : AppTheme.primaryColor.withOpacity(0.2),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _fileUploaded
                              ? AppTheme.successColor.withOpacity(0.1)
                              : AppTheme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _fileUploaded
                              ? Icons.check_circle
                              : Icons.cloud_upload_outlined,
                          size: 28,
                          color: _fileUploaded
                              ? AppTheme.successColor
                              : AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fileUploaded
                            ? _uploadedFileName
                            : 'Tap to upload file',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _fileUploaded
                              ? AppTheme.successColor
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fileUploaded
                            ? '$_studentCount students loaded'
                            : 'CSV, XLSX (Max 5MB)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Preview Table ──
              if (_fileUploaded) ...[
                const SizedBox(height: 20),
                Text(
                  'Preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Roll',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Name',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Username',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Rows
                      _previewRow('001', 'Arjun Mehta', 'arjun.m'),
                      _previewRow('002', 'Priya Sengupta', 'priya.s'),
                      _previewRow('003', 'Rahul Verma', 'rahul.v'),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ── Submit Button ──
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
                    elevation: 4,
                    shadowColor: AppTheme.accentPurple.withOpacity(0.3),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Create Class'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewRow(String roll, String name, String username) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              roll,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(name, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            flex: 2,
            child: Text(
              username,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
