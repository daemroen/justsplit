import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/expense_allocation.dart';
import '../models/group.dart';
import '../models/receipt.dart';
import '../models/user_profile.dart';
import '../services/allocation_service.dart';
import '../services/receipt_service.dart';
import '../services/settlement_service.dart';
import '../services/split_calculation_service.dart';
import '../services/user_service.dart';

enum SplitMode { equal, perItem, custom }

class BillSplittingScreen extends StatefulWidget {
  final Receipt receipt;
  final Group group;

  const BillSplittingScreen({
    super.key,
    required this.receipt,
    required this.group,
  });

  @override
  State<BillSplittingScreen> createState() => _BillSplittingScreenState();
}

class _BillSplittingScreenState extends State<BillSplittingScreen> {
  SplitMode _splitMode = SplitMode.equal;
  String? _paidByUid;
  Map<String, UserProfile> _memberProfiles = {};
  bool _isLoading = true;
  bool _isSaving = false;

  /// All member IDs: registered UIDs + "guest:Name" for guests
  List<String> get _allMemberIds => widget.group.allMemberIds;

  // Per-item mode: itemIndex -> list of assigned member IDs (duplicates = extra shares)
  late Map<int, List<String>> _itemAssignments;

  // Custom mode: memberId -> amount controller
  late Map<String, TextEditingController> _customAmountControllers;

  @override
  void initState() {
    super.initState();
    _paidByUid = FirebaseAuth.instance.currentUser?.uid;
    _initItemAssignments();
    _loadMemberProfiles();
  }

  void _initItemAssignments() {
    _itemAssignments = {};
    for (var i = 0; i < widget.receipt.items.length; i++) {
      _itemAssignments[i] = <String>[];
    }
  }

  void _initCustomControllers() {
    _customAmountControllers = {};
    final memberCount = _allMemberIds.length;
    if (memberCount == 0) return;
    final perPerson = widget.receipt.totalAmount / memberCount;
    for (final id in _allMemberIds) {
      _customAmountControllers[id] =
          TextEditingController(text: perPerson.toStringAsFixed(2));
    }
  }

  Future<void> _loadMemberProfiles() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final profiles = await userService.getUserProfiles(widget.group.members);

    // Create dummy profiles for guest members
    for (final guestName in widget.group.guestMembers) {
      final guestId = 'guest:$guestName';
      profiles[guestId] = UserProfile(
        uid: guestId,
        email: 'Guest',
        displayName: guestName,
      );
    }

