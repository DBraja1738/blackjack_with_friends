import 'package:flutter/material.dart';
import 'game_models.dart';
import 'widgets/decorations.dart';

class BlackjackGame extends StatefulWidget {
  const BlackjackGame({super.key});

  @override
  State<BlackjackGame> createState() => _BlackjackGameState();
}

class _BlackjackGameState extends State<BlackjackGame> with TickerProviderStateMixin {
  late Deck deck;
  late Hand playerHand;
  late Hand dealerHand;

  GameState gameState = GameState.betting;
  int playerChips = 1000;
  int currentBet = 0;

  // Animation controllers
  late AnimationController cardAnimationController;
  late Animation<double> cardAnimation;

  @override
  void initState() {
    super.initState();
    initializeGame();
    initializeAnimations();
  }

  void initializeGame() {
    deck = Deck();
    playerHand = Hand();
    dealerHand = Hand();
  }

  void initializeAnimations() {
    cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    cardAnimation = CurvedAnimation(
      parent: cardAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    cardAnimationController.dispose();
    super.dispose();
  }

  void startNewRound() {
    setState(() {
      gameState = GameState.playing;
      playerHand.clear();
      dealerHand.clear();
      deck.reset();

      // Deal initial cards
      dealInitialCards();
    });
  }

  void dealInitialCards() async {
    // Deal cards with animation
    for (int i = 0; i < 2; i++) {
      await dealCardToPlayer();
      await Future.delayed(const Duration(milliseconds: 300));
      await dealCardToDealer(i == 0);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Check for blackjack
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
      cardAnimationController.forward(from: 0);
    }
  }

  Future<void> dealCardToDealer([bool faceUp = true]) async {
    final card = deck.drawCard();
    if (card != null) {
      card.faceUp = faceUp;
      setState(() {
        dealerHand.addCard(card);
      });
      cardAnimationController.forward(from: 0);
    }
  }

  void hit() async {
    if (gameState != GameState.playing) return;

    await dealCardToPlayer();

    if (playerHand.isBust) {
      endRound();
    }
  }

  void stand() {
    if (gameState != GameState.playing) return;

    setState(() {
      gameState = GameState.dealerTurn;
    });

    dealerPlay();
  }

  void dealerPlay() async {
    // Reveal hidden card
    setState(() {
      dealerHand.cards[1].faceUp = true;
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    // Dealer draws until 17 or bust
    while (dealerHand.value < 17) {
      await dealCardToDealer();
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    endRound();
  }

  void endRound() {
    setState(() {
      gameState = GameState.roundEnd;


      if (playerHand.isBust) {
        // player busts, loses bet
      } else if (dealerHand.isBust) {
        // dealer busts, player wins
        playerChips += currentBet * 2;
      } else if (playerHand.isBlackjack && !dealerHand.isBlackjack) {
        // player blackjack
        playerChips += (currentBet * 2.5).round();
      } else if (playerHand.value > dealerHand.value) {
        // player wins
        playerChips += currentBet * 2;
      } else if (playerHand.value == dealerHand.value) {
        // Push
        playerChips += currentBet;
      }
      // else player loses (bet already deducted)
    });
  }

  void placeBet(int amount) {
    if (amount <= playerChips) {
      setState(() {
        currentBet = amount;
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
    return Scaffold(
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
          // Dealer's hand
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
              child: Text(
                getResultMessage(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          //player hand
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

          // Action buttons
          buildActionButtons(),
        ],
      ),
    );
  }

  Widget buildHand(Hand hand) {
    return SizedBox(
      height: 120,
      child: Stack(
        children: hand.cards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;

          return AnimatedBuilder(
            animation: cardAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(index * 30.0 - hand.cards.length * 15.0, 0),
                child: Transform.scale(
                  scale: cardAnimation.value,
                  child: _buildCard(card),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard(PlayingCard card) {
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
            onPressed: hit,
            child: const Text('HIT'),
          ),
          ElevatedButton(
            style: AppDecorations.buttonStyleRed,
            onPressed: stand,
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
          });
        },
        child: const Text('NEW ROUND'),
      ),
    );
  }
}

enum GameState { betting, playing, dealerTurn, roundEnd }