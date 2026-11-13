import 'package:flutter/material.dart';

import '../models/user_profile.dart';

class MemberTile extends StatelessWidget {
  final UserProfile profile;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MemberTile({
    super.key,
    required this.profile,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
        child: profile.photoUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(profile.displayName ?? profile.email),
      subtitle: profile.displayName != null ? Text(profile.email) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