    setState(() {
      _memberProfiles = profiles;
      _isLoading = false;
    });
    _initCustomControllers();
  }

  @override
  void dispose() {
    for (final controller in _customAmountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Get display name for any member ID (registered or guest)
  String _displayName(String memberId) {
    if (Group.isGuest(memberId)) {
      return Group.guestName(memberId);
    }
    final profile = _memberProfiles[memberId];
    return profile?.displayName ?? profile?.email ?? memberId;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Split Bill')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Split Bill')),
      body: Column(
        children: [
          _buildReceiptHeader(),
          _buildPaidBySelector(),
          _buildSplitModeSelector(),
          const Divider(),
          Expanded(child: _buildSplitContent()),
          _buildSummaryAndConfirm(),
        ],
      ),
    );
  }

  Widget _buildReceiptHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receipt.restaurantName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${widget.receipt.items.length} items · ${_allMemberIds.length} people',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${widget.receipt.totalAmount.toStringAsFixed(2)} ${widget.group.currency}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidBySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Paid by: '),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: _paidByUid,
              isExpanded: true,
              items: _allMemberIds.map((id) {
                return DropdownMenuItem(
                  value: id,
                  child: Row(
                    children: [
                      if (Group.isGuest(id))
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child:
                              Icon(Icons.person_outline, size: 16),
                        ),
                      Text(_displayName(id)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _paidByUid = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<SplitMode>(
        segments: const [
          ButtonSegment(value: SplitMode.equal, label: Text('Equal')),
          ButtonSegment(value: SplitMode.perItem, label: Text('Per Item')),
          ButtonSegment(value: SplitMode.custom, label: Text('Custom')),
        ],
        selected: {_splitMode},
        onSelectionChanged: (modes) {
          setState(() => _splitMode = modes.first);
        },
      ),
    );
  }

  Widget _buildSplitContent() {
    switch (_splitMode) {
      case SplitMode.equal:
        return _buildEqualSplit();
      case SplitMode.perItem:
        return _buildPerItemSplit();
      case SplitMode.custom:
        return _buildCustomSplit();
    }
  }

  Widget _buildMemberAvatar(String memberId) {
    if (Group.isGuest(memberId)) {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: const Icon(Icons.person_outline),
      );
    }
    final profile = _memberProfiles[memberId];
    return CircleAvatar(
      backgroundImage: profile?.photoUrl != null
          ? NetworkImage(profile!.photoUrl!)
          : null,
      child: profile?.photoUrl == null ? const Icon(Icons.person) : null,
    );
  }

  Widget _buildEqualSplit() {
    final perPerson = widget.receipt.totalAmount / _allMemberIds.length;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allMemberIds.length,
      itemBuilder: (context, index) {
        final id = _allMemberIds[index];
        final isPayer = id == _paidByUid;

        return Card(
          child: ListTile(
            leading: _buildMemberAvatar(id),
            title: Text(_displayName(id)),
            subtitle: isPayer
                ? const Text('Paid the bill')
                : Group.isGuest(id)
                    ? const Text('Guest')
                    : null,
            trailing: Text(
              '${perPerson.toStringAsFixed(2)} ${widget.group.currency}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPayer ? Colors.green : null,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Get initials for a member (1-2 chars)
  String _initials(String memberId) {
    final name = _displayName(memberId);
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Build a small avatar (used in the drag header and on assigned items)
  Widget _buildSmallAvatar(String memberId, {double radius = 20}) {
    final profile = _memberProfiles[memberId];
    final photoUrl = profile?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
      backgroundColor: hasPhoto
          ? null
          : _avatarColor(memberId),
      child: hasPhoto
          ? null
          : Text(
              _initials(memberId),
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }

  /// Deterministic color per member
  Color _avatarColor(String memberId) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber.shade700,
      Colors.cyan.shade700,
    ];
    return colors[memberId.hashCode.abs() % colors.length];
  }

  Widget _buildPerItemSplit() {
    return Column(
      children: [
        // Sticky header row with draggable member avatars
        _buildDragAvatarHeader(),
        const Divider(height: 1),
        // Scrollable item list as drop targets
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: widget.receipt.items.length,
            itemBuilder: (context, index) => _buildDropTargetItem(index),
          ),
        ),
      ],
    );
  }

  Widget _buildDragAvatarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Drag members onto items',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _allMemberIds.map((id) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Draggable<String>(
                    data: id,
                    feedback: Material(
                      elevation: 6,
                      shape: const CircleBorder(),
                      child: _buildSmallAvatar(id, radius: 24),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _buildAvatarWithLabel(id),
                    ),
                    child: _buildAvatarWithLabel(id),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithLabel(String memberId) {
    final name = _displayName(memberId);
    final shortName =
        name.length > 8 ? '${name.substring(0, 7)}…' : name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSmallAvatar(memberId),
        const SizedBox(height: 4),
        Text(
          shortName,
          style: Theme.of(context).textTheme.labelSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDropTargetItem(int index) {
    final item = widget.receipt.items[index];
    final assignedList = _itemAssignments[index] ?? [];
    final totalShares = assignedList.length;

    // Group by member to get share counts
    final shareCounts = <String, int>{};
    for (final id in assignedList) {
      shareCounts[id] = (shareCounts[id] ?? 0) + 1;
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        setState(() {
          _itemAssignments[index]!.add(details.data);
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isHovering ? 4 : 1,
          color: isHovering
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isHovering
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name + price
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.description,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${item.totalPrice.toStringAsFixed(2)} ${widget.group.currency}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (shareCounts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${(item.totalPrice / totalShares).toStringAsFixed(2)} per share · $totalShares shares',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Assigned members grouped with share count
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: shareCounts.entries.map((entry) {
                      final id = entry.key;
                      final count = entry.value;
                      final label = count > 1
                          ? '${_displayName(id)} ×$count'
                          : _displayName(id);

                      return Chip(
                        avatar: _buildSmallAvatar(id, radius: 12),
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() {
                            // Remove one share (one occurrence)
                            _itemAssignments[index]!.remove(id);
                          });
                        },
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Drop members here',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomSplit() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._allMemberIds.map((id) {
          final controller = _customAmountControllers[id];

          return Card(
            child: ListTile(
              leading: _buildMemberAvatar(id),
              title: Text(_displayName(id)),
              subtitle: Group.isGuest(id) ? const Text('Guest') : null,
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    suffixText: widget.group.currency,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        _buildCustomSplitRemaining(),
      ],
    );
  }

  Widget _buildCustomSplitRemaining() {
    final total = _getCustomTotal();
    final remaining = widget.receipt.totalAmount - total;
    final isValid = remaining.abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isValid ? 'Amounts match!' : 'Remaining:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isValid ? Colors.green : Colors.red,
            ),
          ),
          Text(
            '${remaining.toStringAsFixed(2)} ${widget.group.currency}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isValid ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  double _getCustomTotal() {
    var total = 0.0;
    for (final controller in _customAmountControllers.values) {
      total += double.tryParse(controller.text) ?? 0;
    }
    return total;
  }

  Map<String, double> _calculateOwedAmounts() {
    final splitService =
        Provider.of<SplitCalculationService>(context, listen: false);
    final paidBy = _paidByUid ?? _allMemberIds.first;

    switch (_splitMode) {
      case SplitMode.equal:
        return splitService.calculateEqualSplit(
          totalAmount: widget.receipt.totalAmount,
          memberUids: _allMemberIds,
          paidByUid: paidBy,
        );
      case SplitMode.perItem:
        final assignments =
            _itemAssignments.map((k, v) => MapEntry(k, v.toList()));
        return splitService.calculateItemSplit(
          receipt: widget.receipt,
          itemAssignments: assignments,
          paidByUid: paidBy,
        );
      case SplitMode.custom:
        final amounts = <String, double>{};
        for (final id in _allMemberIds) {
          if (id != paidBy) {
            amounts[id] =
                double.tryParse(_customAmountControllers[id]?.text ?? '0') ??
                    0;
          }
        }
        return amounts;
    }
  }

  Widget _buildSummaryAndConfirm() {
    final owedAmounts = _calculateOwedAmounts();
    final paidBy = _paidByUid ?? _allMemberIds.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (owedAmounts.isNotEmpty) ...[
            Text(
              'Settlement Summary',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...owedAmounts.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_displayName(entry.key)} owes ${_displayName(paidBy)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${entry.value.toStringAsFixed(2)} ${widget.group.currency}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _confirmSplit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm & Save'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: owedAmounts.isNotEmpty
                    ? () => _shareResult(owedAmounts)
                    : null,
                icon: const Icon(Icons.share),
                tooltip: 'Share result',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _generateShareText(Map<String, double> owedAmounts) {
    final paidBy = _paidByUid ?? _allMemberIds.first;
    final currency = widget.group.currency;
    final buffer = StringBuffer();

    buffer.writeln(widget.receipt.restaurantName);
    buffer.writeln('Total: ${widget.receipt.totalAmount.toStringAsFixed(2)} $currency');
    buffer.writeln('Paid by: ${_displayName(paidBy)}');
    buffer.writeln('');

    for (final entry in owedAmounts.entries) {
      buffer.writeln(
          '${_displayName(entry.key)} owes ${entry.value.toStringAsFixed(2)} $currency');
    }

    buffer.writeln('');
    buffer.writeln('Shared via JustSplit');

    return buffer.toString();
  }

  void _shareResult(Map<String, double> owedAmounts) {
    final text = _generateShareText(owedAmounts);
    Share.share(text);
  }

  Future<void> _confirmSplit() async {
    if (_splitMode == SplitMode.custom) {
      final remaining = widget.receipt.totalAmount - _getCustomTotal();
      if (remaining.abs() >= 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom amounts must equal the total'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final receiptService =
          Provider.of<ReceiptService>(context, listen: false);
      final allocationService =
          Provider.of<AllocationService>(context, listen: false);
      final settlementService =
          Provider.of<SettlementService>(context, listen: false);
      final splitService =
          Provider.of<SplitCalculationService>(context, listen: false);

      final paidBy = _paidByUid ?? _allMemberIds.first;

      // 1. Save the receipt
      await receiptService.addReceipt(widget.receipt);

      // 2. Save allocations
      final allocations = <ExpenseAllocation>[];
      final now = DateTime.now();

      if (_splitMode == SplitMode.perItem) {
        for (var i = 0; i < widget.receipt.items.length; i++) {
          final assignedMembers = _itemAssignments[i] ?? [];
          if (assignedMembers.isEmpty) continue;
          final perPerson =
              widget.receipt.items[i].totalPrice / assignedMembers.length;

          for (final id in assignedMembers) {
            allocations.add(ExpenseAllocation(
              id: const Uuid().v4(),
              receiptId: widget.receipt.id,
              groupId: widget.group.id,
              userId: id,
              paidByUserId: paidBy,
              itemIndex: i,
              amount: perPerson,
              createdAt: now,
            ));
          }
        }
      } else {
        final owedAmounts = _calculateOwedAmounts();
        for (final entry in owedAmounts.entries) {
          allocations.add(ExpenseAllocation(
            id: const Uuid().v4(),
            receiptId: widget.receipt.id,
            groupId: widget.group.id,
            userId: entry.key,
            paidByUserId: paidBy,
            itemIndex: -1,
            amount: entry.value,
            createdAt: now,
          ));
        }
      }

      if (allocations.isNotEmpty) {
        await allocationService.saveAllocations(allocations);
      }

      // 3. Create settlements (only for registered users, not guests)
      final owedAmounts = _calculateOwedAmounts();
      // Filter out guest entries for Firestore settlements
      final registeredOwed = Map.fromEntries(
        owedAmounts.entries.where((e) => !Group.isGuest(e.key)),
      );

      if (registeredOwed.isNotEmpty && !Group.isGuest(paidBy)) {
        final settlements = splitService.generateSettlements(
          groupId: widget.group.id,
          receiptId: widget.receipt.id,
          paidByUid: paidBy,
          owedAmounts: registeredOwed,
        );

        if (settlements.isNotEmpty) {
          await settlementService.createSettlements(settlements);
        }
      }

      if (mounted) {
        // If there are guest members, offer to share
        final hasGuests = owedAmounts.keys.any(Group.isGuest);

        if (hasGuests) {
          _showShareDialog(owedAmounts);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill split saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving split: $e')),
        );
      }
    }
  }

  void _showShareDialog(Map<String, double> owedAmounts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved!'),
        content: const Text(
            'The bill has been split. Would you like to share the result with your guests?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context, true); // close split screen
            },
            child: const Text('No thanks'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // close dialog
              _shareResult(owedAmounts);
              Navigator.pop(context, true); // close split screen
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }
}
