import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final String? role;
  final String? userName;
  final String? userEmail;
  final Map<String, dynamic>? userData;
  final String? errorMessage;

  AuthState({
    this.status = AuthStatus.initial,
    this.role,
    this.userName,
    this.userEmail,
    this.userData,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? role,
    String? userName,
    String? userEmail,
    Map<String, dynamic>? userData,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      role: role ?? this.role,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userData: userData ?? this.userData,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository = AuthRepository();
  final SecureStorageService _storage = SecureStorageService();

  AuthNotifier() : super(AuthState()) {
    checkSession();
  }

  Future<void> checkSession() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      final token = await _storage.getToken();

      if (token != null && token.isNotEmpty) {
        final profile = await _repository.getProfile();
        if (profile != null && profile['user'] != null) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            role: profile['user']['role'],
            userName: profile['user']['name'],
            userEmail: profile['user']['email'],
            userData: profile['user'],
          );
          return;
        }
      }
      await _storage.clearAuthData();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      // ignore: avoid_print
      print('[AUTH DIAGNOSTIC] checkSession failed: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    // ignore: avoid_print
    print('[AUTH DIAGNOSTIC] Login initiated for email: $email');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final data = await _repository.login(email, password);
      final user = data['user'];
      // ignore: avoid_print
      print('[AUTH DIAGNOSTIC] Login SUCCESS! User: ${user['email']}, Role: ${user['role']}');
      state = state.copyWith(
        status: AuthStatus.authenticated,
        role: user['role'],
        userName: user['name'],
        userEmail: user['email'],
        userData: user,
      );
      return true;
    } catch (e) {
      final rawError = e.toString().replaceAll('Exception: ', '');
      // ignore: avoid_print
      print('[AUTH DIAGNOSTIC] Login FAILURE: $rawError');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: rawError,
      );
      return false;
    }
  }

  Future<bool> uploadAvatar(File imageFile) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final data = await _repository.uploadAvatar(imageFile);
      final user = data['user'];
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userName: user['name'],
        userEmail: user['email'],
        userData: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
