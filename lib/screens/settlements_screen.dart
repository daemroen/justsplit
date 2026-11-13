import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/settlement.dart';
import '../models/user_profile.dart';
import '../services/settlement_service.dart';
import '../services/user_service.dart';
import '../widgets/balance_summary_card.dart';

class SettlementsScreen extends StatelessWidget {
  final String groupId;
  final String currency;

  const SettlementsScreen({
    super.key,
    required this.groupId,
    this.currency = 'NOK',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settlements')),
      body: _SettlementsBody(groupId: groupId, currency: currency),
    );
  }
}

class _SettlementsBody extends StatelessWidget {
  final String groupId;
  final String currency;

  const _SettlementsBody({required this.groupId, required this.currency});

  @override
  Widget build(BuildContext context) {
    final settlementService =
        Provider.of<SettlementService>(context, listen: false);

    return StreamBuilder<List<Settlement>>(
      stream: settlementService.getAllSettlements(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allSettlements = snapshot.data ?? [];
        final pending = allSettlements
            .where((s) => s.status == SettlementStatus.pending)
            .toList();
        final confirmed = allSettlements
            .where((s) => s.status == SettlementStatus.confirmed)
            .toList();

        // Collect all user IDs
        final userIds = <String>{};
        for (final s in allSettlements) {
          userIds.add(s.fromUserId);
          userIds.add(s.toUserId);
        }

        return FutureBuilder<Map<String, UserProfile>>(
          future: Provider.of<UserService>(context, listen: false)
              .getUserProfiles(userIds.toList()),
          builder: (context, profileSnapshot) {
            final profiles = profileSnapshot.data ?? {};

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balances section
                _buildBalancesSection(
                    context, allSettlements, profiles),
                const SizedBox(height: 24),
                // Pending settlements
                if (pending.isNotEmpty) ...[
                  Text(
                    'Pending (${pending.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...pending.map((s) =>
                      _buildSettlementTile(context, s, profiles)),
                  const SizedBox(height: 24),
                ],
                // Settlement history
                if (confirmed.isNotEmpty) ...[
                  Text(
                    'History (${confirmed.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...confirmed.map((s) =>
                      _buildSettlementTile(context, s, profiles)),
                ],
                if (allSettlements.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No settlements yet.\nSplit a bill to get started!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBalancesSection(BuildContext context,
      List<Settlement> settlements, Map<String, UserProfile> profiles) {
    final balances = <String, double>{};
    for (final s in settlements) {
      if (s.status == SettlementStatus.pending) {
        balances[s.fromUserId] =
            (balances[s.fromUserId] ?? 0) - s.amount;
        balances[s.toUserId] =
            (balances[s.toUserId] ?? 0) + s.amount;
      }
    }

    if (balances.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Balances',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...balances.entries.map((entry) {
          final profile = profiles[entry.key];
          if (profile == null) return const SizedBox.shrink();
          return BalanceSummaryCard(
            profile: profile,
            amount: entry.value,
            currency: currency,
          );
        }),
      ],
    );
  }

  Widget _buildSettlementTile(BuildContext context, Settlement settlement,
      Map<String, UserProfile> profiles) {
    final from = profiles[settlement.fromUserId];
    final to = profiles[settlement.toUserId];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final canSettle = settlement.status == SettlementStatus.pending &&
        (settlement.fromUserId == currentUserId ||
            settlement.toUserId == currentUserId);

    return Card(
      child: ListTile(
        leading: Icon(
          settlement.status == SettlementStatus.confirmed
              ? Icons.check_circle
              : Icons.pending,
          color: settlement.status == SettlementStatus.confirmed
              ? Colors.green
              : Colors.orange,
        ),
        title: Text(
          '${from?.displayName ?? from?.email ?? 'Unknown'} owes ${to?.displayName ?? to?.email ?? 'Unknown'}',
        ),
        subtitle: settlement.status == SettlementStatus.confirmed &&
                settlement.settledAt != null
            ? Text(
                'Settled ${_formatDate(settlement.settledAt!)}')
            : Text('Created ${_formatDate(settlement.createdAt)}'),
        trailing: canSettle
            ? TextButton(
                onPressed: () => _markAsSettled(context, settlement),
                child: const Text('Mark Paid'),
              )
            : Text(
                '${settlement.amount.toStringAsFixed(2)} $currency',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Future<void> _markAsSettled(
      BuildContext context, Settlement settlement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content:
            Text('Mark ${settlement.amount.toStringAsFixed(2)} $currency as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final service =
          Provider.of<SettlementService>(context, listen: false);
      await service.markAsSettled(settlement.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
