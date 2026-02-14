import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class UploadStudentsScreen extends StatefulWidget {
  const UploadStudentsScreen({super.key});

  @override
  State<UploadStudentsScreen> createState() => _UploadStudentsScreenState();
}

class _UploadStudentsScreenState extends State<UploadStudentsScreen> {
  List<Map<String, String>> _students = [];
  bool _isUploading = false;

  Future<void> _pickFile() async {
    // TODO: Implement file picker for CSV upload
    setState(() {
      _students = [
        {'roll': '001', 'name': 'Arjun Mehta', 'username': 'arjun.m'},
        {'roll': '002', 'name': 'Priya Sengupta', 'username': 'priya.s'},
        {'roll': '003', 'name': 'Rahul Verma', 'username': 'rahul.v'},
        {'roll': '004', 'name': 'Sneha Das', 'username': 'sneha.d'},
        {'roll': '005', 'name': 'Karan Kumar', 'username': 'karan.k'},
      ];
    });
  }

  Future<void> _uploadStudents() async {
    setState(() => _isUploading = true);

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Students uploaded successfully!'),
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
        title: const Text('Upload Students'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Instructions Card ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'CSV Format Required',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoLine('Roll Number'),
                  _infoLine('Student Name'),
                  _infoLine('Username / Email'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Pick File ──
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _students.isNotEmpty
                        ? AppTheme.successColor.withOpacity(0.3)
                        : AppTheme.primaryColor.withOpacity(0.2),
                    width: 2,
                  ),
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
                    Icon(
                      _students.isNotEmpty
                          ? Icons.check_circle
                          : Icons.cloud_upload,
                      size: 40,
                      color: _students.isNotEmpty
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _students.isNotEmpty
                          ? '${_students.length} students loaded'
                          : 'Tap to select CSV file',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _students.isNotEmpty
                            ? AppTheme.successColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CSV, XLSX supported',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Preview ──
            if (_students.isNotEmpty) ...[
              Text(
                'Preview (${_students.length} students)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
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
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _students.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.grey.shade100, height: 1),
                    itemBuilder: (context, index) {
                      final s = _students[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              s['roll'] ?? '',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          s['name'] ?? '',
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          s['username'] ?? '',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Upload Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadStudents,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isUploading
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
                      : const Text('Upload Students'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
