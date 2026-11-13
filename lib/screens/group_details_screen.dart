import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/group.dart';
import '../models/receipt.dart';
import '../models/settlement.dart';
import '../models/user_profile.dart';
import '../services/group_service.dart';
import '../services/receipt_service.dart';
import '../services/settlement_service.dart';
import '../services/user_service.dart';
import '../widgets/balance_summary_card.dart';
import '../widgets/member_tile.dart';
import 'group_settings_screen.dart';
import 'receipt_detail_screen.dart';
import 'settlements_screen.dart';

class GroupDetailsScreen extends StatelessWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final groupService = Provider.of<GroupService>(context, listen: false);

    return StreamBuilder<Group>(
      stream: groupService.streamGroup(group.id),
      initialData: group,
      builder: (context, snapshot) {
        final currentGroup = snapshot.data ?? group;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(currentGroup.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GroupSettingsScreen(group: currentGroup),
                      ),
                    );
                  },
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.people), text: 'Members'),
                  Tab(icon: Icon(Icons.receipt_long), text: 'Receipts'),
                  Tab(icon: Icon(Icons.account_balance_wallet), text: 'Settle'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _MembersTab(group: currentGroup),
                _ReceiptsTab(group: currentGroup),
                _SettlementsTab(group: currentGroup),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showAddMemberDialog(context, currentGroup),
              tooltip: 'Add Member',
              child: const Icon(Icons.person_add),
            ),
          ),
        );
      },
    );
  }

  void _showAddMemberDialog(BuildContext context, Group currentGroup) {
    final userService = Provider.of<UserService>(context, listen: false);
    final groupService = Provider.of<GroupService>(context, listen: false);
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Member'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search by email',
                        hintText: 'e.g. user@example.com',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // Add guest button
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddGuestDialog(context, currentGroup);
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Add guest without account'),
                    ),
                    const SizedBox(height: 12),
                    if (searchController.text.length >= 3)
                      SizedBox(
                        height: 200,
                        child: FutureBuilder<List<UserProfile>>(
                          future: userService
                              .searchUsersByEmail(searchController.text),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final results = snapshot.data ?? [];
                            final filteredResults = results
                                .where((user) =>
                                    !currentGroup.members.contains(user.uid))
                                .toList();

                            if (filteredResults.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No users found',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredResults.length,
                              itemBuilder: (context, index) {
                                final user = filteredResults[index];
                                return MemberTile(
                                  profile: user,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.add_circle,
                                        color: Colors.green),
                                    onPressed: () async {
                                      await groupService.addMember(
                                          currentGroup.id, user.uid);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${user.displayName ?? user.email} added'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      )
                    else
                      const SizedBox(
                        height: 50,
                        child: Center(
                          child: Text(
                            'Type at least 3 characters to search',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddGuestDialog(BuildContext context, Group currentGroup) {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Guest'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Ola Nordmann',
            prefixIcon: Icon(Icons.person_outline),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await groupService.addGuestMember(currentGroup.id, name);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name added as guest'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// --- Members Tab ---

class _MembersTab extends StatelessWidget {
  final Group group;
  const _MembersTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCreator = group.createdBy == currentUserId;

    return FutureBuilder<Map<String, UserProfile>>(
      future: userService.getUserProfiles(group.members),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final profiles = snapshot.data ?? {};
        final totalCount = group.members.length + group.guestMembers.length;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: totalCount,
          itemBuilder: (context, index) {
            // Registered members first, then guests
            if (index < group.members.length) {
              final uid = group.members[index];
              final profile = profiles[uid];

              if (profile == null) {
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(uid),
                  subtitle: const Text('Unknown user'),
                );
              }

              final isCurrentUser = uid == currentUserId;
              final canRemove = isCreator && !isCurrentUser;

              return MemberTile(
                profile: profile,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (uid == group.createdBy)
                      const Chip(label: Text('Admin')),
                    if (canRemove)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        onPressed: () =>
                            _confirmRemoveMember(context, profile),
                      ),
                  ],
                ),
              );
            } else {
              // Guest member
              final guestIndex = index - group.members.length;
              final guestName = group.guestMembers[guestIndex];

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  child: const Icon(Icons.person_outline),
                ),
                title: Text(guestName),
                subtitle: const Text('Guest'),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: () =>
                      _confirmRemoveGuest(context, guestName),
                ),
              );
            }
          },
        );
      },
    );
  }

  void _confirmRemoveMember(BuildContext context, UserProfile profile) {
    final groupService = Provider.of<GroupService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Remove ${profile.displayName ?? profile.email} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await groupService.removeMember(group.id, profile.uid);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${profile.displayName ?? profile.email} removed'),
                  ),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveGuest(BuildContext context, String guestName) {
    final groupService = Provider.of<GroupService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Guest'),
        content: Text('Remove $guestName from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await groupService.removeGuestMember(group.id, guestName);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$guestName removed')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// --- Receipts Tab ---

class _ReceiptsTab extends StatelessWidget {
  final Group group;
  const _ReceiptsTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final receiptService =
        Provider.of<ReceiptService>(context, listen: false);

    return StreamBuilder<List<Receipt>>(
      stream: receiptService.getReceiptsForGroup(group.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final receipts = snapshot.data ?? [];

        if (receipts.isEmpty) {
          return const Center(
            child: Text(
              'No receipts yet.\nScan a receipt to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: receipts.length,
          itemBuilder: (context, index) {
            final receipt = receipts[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long)),
                title: Text(receipt.restaurantName),
                subtitle: Text(
                    '${receipt.date.day}/${receipt.date.month}/${receipt.date.year}'),
                trailing: Text(
                  '${receipt.totalAmount.toStringAsFixed(2)} ${group.currency}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReceiptDetailScreen(
                        receipt: receipt,
                        currency: group.currency,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// --- Settlements Tab ---

class _SettlementsTab extends StatelessWidget {
  final Group group;
  const _SettlementsTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final settlementService =
        Provider.of<SettlementService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);

    return StreamBuilder<List<Settlement>>(
      stream: settlementService.getPendingSettlements(group.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final settlements = snapshot.data ?? [];

        if (settlements.isEmpty) {
          return const Center(
            child: Text(
              'All settled up!',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        // Collect user IDs for profiles
        final userIds = <String>{};
        for (final s in settlements) {
          userIds.add(s.fromUserId);
          userIds.add(s.toUserId);
        }

        return FutureBuilder<Map<String, UserProfile>>(
          future: userService.getUserProfiles(userIds.toList()),
          builder: (context, profileSnapshot) {
            final profiles = profileSnapshot.data ?? {};

            // Calculate balances
            final balances = <String, double>{};
            for (final s in settlements) {
              balances[s.fromUserId] =
                  (balances[s.fromUserId] ?? 0) - s.amount;
              balances[s.toUserId] =
                  (balances[s.toUserId] ?? 0) + s.amount;
            }

            return ListView(
              padding: const EdgeInsets.all(16),
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
                    currency: group.currency,
                  );
                }),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettlementsScreen(
                          groupId: group.id,
                          currency: group.currency,
                        ),
                      ),
                    );
                  },
                  child: const Text('View All Settlements'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
