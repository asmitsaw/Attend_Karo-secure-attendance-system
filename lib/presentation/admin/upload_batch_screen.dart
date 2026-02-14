import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/theme/app_theme.dart';

class UploadBatchScreen extends StatefulWidget {
  const UploadBatchScreen({super.key});

  @override
  State<UploadBatchScreen> createState() => _UploadBatchScreenState();
}

class _UploadBatchScreenState extends State<UploadBatchScreen> {
  final _formKey = GlobalKey<FormState>();

  final _batchNameController = TextEditingController();
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();
  final _sectionController = TextEditingController();

  String? _selectedDepartment;
  int? _selectedSemester;

  PlatformFile? _pickedFile;
  bool _isSubmitting = false;

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
  void dispose() {
    _batchNameController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _pickedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error picking file')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student CSV file')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await _storage.read(key: 'auth_token');

      String? fileName = _pickedFile!.name;

      // Determine how to send file bytes vs path depending on platform
      // For mobile, path usually works. For web (if supported later), bytes.
      // Dio FormData supports file from path.

      final formData = FormData.fromMap({
        'batchName': _batchNameController.text.trim(),
        'department': _selectedDepartment,
        'startYear': _startYearController.text.trim(),
        'endYear': _endYearController.text.trim(),
        'semester': _selectedSemester,
        'section': _sectionController.text.trim(),
        'file': await MultipartFile.fromFile(
          _pickedFile!.path!,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        ApiEndpoints.uploadStudentBatch,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final csvContent = data['credentialsCSV']; // The generated credentials

        if (mounted) {
          _showSuccessDialog(csvContent);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(String? csvContent) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Batch Created Successfully'),
        content: const Text(
          'Students have been enrolled and accounts created.\n\n'
          'Please download the credentials CSV file to distribute passwords to students.',
        ),
        actions: [
          if (csvContent != null)
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download Credentials'),
              onPressed: () {
                _saveCredentials(csvContent);
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Go back to dashboard
              },
            ),
          TextButton(
            child: const Text('Close'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveCredentials(String csvContent) async {
    try {
      // Permissions
      if (Platform.isAndroid) {
        // Check Android 13+ logic if needed, simplify for now
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      }

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) throw 'Downloads folder not found';

      final fileName =
          'credentials_${_batchNameController.text}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${downloadsDir.path}/$fileName');

      await file.writeAsString(csvContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Student Batch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _batchNameController,
                decoration: const InputDecoration(
                  labelText: 'Batch Name (e.g. CSE 2024-28)',
                ),
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
                      decoration: const InputDecoration(
                        labelText: 'Current Semester',
                      ),
                      items: _semesters
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSemester = v),
                      validator: (v) => v == null ? 'Required' : null,
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
              const SizedBox(height: 24),

              // File Picker
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _pickedFile != null
                      ? 'Selected: ${_pickedFile!.name}'
                      : 'Select CSV (UserID, Name, Email)',
                ),
              ),
              if (_pickedFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Size: ${_pickedFile!.size} bytes',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Batch & Accounts',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
