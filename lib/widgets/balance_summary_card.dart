import 'package:flutter/material.dart';

import '../models/user_profile.dart';

class BalanceSummaryCard extends StatelessWidget {
  final UserProfile profile;
  final double amount;
  final String currency;

  const BalanceSummaryCard({
    super.key,
    required this.profile,
    required this.amount,
    this.currency = 'NOK',
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = amount > 0;
    final isZero = amount.abs() < 0.01;
    final color = isZero
        ? Colors.grey
        : isPositive
            ? Colors.green
            : Colors.red;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: profile.photoUrl != null
              ? NetworkImage(profile.photoUrl!)
              : null,
          child:
              profile.photoUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(profile.displayName ?? profile.email),
        subtitle: Text(
          isZero
              ? 'Settled up'
              : isPositive
                  ? 'Is owed'
                  : 'Owes',
          style: TextStyle(color: color),
        ),
        trailing: Text(
          '${isPositive ? '+' : ''}${amount.toStringAsFixed(2)} $currency',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ),
    );
  }
}
