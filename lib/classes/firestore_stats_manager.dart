import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class PlayerStats {
  final int totalGamesPlayed;
  final int totalGamesWon;
  final int totalGamesLost;
  final int totalGamesPush;
  final int lifetimeChipsWon;
  final int lifetimeChipsLost;
  final int currentChips;
  final int highestChips;
  final int biggestWin;
  final int biggestLoss;
  final DateTime lastPlayed;
  final int blackjackCount;
  final int bustCount;

  PlayerStats({
    this.totalGamesPlayed = 0,
    this.totalGamesWon = 0,
    this.totalGamesLost = 0,
    this.totalGamesPush = 0,
    this.lifetimeChipsWon = 0,
    this.lifetimeChipsLost = 0,
    this.currentChips = 1000,
    this.highestChips = 1000,
    this.biggestWin = 0,
    this.biggestLoss = 0,
    DateTime? lastPlayed,
    this.blackjackCount = 0,
    this.bustCount = 0,
  }) : lastPlayed = lastPlayed ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'totalGamesPlayed': totalGamesPlayed,
      'totalGamesWon': totalGamesWon,
      'totalGamesLost': totalGamesLost,
      'totalGamesPush': totalGamesPush,
      'lifetimeChipsWon': lifetimeChipsWon,
      'lifetimeChipsLost': lifetimeChipsLost,
      'currentChips': currentChips,
      'highestChips': highestChips,
      'biggestWin': biggestWin,
      'biggestLoss': biggestLoss,
      'lastPlayed': Timestamp.fromDate(lastPlayed),
      'blackjackCount': blackjackCount,
      'bustCount': bustCount,
    };
  }

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    return PlayerStats(
      totalGamesPlayed: map['totalGamesPlayed'] ?? 0,
      totalGamesWon: map['totalGamesWon'] ?? 0,
      totalGamesLost: map['totalGamesLost'] ?? 0,
      totalGamesPush: map['totalGamesPush'] ?? 0,
      lifetimeChipsWon: map['lifetimeChipsWon'] ?? 0,
      lifetimeChipsLost: map['lifetimeChipsLost'] ?? 0,
      currentChips: map['currentChips'] ?? 1000,
      highestChips: map['highestChips'] ?? 1000,
      biggestWin: map['biggestWin'] ?? 0,
      biggestLoss: map['biggestLoss'] ?? 0,
      lastPlayed: (map['lastPlayed'] as Timestamp?)?.toDate() ?? DateTime.now(),
      blackjackCount: map['blackjackCount'] ?? 0,
      bustCount: map['bustCount'] ?? 0,
    );
  }

  // Calculate win rate
  double get winRate {
    if (totalGamesPlayed == 0) return 0;
    return (totalGamesWon / totalGamesPlayed) * 100;
  }

  // Calculate net profit/loss
  int get netChips => lifetimeChipsWon - lifetimeChipsLost;
}

class FirestoreStatsManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'playerStats';


  static String? get userId => FirebaseAuth.instance.currentUser?.uid;

  // initialise stats if doesnt exist
  static Future<void> initializePlayerStats() async {
    if (userId == null) return;

    final doc = await _firestore.collection(_collection).doc(userId).get();

    if (!doc.exists) {
      await _firestore.collection(_collection).doc(userId).set(
        PlayerStats().toMap(),
      );
    }
  }

  // Get player stats
  static Future<PlayerStats?> getPlayerStats() async {
    if (userId == null) return null;

    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();

      if (doc.exists) {
        return PlayerStats.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting player stats: $e');
      return null;
    }
  }

  // Update stats after game ends
  static Future<void> updateGameResult({
    required String outcome, // 'won', 'lost', 'push'
    required int betAmount,
    required int winnings,
    required int finalChips,
    required bool hadBlackjack,
    required bool busted,
  }) async {
    if (userId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection(_collection).doc(userId);
        final snapshot = await transaction.get(docRef);

        PlayerStats currentStats;
        if (snapshot.exists) {
          currentStats = PlayerStats.fromMap(snapshot.data()!);
        } else {
          currentStats = PlayerStats();
        }

        // Calculate new stats
        int newGamesPlayed = currentStats.totalGamesPlayed + 1;
        int newGamesWon = currentStats.totalGamesWon;
        int newGamesLost = currentStats.totalGamesLost;
        int newGamesPush = currentStats.totalGamesPush;
        int newChipsWon = currentStats.lifetimeChipsWon;
        int newChipsLost = currentStats.lifetimeChipsLost;
        int newBiggestWin = currentStats.biggestWin;
        int newBiggestLoss = currentStats.biggestLoss;

        // Update based on outcome
        switch (outcome) {
          case 'won':
            newGamesWon++;
            int profit = winnings - betAmount;
            newChipsWon += profit;
            if (profit > newBiggestWin) {
              newBiggestWin = profit;
            }
            break;
          case 'lost':
            newGamesLost++;
            newChipsLost += betAmount;
            if (betAmount > newBiggestLoss) {
              newBiggestLoss = betAmount;
            }
            break;
          case 'push':
            newGamesPush++;
            break;
        }

        // Update other stats
        int newHighestChips = finalChips > currentStats.highestChips
            ? finalChips
            : currentStats.highestChips;

        int newBlackjackCount = currentStats.blackjackCount + (hadBlackjack ? 1 : 0);
        int newBustCount = currentStats.bustCount + (busted ? 1 : 0);

        // Create updated stats
        final updatedStats = PlayerStats(
          totalGamesPlayed: newGamesPlayed,
          totalGamesWon: newGamesWon,
          totalGamesLost: newGamesLost,
          totalGamesPush: newGamesPush,
          lifetimeChipsWon: newChipsWon,
          lifetimeChipsLost: newChipsLost,
          currentChips: finalChips,
          highestChips: newHighestChips,
          biggestWin: newBiggestWin,
          biggestLoss: newBiggestLoss,
          lastPlayed: DateTime.now(),
          blackjackCount: newBlackjackCount,
          bustCount: newBustCount,
        );

        // Save to Firestore
        transaction.set(docRef, updatedStats.toMap());
      });

      print('Stats updated successfully');
    } catch (e) {
      print('Error updating stats: $e');
    }
  }

  // Get leaderboard (top players by current chips)
  static Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('currentChips', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => {
        'userId': doc.id,
        'stats': PlayerStats.fromMap(doc.data()),
      }).toList();
    } catch (e) {
      print('Error getting leaderboard: $e');
      return [];
    }
  }

  // Reset player stats (for testing or if player wants to start fresh)
  static Future<void> resetStats() async {
    if (userId == null) return;

    try {
      await _firestore.collection(_collection).doc(userId).set(
        PlayerStats().toMap(),
      );
    } catch (e) {
      print('Error resetting stats: $e');
    }
  }
}

// Extension to make it easy to use in your game screen
extension FirestoreStatsExtension on State {
  Future<void> recordGameResult(Map<String, dynamic> gameResult) async {
    // Extract data from your game result
    final myResult = gameResult['results'][gameResult['myId']];
    final myState = gameResult['players'][gameResult['myId']];

    await FirestoreStatsManager.updateGameResult(
      outcome: myResult['outcome'],
      betAmount: myState['currentBet'],
      winnings: myResult['winnings'],
      finalChips: myResult['finalChips'],
      hadBlackjack: myState['isBlackjack'] ?? false,
      busted: myState['hasBusted'] ?? false,
    );
  }
}