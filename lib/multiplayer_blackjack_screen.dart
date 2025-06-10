import 'package:flutter/material.dart';
import 'dart:convert';
import 'classes/tcp_sink.dart';
import "classes/game_models.dart";

class MultiplayerBlackjackScreen extends StatefulWidget {
  final TCPChannel channel;
  final String roomName;

  const MultiplayerBlackjackScreen({
    super.key,
    required this.channel,
    required this.roomName,
  });

  @override
  State<MultiplayerBlackjackScreen> createState() => _MultiplayerBlackjackScreenState();
}

class _MultiplayerBlackjackScreenState extends State<MultiplayerBlackjackScreen> {
  Map<String, dynamic> gameState = {};
  String myId = "";
  bool isMyTurn = false;
  String gamePhase = "waiting";
  int betAmount = 50;

  @override
  void initState() {
    super.initState();

    widget.channel.stream.listen((message) {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'game_update':
          setState(() {
            gameState = data;
            myId = data['yourId'];
            isMyTurn = data['currentPlayer'] == myId;
            gamePhase = data['phase'] ?? 'waiting';
          });
          break;

        case 'player_ready':
          _showSnackBar('${data['readyCount']}/${data['totalPlayers']} players ready');
          break;

        case 'betting_phase_start':
          setState(() {
            gamePhase = 'betting';
          });
          _showSnackBar('Place your bets!');
          break;

        case 'game_over':
          _showGameOverDialog(data);
          break;

        case 'game_reset':
          setState(() {
            gameState = {};
            gamePhase = 'waiting';
          });
          break;

        case 'error':
          _showSnackBar(data['message'], isError: true);
          break;
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  void _showGameOverDialog(Map<String, dynamic> data) {
    var myResult = data['results'][myId];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Game Over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dealer: ${data['dealerBust'] ? 'BUST' : data['dealerValue']}'),
            SizedBox(height: 20),
            Text(
              myResult['outcome'] == 'won' ? 'You Won!' :
              myResult['outcome'] == 'push' ? 'Push!' : 'You Lost',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: myResult['outcome'] == 'won' ? Colors.green :
                myResult['outcome'] == 'push' ? Colors.orange : Colors.red,
              ),
            ),
            if (myResult['winnings'] > 0)
              Text('Winnings: ${myResult['winnings']} chips'),
            Text('Total Chips: ${myResult['finalChips']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendReady();
            },
            child: Text('Play Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Leave room
            },
            child: Text('Leave Room'),
          ),
        ],
      ),
    );
  }

  void _sendReady() {
    widget.channel.sink.add(jsonEncode({'type': 'ready'}));
  }

  void _placeBet() {
    widget.channel.sink.add(jsonEncode({
      'type': 'bet',
      'amount': betAmount,
    }));
  }

  void _hit() {
    widget.channel.sink.add(jsonEncode({'type': 'hit'}));
  }

  void _stand() {
    widget.channel.sink.add(jsonEncode({'type': 'stand'}));
  }

  void _doubleDown() {
    widget.channel.sink.add(jsonEncode({'type': 'double_down'}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Blackjack - $widget.roomName'),
        backgroundColor: Colors.green[800],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[800]!, Colors.green[600]!],
          ),
        ),
        child: _buildGameContent(),
      ),
    );
  }

  Widget _buildGameContent() {
    if (gamePhase == 'waiting') {
      return _buildWaitingRoom();
    } else if (gamePhase == 'betting') {
      return _buildBettingPhase();
    } else {
      return _buildGameTable();
    }
  }

  Widget _buildWaitingRoom() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text(
            'Waiting for players...',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _sendReady,
            child: Text('Ready'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBettingPhase() {
    var myState = gameState['players']?[myId];

    return Center(
      child: Card(
        margin: EdgeInsets.all(20),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Place Your Bet', style: TextStyle(fontSize: 24)),
              SizedBox(height: 20),
              Text('Your Chips: ${myState?['chips'] ?? 0}'),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        betAmount = (betAmount - 10).clamp(10, 500);
                      });
                    },
                    icon: Icon(Icons.remove_circle),
                  ),
                  Container(
                    width: 100,
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$betAmount',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        betAmount = (betAmount + 10).clamp(10,
                            (myState?['chips'] ?? 500).clamp(0, 500)).toInt();
                      });
                    },
                    icon: Icon(Icons.add_circle),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _placeBet,
                child: Text('Place Bet'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTable() {
    return Column(
      children: [
        // Dealer section
        _buildDealerSection(),

        // Players section
        Expanded(
          child: _buildPlayersSection(),
        ),

        // Action buttons
        if (isMyTurn && gamePhase == 'playing')
          _buildActionButtons(),
      ],
    );
  }

  Widget _buildDealerSection() {
    var dealerHand = gameState['dealerHand'] ?? [];
    var dealerValue = gameState['dealerValue'];

    return Card(
      margin: EdgeInsets.all(16),
      color: Colors.green[700],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Dealer',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            if (dealerValue != null)
              Text(
                'Value: $dealerValue',
                style: TextStyle(color: Colors.white70),
              ),
            SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var cardData in dealerHand)
                    _buildCard(cardData),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersSection() {
    var players = gameState['players'] ?? {};

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (var playerId in players.keys)
          _buildPlayerSection(playerId, players[playerId]),
      ],
    );
  }

  Widget _buildPlayerSection(String playerId, Map<String, dynamic> playerData) {
    bool isMe = playerId == myId;
    bool isCurrentPlayer = gameState['currentPlayer'] == playerId;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: isCurrentPlayer ? Colors.amber[100] :
      isMe ? Colors.blue[100] : null,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isMe ? 'You' : 'Player $playerId',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Chips: ${playerData['chips']}'),
                    Text('Bet: ${playerData['currentBet']}'),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Text('Hand: ${playerData['handValue']}'),
                SizedBox(width: 10),
                if (playerData['isBlackjack'])
                  Chip(
                    label: Text('BLACKJACK!'),
                    backgroundColor: Colors.amber,
                  ),
                if (playerData['hasBusted'])
                  Chip(
                    label: Text('BUST'),
                    backgroundColor: Colors.red,
                  ),
              ],
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: Row(
                children: [
                  for (var cardData in playerData['hand'] ?? [])
                    _buildCard(cardData),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> cardData) {
    // Convert from JSON to your card model
    Suit suit = Suit.values.firstWhere(
            (s) => s.toString().split('.').last == cardData['suit']
    );
    Rank rank = Rank.values.firstWhere(
            (r) => r.toString().split('.').last == cardData['rank']
    );
    bool faceUp = cardData['faceUp'] ?? true;

    PlayingCard card = PlayingCard(suit: suit, rank: rank, faceUp: faceUp);

    return Container(
      width: 70,
      height: 100,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Image.asset(
        card.imagePath,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildActionButtons() {
    var myState = gameState['players']?[myId];
    bool canDoubleDown = myState != null &&
        myState['hand'].length == 2 &&
        myState['chips'] >= myState['currentBet'];

    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.green[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: _hit,
            child: Text('HIT'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
          ElevatedButton(
            onPressed: _stand,
            child: Text('STAND'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
          if (canDoubleDown)
            ElevatedButton(
              onPressed: _doubleDown,
              child: Text('DOUBLE'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
        ],
      ),
    );
  }
}