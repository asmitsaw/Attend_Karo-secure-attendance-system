import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/auth_provider.dart';
import 'presentation/admin/admin_dashboard_screen.dart';
import 'presentation/faculty/faculty_dashboard.dart';
import 'presentation/student/student_dashboard.dart';
import 'data/models/user_model.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attend Karo',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Show login if not authenticated
    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    // Show appropriate dashboard based on role
    if (authState.user?.role == UserRole.admin) {
      return const AdminDashboardScreen();
    } else if (authState.user?.role == UserRole.faculty) {
      return const FacultyDashboard();
    } else {
      return const StudentDashboard();
    }
  }
}
