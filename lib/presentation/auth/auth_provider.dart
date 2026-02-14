import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      // TODO: Fetch user profile from backend if needed
      // Actually we should verify token validity
      state = state.copyWith(isAuthenticated: true);
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
