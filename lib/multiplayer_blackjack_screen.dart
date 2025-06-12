import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'classes/firestore_stats_manager.dart';
import 'classes/game_models.dart';
import 'classes/tcp_sink.dart';

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

class _MultiplayerBlackjackScreenState extends State<MultiplayerBlackjackScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> gameState = {};
  String myId = "";
  bool isMyTurn = false;
  String gamePhase = "waiting";
  int betAmount = 50;

  // Waiting room state
  int readyCount = 0;
  int totalPlayers = 0;
  bool isReady = false;
  Map<String, bool> playerReadyStatus = {};

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    // Initialize Firestore stats
    FirestoreStatsManager.initializePlayerStats();

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
          if (gamePhase == 'dealing') {
            _animationController.forward();
          }
          break;

        case 'player_ready':
          setState(() {
            readyCount = data['readyCount'];
            totalPlayers = data['totalPlayers'];
            playerReadyStatus[data['playerId']] = true;
          });
          break;

        case 'betting_phase_start':
          setState(() {
            gamePhase = 'betting';
            if (data['initialChips'] != null) {
              gameState['myChips'] = data['initialChips'];
            }
          });
          _showNotification('Place your bets!', Colors.amber);
          break;

        case 'bet_placed':
          _showNotification('Player ${data['playerId']} bet ${data['amount']} chips', Colors.blue);
          break;

        case 'game_over':
          _updateFirestoreStats(data);
          _showGameOverDialog(data);
          break;

        case 'game_reset':
          setState(() {
            gameState = {};
            gamePhase = 'waiting';
            isReady = false;
            playerReadyStatus.clear();
            readyCount = 0;
          });
          break;

        case 'error':
          _showNotification(data['message'], Colors.red);
          break;

        case 'status':
          if (data['message'].contains('joined room')) {
            setState(() {
              totalPlayers = (totalPlayers + 1).clamp(0, 3);
            });
          }
          break;

        case 'player_left':
          setState(() {
            totalPlayers = data['playersRemaining'] ?? 0;
            playerReadyStatus.remove(data['playerId']);
            readyCount = playerReadyStatus.values.where((ready) => ready).length;
          });
          _showNotification('A player left the room', Colors.orange);
          break;
      }
    });
  }

  @override
  void dispose() {
    // Leave room when disposing
    _leaveRoom();
    _animationController.dispose();
    super.dispose();
  }

  void _leaveRoom() {
    // send leave message to server
    widget.channel.sink.add(jsonEncode({
      'type': 'leave',
      'room': widget.roomName,
    }));
  }

  void _showNotification(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _updateFirestoreStats(Map<String, dynamic> data) async {
    try {
      var myResult = data['results'][myId];
      var myState = gameState['players']?[myId];

      if (myResult != null && myState != null) {
        final FirebaseFirestore firestore = FirebaseFirestore.instance;
        try{
          firestore
              .collection("users")
              .doc(FirebaseAuth
              .instance.currentUser?.uid)
              .update({
                "current_chips": myResult["finalChips"],
              });

        }catch(e){}

        await FirestoreStatsManager.updateGameResult(
          outcome: myResult['outcome'],
          betAmount: myState['currentBet'] ?? 0,
          winnings: myResult['winnings'] ?? 0,
          finalChips: myResult['finalChips'] ?? 0,
          hadBlackjack: myState['isBlackjack'] ?? false,
          busted: myState['hasBusted'] ?? false,
        );
      }
    } catch (e) {
      print('Error updating Firestore stats: $e');
    }
  }

  void _showGameOverDialog(Map<String, dynamic> data) {
    var myResult = data['results'][myId];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                myResult['outcome'] == 'won' ? Colors.green[700]! :
                myResult['outcome'] == 'push' ? Colors.orange[700]! : Colors.red[700]!,
                Colors.black87,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white24,
              width: 2,
            ),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                myResult['outcome'] == 'won' ? Icons.celebration :
                myResult['outcome'] == 'push' ? Icons.handshake : Icons.sentiment_dissatisfied,
                size: 64,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                myResult['outcome'] == 'won' ? 'VICTORY!' :
                myResult['outcome'] == 'push' ? 'PUSH!' : 'DEFEAT',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Dealer: ${data['dealerBust'] ? 'BUST' : data['dealerValue']}',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    if (myResult['winnings'] > 0)
                      Text(
                        '+${myResult['winnings']} chips',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.casino, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '${myResult['finalChips']} chips',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendReady();
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Play Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.exit_to_app),
                    label: Text('Leave'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white54),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendReady() {
    setState(() {
      isReady = true;
    });
    widget.channel.sink.add(jsonEncode({'type': 'ready'}));
  }

  void _placeBet() {
    widget.channel.sink.add(jsonEncode({
      'type': 'bet',
      'amount': betAmount,
    }));
    setState(() {
      gamePhase = 'waiting_for_bets';
    });
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result){
        if(didPop) return;

        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: Colors.green[900],
        appBar: AppBar(
          title: Text('Blackjack - ${widget.roomName}'),
          backgroundColor: Colors.green[800],
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => _showExitConfirmation(),
          ),
          actions: [
            if (gamePhase != 'waiting')
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    'Room: ${widget.roomName}',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.green[800]!, Colors.green[900]!],
            ),
          ),
          child: _buildGameContent(),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Game?'),
        content: Text(
            gamePhase != 'waiting' && gamePhase != 'finished'
                ? 'You\'re in the middle of a game. Are you sure you want to leave?'
                : 'Are you sure you want to leave the room?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Leave screen
            },
            child: Text(
              'Leave',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    if (gamePhase == 'waiting') {
      return _buildWaitingRoom();
    } else if (gamePhase == 'betting' || gamePhase == 'waiting_for_bets') {
      return _buildBettingPhase();
    } else {
      return _buildGameTable();
    }
  }

  Widget _buildWaitingRoom() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        margin: EdgeInsets.all(20),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.casino,
                  size: 64,
                  color: Colors.green[700],
                ),
                SizedBox(height: 24),
                Text(
                  'Waiting for Players',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                LinearProgressIndicator(
                  value: totalPlayers > 0 ? readyCount / totalPlayers : 0,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(Colors.green),
                  minHeight: 8,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '$readyCount / $totalPlayers Players Ready',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                // Player list
                if (totalPlayers > 0)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < totalPlayers; i++)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: i < readyCount ? Colors.green : Colors.grey,
                                ),
                                SizedBox(width: 8),
                                Text('Player ${i + 1}'),
                                Spacer(),
                                if (i < readyCount)
                                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(height: 24),
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  child: ElevatedButton(
                    onPressed: isReady ? null : _sendReady,
                    child: Text(isReady ? 'Waiting for others...' : 'Ready to Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isReady ? Colors.grey : Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      textStyle: TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                if (totalPlayers < 2)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Need at least 2 players to start',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBettingPhase() {
    var myState = gameState['players']?[myId];
    bool hasBet = gamePhase == 'waiting_for_bets';

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        margin: EdgeInsets.all(20),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on,
                  size: 48,
                  color: Colors.amber[700],
                ),
                SizedBox(height: 16),
                Text(
                  hasBet ? 'Waiting for other players...' : 'Place Your Bet',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.casino, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Your Chips: ${gameState['myChips'] ?? myState?['chips'] ?? 1000}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (!hasBet) ...[
                  SizedBox(height: 24),
                  Text('Bet Amount', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            betAmount = (betAmount - 10).clamp(10, 500);
                          });
                        },
                        icon: Icon(Icons.remove_circle, size: 36),
                        color: Colors.red,
                      ),
                      Container(
                        width: 120,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$betAmount',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            betAmount = (betAmount + 10).clamp(10,
                                (myState?['chips'] ?? 500).clamp(0, 500)).toInt();
                          });
                        },
                        icon: Icon(Icons.add_circle, size: 36),
                        color: Colors.green,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Min: 10 | Max: 500',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _placeBet,
                    child: Text('Place Bet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      textStyle: TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 24),
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Your bet: $betAmount chips',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameTable() {
    return Column(
      children: [
        // Game phase indicator
        if (gamePhase == 'dealerTurn')
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            color: Colors.amber[700],
            child: Center(
              child: Text(
                'Dealer\'s Turn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

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

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[800]!],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Dealer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (dealerValue != null) ...[
                SizedBox(width: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Value: $dealerValue',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < dealerHand.length; i++)
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _animationController.value * -10),
                        child: _buildCard(dealerHand[i]),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
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

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrentPlayer
              ? [Colors.amber[100]!, Colors.amber[50]!]
              : isMe
              ? [Colors.blue[100]!, Colors.blue[50]!]
              : [Colors.white, Colors.grey[50]!],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCurrentPlayer ? Colors.amber : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentPlayer ? Colors.amber.withOpacity(0.3) : Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? 'You' : (playerData["username"] ?? "Player"),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isCurrentPlayer)
                          Text(
                            'Playing...',
                            style: TextStyle(
                              color: Colors.amber[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.casino, size: 16, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          '${playerData['chips']}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Text(
                      'Bet: ${playerData['currentBet']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hand: ${playerData['handValue']}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 8),
                if (playerData['isBlackjack'])
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'BLACKJACK!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (playerData['hasBusted'])
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'BUST',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
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
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          card.imagePath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    var myState = gameState['players']?[myId];
    bool canDoubleDown = myState != null &&
        myState['hand'].length == 2 &&
        myState['chips'] >= myState['currentBet'];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Text(
              'Your Turn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  onPressed: _hit,
                  label: 'HIT',
                  icon: Icons.add_circle,
                  color: Colors.blue,
                ),
                _buildActionButton(
                  onPressed: _stand,
                  label: 'STAND',
                  icon: Icons.pan_tool,
                  color: Colors.orange,
                ),
                if (canDoubleDown)
                  _buildActionButton(
                    onPressed: _doubleDown,
                    label: 'DOUBLE',
                    icon: Icons.exposure_plus_2,
                    color: Colors.purple,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}