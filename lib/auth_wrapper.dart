import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'services/user_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          // Ensure user profile exists in Firestore
          final userService =
              Provider.of<UserService>(context, listen: false);
          userService.ensureUserProfile(snapshot.data!);
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
