import 'package:flutter/material.dart';

import 'admin_screen.dart';
import 'guard_home_screen.dart';
import 'login_screen.dart';
import 'models.dart';
import 'services.dart';
import 'supervisor_screen.dart';

class PatrolGuardApp extends StatefulWidget {
  const PatrolGuardApp({super.key});

  @override
  State<PatrolGuardApp> createState() => _PatrolGuardAppState();
}

class _PatrolGuardAppState extends State<PatrolGuardApp> {
  final storage = const GuardDeviceStorage();
  MobileAuthState? authState;
  bool isBooting = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final restoredState = await storage.readAuthState();

    setState(() {
      authState = restoredState;
      isBooting = false;
    });
  }

  Future<void> _login(MobileAuthState nextState) async {
    await storage.saveAuthState(nextState);

    setState(() {
      authState = nextState;
    });
  }

  Future<void> _logout() async {
    await storage.saveAuthState(null);

    setState(() {
      authState = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patrol Guard Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5B93A),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF08111F),
        cardTheme: const CardThemeData(
          color: Color(0xFF0E203A),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF12233D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: isBooting
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : authState == null
              ? LoginScreen(onLogin: _login)
              : RoleHomeScreen(
                  authState: authState!,
                  onLogout: _logout,
                ),
    );
  }
}

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({
    super.key,
    required this.authState,
    required this.onLogout,
  });

  final MobileAuthState authState;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    switch (authState.user.role) {
      case 'admin':
        return AdminScreen(
          authState: authState,
          onLogout: onLogout,
        );
      case 'supervisor':
        return SupervisorScreen(
          authState: authState,
          onLogout: onLogout,
        );
      default:
        return GuardHomeScreen(
          authState: authState,
          onLogout: onLogout,
        );
    }
  }
}
