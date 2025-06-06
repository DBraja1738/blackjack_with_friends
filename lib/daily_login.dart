import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class DailyBonusSystem extends StatefulWidget {
  final VoidCallback? onBonusClaimed;

  const DailyBonusSystem({super.key, this.onBonusClaimed});

  @override
  State<DailyBonusSystem> createState() => _DailyBonusSystemState();
}

class _DailyBonusSystemState extends State<DailyBonusSystem> {
  final user = FirebaseAuth.instance.currentUser;

  bool canClaimBonus = false;
  int currentStreak = 0;
  DateTime? lastClaimDate;
  bool isLoading = true;
  Timer? timer;

  final List<int> bonusAmounts = [100, 150, 200, 250, 300, 400, 500];

  @override
  void initState() {
    super.initState();
    checkBonusStatus();
    startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          if (lastClaimDate != null && !canClaimBonus) {
            final difference = now.difference(lastClaimDate!);
            if (difference.inHours >= 24) {
              canClaimBonus = true;
              checkBonusStatus();
            }
          }
        });
      }
    });
  }

  Future<void> checkBonusStatus() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      final data = doc.data();
      if (data != null) {
        currentStreak = data['dailyStreak'] ?? 0;
        final lastClaim = data['lastDailyBonus'] as Timestamp?;

        if (lastClaim != null) {
          lastClaimDate = lastClaim.toDate();
          final now = DateTime.now();
          final difference = now.difference(lastClaimDate!);

          if (difference.inHours >= 24) {
            canClaimBonus = true;
            if (difference.inHours > 48) {
              currentStreak = 0;
            }
          }
        } else {
          canClaimBonus = true;
        }
      } else {
        canClaimBonus = true;
      }
    } catch (e) {
      print('Error checking bonus status: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> claimBonus() async {
    if (!canClaimBonus || user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid);

      final doc = await userRef.get();
      final currentChips = doc.data()?['current_chips'] ?? 0;

      final bonusIndex = currentStreak % bonusAmounts.length;
      final bonusAmount = bonusAmounts[bonusIndex];

      await userRef.update({
        'current_chips': currentChips + bonusAmount,
        'lastDailyBonus': Timestamp.now(),
        'dailyStreak': currentStreak + 1,
      });

      setState(() {
        canClaimBonus = false;
        currentStreak++;
        lastClaimDate = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You received $bonusAmount chips!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onBonusClaimed?.call();

    } catch (e) {
      print('Error claiming bonus: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error claiming bonus. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  String getTimeUntilNextBonus() {
    if (lastClaimDate == null) return '';

    final nextBonus = lastClaimDate!.add(const Duration(hours: 24));
    final now = DateTime.now();
    final difference = nextBonus.difference(now);

    if (difference.isNegative) return 'Available now!';

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.amber.shade700, Colors.orange.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Daily Bonus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Day ${currentStreak + 1} - ${bonusAmounts[currentStreak % bonusAmounts.length]} chips',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: bonusAmounts.length,
                itemBuilder: (context, index) {
                  final isCompleted = index < (currentStreak % bonusAmounts.length);
                  final isCurrent = index == (currentStreak % bonusAmounts.length);

                  return Container(
                    width: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? Colors.green
                          : isCurrent
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      border: isCurrent
                          ? Border.all(color: Colors.yellow, width: 3)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCompleted || isCurrent
                              ? Colors.black87
                              : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            if (canClaimBonus)
              ElevatedButton(
                onPressed: claimBonus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Claim Bonus!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Column(
                children: [
                  const Text(
                    'Next bonus in:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getTimeUntilNextBonus(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class DailyBonusDialog extends StatelessWidget {
  final VoidCallback? onBonusClaimed;

  const DailyBonusDialog({super.key, this.onBonusClaimed});

  static void show(BuildContext context, {VoidCallback? onBonusClaimed}) {
    showDialog(
      context: context,
      builder: (context) => DailyBonusDialog(onBonusClaimed: onBonusClaimed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: DailyBonusSystem(
        onBonusClaimed: () {
          onBonusClaimed?.call();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}