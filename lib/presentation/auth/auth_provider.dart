import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_endpoints.dart';
import '../../data/data_sources/auth_service.dart';
import '../../data/models/user_model.dart';

// Auth State
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
    );
  }
}

// Auth Notifier (Updated for Riverpod 3.x)
class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;

  @override
  AuthState build() {
    // This assumes authServiceProvider is available. Riverpod 2+ lazy loads.
    // It's safe to read here.
    _authService = ref.read(authServiceProvider);
    _checkAuthStatus();
    return AuthState();
  }

  Future<void> _checkAuthStatus() async {
    final isAuth = await _authService.isAuthenticated();
    if (isAuth) {
      // Restore user data from secure storage
      final userId = await _authService.getUserId();
      final role = await _authService.getUserRoleEnum();

      if (userId != null && role != null) {
        state = state.copyWith(
          isAuthenticated: true,
          user: UserModel(id: userId, username: '', name: '', role: role),
        );

        // Fetch full profile from backend to get the actual name
        try {
          final dio = Dio();
          final token = await _authService.getToken();
          String? profileEndpoint;
          if (role == UserRole.student) {
            profileEndpoint = '${ApiEndpoints.baseUrl}/student/profile';
          } else if (role == UserRole.faculty) {
            profileEndpoint = '${ApiEndpoints.baseUrl}/faculty/profile';
          }
          // Admin has no profile endpoint — skip fetch

          if (profileEndpoint != null) {
            final response = await dio.get(
              profileEndpoint,
              options: Options(headers: {'Authorization': 'Bearer $token'}),
            );
            final profile = response.data['profile'] ?? response.data['user'];
            if (profile != null) {
              state = state.copyWith(
                user: UserModel(
                  id: userId,
                  username: profile['username'] ?? '',
                  name: profile['name'] ?? '',
                  role: role,
                  department: profile['department'],
                ),
              );
            }
          } else {
            // For admin, restore name from storage
            final storedName = await _authService.getUserName();
            state = state.copyWith(
              user: UserModel(
                id: userId,
                username: '',
                name: storedName ?? 'Admin',
                role: role,
              ),
            );
          }
        } catch (e) {
          // Profile fetch failed — keep the basic user info, they're still authenticated
        }
      } else {
        // Invalid stored data — force logout
        await _authService.logout();
        state = AuthState();
      }
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    // Get Device ID for binding (Students only mostly, but safe to send always)
    String? deviceId;
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
      }
    } catch (e) {
      // Ignore device info errors, login might proceed without binding or backend handles it
    }

    final result = await _authService.login(
      username,
      password,
      deviceId: deviceId,
    );

    if (result['success'] == true) {
      // Create user model, assuming valid map
      UserModel? user;
      try {
        if (result['user'] is Map) {
          user = UserModel.fromJson(result['user']);
        } else if (result['user'] is UserModel) {
          user = result['user'];
        }
      } catch (e) {
        /* ignore parse error? */
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user:
            user ??
            UserModel(
              id: 'unknown',
              username: username,
              name: username,
              role: UserRole.student,
            ),
        error: null,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: result['message'] as String? ?? 'Login failed',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = AuthState();
  }
}

// Providers
final authServiceProvider = Provider((ref) => AuthService());

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
