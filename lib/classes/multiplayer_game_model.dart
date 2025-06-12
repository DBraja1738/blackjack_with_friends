
import 'game_models.dart';

// Game-specific room that extends the base Room functionality
class GameRoom {
  final String name;
  final int capacity;
  final Set<dynamic> clients = {}; // Will hold Client objects from server

  // Game-specific properties
  BlackjackGameState? gameState;
  Map<String, PlayerState> playerStates = {};

  GameRoom(this.name, {this.capacity = 3});

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "capacity": capacity,
      "occupancy": clients.length,
      "gameInProgress": gameState != null,
      "players": clients.map((c) => {
        'id': c.id,
        'ready': playerStates[c.id]?.isReady ?? false,
        'chips': playerStates[c.id]?.chips ?? 0,
      }).toList(),
    };
  }
}

// Player state for each connected player
class PlayerState {
  Hand hand = Hand();
  int chips;
  int currentBet = 0;
  bool isReady = false;
  bool hasStood = false;
  bool hasBusted = false;
  bool hasDoubledDown = false;
  String username = "Player";

  PlayerState({this.chips = 1000});

  Map<String, dynamic> toJson() {
    return {
      'hand': hand.cards.map((card) => {
        'suit': card.suit.toString().split('.').last,
        'rank': card.rank.toString().split('.').last,
        'faceUp': card.faceUp,
        'value': card.value,
      }).toList(),
      'handValue': hand.value,
      'chips': chips,
      'currentBet': currentBet,
      'hasStood': hasStood,
      'hasBusted': hand.isBust,
      'isBlackjack': hand.isBlackjack,
      "username": username
    };
  }
}

// Main game state
class BlackjackGameState {
  Deck deck = Deck();
  Hand dealerHand = Hand();
  String currentPlayerId = "";
  GamePhase phase = GamePhase.waiting;

  Map<String, dynamic> toJson() {
    return {
      'currentPlayer': currentPlayerId,
      'phase': phase.toString().split('.').last,
      'dealerHand': dealerHand.cards.map((card) => {
        'suit': card.suit.toString().split('.').last,
        'rank': card.rank.toString().split('.').last,
        'faceUp': card.faceUp,
        'value': card.value,
      }).toList(),
      'dealerValue': dealerHand.cards.isNotEmpty && dealerHand.cards.first.faceUp
          ? dealerHand.value
          : null,
    };
  }
}

// Game phases
enum GamePhase {
  waiting,      // Waiting for players to ready up
  betting,      // Players placing bets
  dealing,      // Initial card dealing
  playing,      // Players taking turns
  dealerTurn,   // Dealer playing
  finished      // Game over, showing results
}

// Result tracking for game end
class GameResult {
  String outcome = ''; // 'won', 'lost', 'push'
  int winnings = 0;
  int finalChips = 0;

  Map<String, dynamic> toJson() => {
    'outcome': outcome,
    'winnings': winnings,
    'finalChips': finalChips,
  };
}

// Helper functions for game logic

// Check if ace should be counted as 11 or 1
int calculateHandValue(List<PlayingCard> cards) {
  int value = 0;
  int aces = 0;

  for (var card in cards) {
    if (card.rank == Rank.ace) {
      aces++;
      value += 11;
    } else {
      value += card.value;
    }
  }

  // Convert aces from 11 to 1 if needed
  while (value > 21 && aces > 0) {
    value -= 10;
    aces--;
  }

  return value;
}

// Check if a hand is a blackjack (21 with 2 cards)
bool isBlackjack(List<PlayingCard> cards) {
  return cards.length == 2 && calculateHandValue(cards) == 21;
}

// Determine if all players have completed their turns
bool allPlayersFinished(GameRoom room) {
  for (var client in room.clients) {
    var state = room.playerStates[client.id];
    if (state != null && !state.hasStood && !state.hasBusted && !state.hand.isBlackjack) {
      return false;
    }
  }
  return true;
}

// Get the next active player
String? getNextActivePlayer(GameRoom room, String currentPlayerId) {
  var clientsList = room.clients.toList();
  var currentIndex = clientsList.indexWhere((c) => c.id == currentPlayerId);

  if (currentIndex == -1) return null;

  for (int i = 1; i <= clientsList.length; i++) {
    var nextIndex = (currentIndex + i) % clientsList.length;
    var nextClient = clientsList[nextIndex];
    var state = room.playerStates[nextClient.id];

    if (state != null && !state.hasStood && !state.hasBusted && !state.hand.isBlackjack) {
      return nextClient.id;
    }
  }

  return null;
}