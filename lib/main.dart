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

    // While checking auth status, show a branded splash screen
    // This prevents the flash of login screen before auto-login kicks in
    if (authState.isLoading) {
      return const _SplashScreen();
    }

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

/// Branded splash screen shown while restoring auth session
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.sensors, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              'Attend Karo',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Secure Attendance System',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
