import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'classes/firestore_stats_manager.dart';
import 'classes/game_models.dart';
import 'widgets/decorations.dart';

class BlackjackGame extends StatefulWidget {
  const BlackjackGame({super.key});

  @override
  State<BlackjackGame> createState() => _BlackjackGameState();
}

class _BlackjackGameState extends State<BlackjackGame> with TickerProviderStateMixin {
  Deck deck = Deck();
  Hand playerHand = Hand();
  Hand dealerHand = Hand();

  final user = FirebaseAuth.instance.currentUser;

  GameState gameState = GameState.betting;
  int playerChips = 0;
  int currentBet = 0;
  bool isDealing = false;

  // Add these for stats tracking
  int chipsBeforeBet = 0;
  bool roundStatsRecorded = false;

  @override
  void initState() {
    super.initState();
    initializeGame();
  }

  void initializeGame() async {
    if (user != null) {
      try {
        // Initialize stats if needed
        await FirestoreStatsManager.initializePlayerStats();

        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user!.uid)
            .get();
        setState(() {
          playerChips = doc.data()?["current_chips"] ?? 1000;
        });
      } catch (e) {
        print('Error initializing game: $e');
      }
    }
    deck = Deck();
    playerHand = Hand();
    dealerHand = Hand();
  }

  void startNewRound() {
    setState(() {
      gameState = GameState.playing;
      playerHand.clear();
      dealerHand.clear();
      deck.reset();
      roundStatsRecorded = false; // Reset for new round
      dealInitialCards();
    });
  }

  void dealInitialCards() async {
    for (int i = 0; i < 2; i++) {
      await dealCardToPlayer();
      await Future.delayed(const Duration(milliseconds: 300));
      await dealCardToDealer(i == 0);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (playerHand.isBlackjack) {
      endRound();
    }
  }

  Future<void> dealCardToPlayer() async {
    final card = deck.drawCard();
    if (card != null) {
      setState(() {
        playerHand.addCard(card);
      });
    }
  }

  Future<void> dealCardToDealer([bool faceUp = true]) async {
    final card = deck.drawCard();
    if (card != null) {
      card.faceUp = faceUp;
      setState(() {
        dealerHand.addCard(card);
      });
    }
  }

  void hit() async {
    if (gameState != GameState.playing || isDealing) return;

    setState(() {
      isDealing = true;
    });

    await dealCardToPlayer();

    setState(() {
      isDealing = false;
    });

    if (playerHand.isBust) {
      endRound();
    }
  }

  void stand() {
    if (gameState != GameState.playing || isDealing) return;

    setState(() {
      gameState = GameState.dealerTurn;
    });

    dealerPlay();
  }

  void dealerPlay() async {
    setState(() {
      dealerHand.cards[1].faceUp = true;
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    while (dealerHand.value < 17) {
      await dealCardToDealer();
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    endRound();
  }

  void endRound() async {
    // Determine outcome and winnings
    String outcome = '';
    int winnings = 0;

    setState(() {
      gameState = GameState.roundEnd;

      if (playerHand.isBust) {
        outcome = 'lost';
        winnings = 0;
      } else if (dealerHand.isBust) {
        outcome = 'won';
        winnings = currentBet * 2;
        playerChips += winnings;
      } else if (playerHand.isBlackjack && !dealerHand.isBlackjack) {
        outcome = 'won';
        winnings = (currentBet * 2.5).round();
        playerChips += winnings;
      } else if (playerHand.value > dealerHand.value) {
        outcome = 'won';
        winnings = currentBet * 2;
        playerChips += winnings;
      } else if (playerHand.value == dealerHand.value) {
        outcome = 'push';
        winnings = currentBet;
        playerChips += winnings;
      } else {
        outcome = 'lost';
        winnings = 0;
      }
    });

    // Update Firestore stats only once per round
    if (!roundStatsRecorded && user != null) {
      roundStatsRecorded = true;

      // Update player stats
      await FirestoreStatsManager.updateGameResult(
        outcome: outcome,
        betAmount: currentBet,
        winnings: winnings,
        finalChips: playerChips,
        hadBlackjack: playerHand.isBlackjack,
        busted: playerHand.isBust,
      );

      // Update current chips
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .update({"current_chips": playerChips});
    }
  }

  void placeBet(int amount) {
    if (amount <= playerChips) {
      setState(() {
        currentBet = amount;
        chipsBeforeBet = playerChips; // Track chips before bet
        playerChips -= amount;
        startNewRound();
      });
    }
  }

  String getResultMessage() {
    if (playerHand.isBust) return "Bust! You lose.";
    if (dealerHand.isBust) return "Dealer busts! You win!";
    if (playerHand.isBlackjack && !dealerHand.isBlackjack) return "Blackjack! You win!";
    if (playerHand.value > dealerHand.value) return "You win!";
    if (playerHand.value < dealerHand.value) return "You lose.";
    return "Push!";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        if (user != null) {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user!.uid)
              .update({"current_chips": playerChips});
        }

        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.green[800],
        appBar: AppBar(
          title: const Text('Blackjack'),
          backgroundColor: Colors.green[900],
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                label: Text('Chips: $playerChips'),
                backgroundColor: Colors.yellow[700],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Dealer',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  buildHand(dealerHand),
                  if (gameState == GameState.roundEnd)
                    Text(
                      'Value: ${dealerHand.value}',
                      style: const TextStyle(color: Colors.white),
                    ),
                ],
              ),
            ),
            if (gameState == GameState.roundEnd)
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      getResultMessage(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (currentBet > 0)
                      Text(
                        _getChipsChangeMessage(),
                        style: TextStyle(
                          color: _getChipsChangeColor(),
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildHand(playerHand),
                  const SizedBox(height: 10),
                  Text(
                    'Your Hand: ${playerHand.value}',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            buildActionButtons(),
          ],
        ),
      ),
    );
  }

  String _getChipsChangeMessage() {
    String outcome = getResultMessage();
    if (outcome.contains("win")) {
      int profit = playerChips - chipsBeforeBet;
      return '+$profit chips';
    } else if (outcome.contains("Push")) {
      return '±0 chips';
    } else {
      return '-$currentBet chips';
    }
  }

  Color _getChipsChangeColor() {
    String outcome = getResultMessage();
    if (outcome.contains("win")) {
      return Colors.green[300]!;
    } else if (outcome.contains("Push")) {
      return Colors.yellow[300]!;
    } else {
      return Colors.red[300]!;
    }
  }

  Widget buildHand(Hand hand) {
    const cardWidth = 80.0;
    const overlap = 30.0;
    final totalWidth = cardWidth + (hand.cards.length - 1) * overlap;

    return Center(
      child: SizedBox(
        height: 120,
        width: totalWidth,
        child: Stack(
          children: hand.cards.asMap().entries.map((entry) {
            final index = entry.key;
            final card = entry.value;

            return Positioned(
              left: index * overlap,
              child: buildCard(card),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildCard(PlayingCard card) {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          card.imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.white,
              child: Center(
                child: Text(
                  '${card.rank.toString().split('.').last}\n${card.suit.toString().split('.').last}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildActionButtons() {
    if (gameState == GameState.betting) {
      return buildBettingButtons();
    } else if (gameState == GameState.playing) {
      return buildGameButtons();
    } else if (gameState == GameState.roundEnd) {
      return buildNewRoundButton();
    }

    return const SizedBox.shrink();
  }

  Widget buildBettingButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Place your bet',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [10, 25, 50, 100].map((amount) {
              return ElevatedButton(
                style: AppDecorations.buttonStyle,
                onPressed: amount <= playerChips ? () => placeBet(amount) : null,
                child: Text('\$$amount'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget buildGameButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            style: AppDecorations.buttonStyle,
            onPressed: isDealing ? null : hit,
            child: const Text('HIT'),
          ),
          ElevatedButton(
            style: AppDecorations.buttonStyleRed,
            onPressed: isDealing ? null : stand,
            child: const Text('STAND'),
          ),
        ],
      ),
    );
  }

  Widget buildNewRoundButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        style: AppDecorations.buttonStyle,
        onPressed: () {
          setState(() {
            gameState = GameState.betting;
            currentBet = 0; // Reset bet for new round
          });
        },
        child: const Text('NEW ROUND'),
      ),
    );
  }
}

enum GameState { betting, playing, dealerTurn, roundEnd }