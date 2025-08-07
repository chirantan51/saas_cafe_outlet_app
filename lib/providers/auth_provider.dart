import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ AuthProvider manages user authentication state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// ✅ AuthState: Holds the authentication token & status
class AuthState {
  final String? authToken;
  final bool isAuthenticated;

  AuthState({this.authToken, required this.isAuthenticated});
}

/// ✅ AuthNotifier: Handles login, logout, and token persistence
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState(isAuthenticated: false)) {
    _loadAuthToken(); // ✅ Load token on app start
  }

  /// ✅ Load authentication token from local storage
  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");
    if (token != null) {
      state = AuthState(authToken: token, isAuthenticated: true);
    }
  }

  /// ✅ Save token and update state on login
  Future<void> login(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token", token);
    state = AuthState(authToken: token, isAuthenticated: true);
  }

  /// ✅ Clear token and update state on logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("auth_token");
    state = AuthState(authToken: null, isAuthenticated: false);
  }
}
