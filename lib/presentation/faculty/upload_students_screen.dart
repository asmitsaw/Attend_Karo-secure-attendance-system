import 'package:flutter/material.dart';

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
    // For now, simulate with mock data
    setState(() {
      _students = [
        {'roll': '001', 'name': 'John Doe', 'username': 'john.doe'},
        {'roll': '002', 'name': 'Jane Smith', 'username': 'jane.smith'},
        {'roll': '003', 'name': 'Mike Johnson', 'username': 'mike.johnson'},
      ];
    });
  }

  Future<void> _uploadStudents() async {
    setState(() => _isUploading = true);

    // TODO: Call backend API to upload students
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Students uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Students')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'CSV Format',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Required columns:\n'
                      '• Roll Number\n'
                      '• Student Name\n'
                      '• Username',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pick File Button
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select CSV File'),
            ),
            const SizedBox(height: 24),

            // Preview
            if (_students.isNotEmpty) ...[
              Text(
                'Preview (${_students.length} students)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(student['roll'] ?? ''),
                        ),
                        title: Text(student['name'] ?? ''),
                        subtitle: Text(student['username'] ?? ''),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Upload Button
              ElevatedButton(
                onPressed: _isUploading ? null : _uploadStudents,
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
            ],
          ],
        ),
      ),
    );
  }
}
