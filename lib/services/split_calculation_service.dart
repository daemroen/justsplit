import '../models/receipt.dart';
import '../models/settlement.dart';

class SplitCalculationService {
  /// Equal split: divide totalAmount equally among members
  /// Returns map of userId -> amount they owe (excluding the payer)
  Map<String, double> calculateEqualSplit({
    required double totalAmount,
    required List<String> memberUids,
    required String paidByUid,
  }) {
    if (memberUids.isEmpty) return {};

    final perPerson = totalAmount / memberUids.length;
    final result = <String, double>{};

    for (final uid in memberUids) {
      if (uid != paidByUid) {
        result[uid] = _roundToTwo(perPerson);
      }
    }

    return result;
  }

  /// Per-item split: each item is assigned to specific members
  /// itemAssignments maps itemIndex -> list of member UIDs who share that item
  /// Returns map of userId -> total amount they owe
  Map<String, double> calculateItemSplit({
    required Receipt receipt,
    required Map<int, List<String>> itemAssignments,
    required String paidByUid,
  }) {
    final totals = <String, double>{};

    for (var i = 0; i < receipt.items.length; i++) {
      final item = receipt.items[i];
      final assignedMembers = itemAssignments[i] ?? [];

      if (assignedMembers.isEmpty) continue;

      final perPerson = item.totalPrice / assignedMembers.length;
      for (final uid in assignedMembers) {
        totals[uid] = (totals[uid] ?? 0) + perPerson;
      }
    }

    // Distribute tax, tip, and global fees/discounts proportionally
    final itemsTotal =
        receipt.items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    if (itemsTotal > 0) {
      final extras = receipt.totalAmount - itemsTotal;
      if (extras.abs() > 0.01) {
        final totalAssigned =
            totals.values.fold<double>(0, (sum, v) => sum + v);
        if (totalAssigned > 0) {
          for (final uid in totals.keys.toList()) {
            final proportion = totals[uid]! / totalAssigned;
            totals[uid] = totals[uid]! + (extras * proportion);
          }
        }
      }
    }

    // Remove the payer from debts (they paid, so they owe nothing)
    // But keep their share tracked for display purposes
    final result = <String, double>{};
    for (final entry in totals.entries) {
      if (entry.key != paidByUid) {
        result[entry.key] = _roundToTwo(entry.value);
      }
    }

    return result;
  }

  /// Validate that custom amounts sum to totalAmount
  bool validateCustomSplit({
    required double totalAmount,
    required Map<String, double> customAmounts,
  }) {
    final sum =
        customAmounts.values.fold<double>(0, (sum, amount) => sum + amount);
    return (sum - totalAmount).abs() < 0.01;
  }

  /// Generate Settlement objects from owed amounts
  List<Settlement> generateSettlements({
    required String groupId,
    required String? receiptId,
    required String paidByUid,
    required Map<String, double> owedAmounts,
  }) {
    final settlements = <Settlement>[];
    final now = DateTime.now();

    for (final entry in owedAmounts.entries) {
      if (entry.value > 0.01) {
        settlements.add(Settlement(
          id: '',
          groupId: groupId,
          fromUserId: entry.key,
          toUserId: paidByUid,
          amount: _roundToTwo(entry.value),
          status: SettlementStatus.pending,
          receiptId: receiptId,
          createdAt: now,
        ));
      }
    }

    return settlements;
  }

  /// Simplify debts within a group to minimize transactions
  /// Uses greedy approach: repeatedly settle largest creditor with largest debtor
  List<Settlement> simplifyDebts(List<Settlement> settlements) {
    // Calculate net balances: positive = owed money, negative = owes money
    final balances = <String, double>{};

    for (final s in settlements) {
      if (s.status == SettlementStatus.pending) {
        balances[s.fromUserId] =
            (balances[s.fromUserId] ?? 0) - s.amount; // owes
        balances[s.toUserId] =
            (balances[s.toUserId] ?? 0) + s.amount; // is owed
      }
    }

    // Separate into creditors and debtors
    final creditors = <MapEntry<String, double>>[];
    final debtors = <MapEntry<String, double>>[];

    for (final entry in balances.entries) {
      if (entry.value > 0.01) {
        creditors.add(entry);
      } else if (entry.value < -0.01) {
        debtors.add(MapEntry(entry.key, -entry.value)); // make positive
      }
    }

    // Sort by amount descending
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final simplified = <Settlement>[];
    final now = DateTime.now();
    var ci = 0, di = 0;
    final cAmounts = creditors.map((e) => e.value).toList();
    final dAmounts = debtors.map((e) => e.value).toList();

    while (ci < creditors.length && di < debtors.length) {
      final amount =
          cAmounts[ci] < dAmounts[di] ? cAmounts[ci] : dAmounts[di];

      if (amount > 0.01) {
        simplified.add(Settlement(
          id: '',
          groupId:
              settlements.isNotEmpty ? settlements.first.groupId : '',
          fromUserId: debtors[di].key,
          toUserId: creditors[ci].key,
          amount: _roundToTwo(amount),
          status: SettlementStatus.pending,
          createdAt: now,
        ));
      }

      cAmounts[ci] -= amount;
      dAmounts[di] -= amount;

      if (cAmounts[ci] < 0.01) ci++;
      if (dAmounts[di] < 0.01) di++;
    }

    return simplified;
  }

  double _roundToTwo(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
