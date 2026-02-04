import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final User? user = authService.currentUser;

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: <Widget>[
        if (user != null)
          Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                user.displayName ?? 'User',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        const SizedBox(height: 30),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change Password'),
          onTap: () {
            //  password change logic
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete Account'),
          onTap: () {
            //  delete account logic
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => authService.signOut(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
}
