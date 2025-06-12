import 'dart:convert';
import 'dart:io';

import 'package:blackjack_with_friends/classes/multiplayer_game_model.dart';

class Client {
  final Socket socket;
  final String id;
  String? currentRoom;
  StringBuffer buffer = StringBuffer();

  Client(this.socket, this.id);
}

class TcpServerForWidget {
  ServerSocket? server;
  final Map<String, Client> clients = {};
  final Map<String, GameRoom> rooms = {};
  int clientIdCounter = 0;

  TcpServerForWidget() {

    rooms["General"] = GameRoom("General");
  }

  Future<void> start({String host = "0.0.0.0", int port = 1234}) async {
    server = await ServerSocket.bind(host, port);

    server!.listen((Socket socket) {
      handleNewClient(socket);
    });
  }

  void stop() {
    for (Client client in clients.values) {
      client.socket.close();
    }
    clients.clear();
    rooms.clear();
    server?.close();
  }

  List<Client> getGamePlayers(String roomName) {
    GameRoom? room = rooms[roomName];
    if (room == null) return [];

    return room.clients.take(3).map((client) => client as Client).toList(); //cast every dynamic class client to Client class
  }

  void handleNewClient(Socket socket) {
    final clientId = "client_${++clientIdCounter}";
    final client = Client(socket, clientId);
    clients[clientId] = client;

    print("new connection: $clientId from ${socket.remoteAddress.address}:${socket.remotePort}");

    socket.listen(
          (data) {
        client.buffer.write(utf8.decode(data));

        String bufferContent = client.buffer.toString();
        List<String> lines = bufferContent.split('\n');

        client.buffer = StringBuffer(lines.removeLast());

        for (String line in lines) {
          line = line.trim();
          if (line.isNotEmpty) {
            handleClientMessage(client, line);
          }
        }
      },
      onError: (error) {
        print("client $clientId error: $error");
        removeClient(client);
      },
      onDone: () {
        print("Client $clientId disconnected");
        removeClient(client);
      },
    );
  }

  void handleClientMessage(Client client, String message) {
    try {
      Map<String, dynamic> data = jsonDecode(message);
      print('Received from ${client.id}: $data');

      switch (data['type']) {
        case 'fetch_rooms':
          sendRoomsList(client);
          break;

        case 'create':
          createRoom(client, data['name']);
          break;

        case 'join':
          joinRoom(client, data['room'], data["chips"]);
          break;

        case "leave":
          handleLeaveRoom(client);
          break;

        case 'ready':
          handlePlayerReady(client);
          break;

        case 'bet':
          handlePlaceBet(client, data['amount'] ?? 0);
          break;

        case 'hit':
          handlePlayerHit(client);
          break;

        case 'stand':
          handlePlayerStand(client);
          break;

        case 'double_down':
          handleDoubleDown(client);
          break;

        default:
          sendToClient(client, {
            'type': 'error',
            'message': 'Unknown message type: ${data['type']}',
          });
      }
    } catch (e) {
      print('Error parsing message from ${client.id}: $e');
      sendToClient(client, {
        'type': 'error',
        'message': 'Invalid message format',
      });
    }
  }

  void createRoom(Client client, String? roomName) {
    if (roomName == null || roomName.isEmpty) {
      sendToClient(client, {
        "type": "status",
        "message": "Room name cant be empty",
      });
      return;
    }
    if (rooms.containsKey(roomName)) {
      sendToClient(client, {
        "type": "status",
        "message": "Room already exists",
      });
      return;
    }

    rooms[roomName] = GameRoom(roomName);

    sendToClient(client, {
      "type": "status",
      "message": "room created successfully",
    });
  }

  void joinRoom(Client client, String? roomName, int chips) {
    if (roomName == null || !rooms.containsKey(roomName)) {
      sendToClient(client, {
        "type": "status",
        "message": "room not found",
      });
      return;
    }

    GameRoom room = rooms[roomName]!;

    if (room.clients.length >= room.capacity) {
      sendToClient(client, {
        "type": "status",
        "message": "room is full",
      });
      return;
    }

    if (client.currentRoom != null) leaveRoom(client);

    room.clients.add(client);
    client.currentRoom = roomName;

    sendToClient(client, {
      "type": "status",
      "message": "joined room $roomName"
    });

    // Initialize player state for GameRoom
    room.playerStates[client.id] ??= PlayerState(chips: chips);

    if (room.gameState != null) {
      broadcastGameState(room);
    }
  }

  void leaveRoom(Client client) {
    if (client.currentRoom == null) return;
    GameRoom? room = rooms[client.currentRoom];

    if (room != null) {
      room.clients.remove(client);

      // Clean up game state for leaving player
      room.playerStates.remove(client.id);

      // If game is in progress and this was the current player, move to next
      if (room.gameState != null &&
          room.gameState!.currentPlayerId == client.id) {
        nextPlayer(room);
      }
    }
    client.currentRoom = null;
  }

  void removeClient(Client client) {
    leaveRoom(client);
    clients.remove(client.id);
    try {
      client.socket.close();
    } catch (e) {
      print("socket already closed? $e");
    }
  }

  void sendToClient(Client client, Map<String, dynamic> data) {
    try {
      String json = jsonEncode(data);
      client.socket.write('$json\n');
    } catch (e) {
      print('Error sending to client ${client.id}: $e');
    }
  }

  void sendRoomsList(Client client) {
    List<Map<String, dynamic>> roomsList = [];
    rooms.forEach((name, room) {
      roomsList.add(room.toJson());
    });

    sendToClient(client, {
      "type": "rooms_list",
      "rooms": roomsList,
    });
  }

  void handlePlayerReady(Client client) {
    if (client.currentRoom == null) return;

    GameRoom? room = rooms[client.currentRoom] as GameRoom?;
    if (room == null) return;


    if(room.playerStates[client.id] != null){
      room.playerStates[client.id]!.isReady = true;
    }

    // Notify other players
    broadcastToRoom(room, {
      'type': 'player_ready',
      'playerId': client.id,
      'readyCount': room.playerStates.values.where((p) => p.isReady).length,
      'totalPlayers': room.clients.length,
    });

    // Check if we can start
    if (room.clients.length >= 2 &&
        room.clients.every((c) => room.playerStates[c.id]?.isReady ?? false)) {
      startBettingPhase(room);
    }
  }

  void startBettingPhase(GameRoom room) {
    room.gameState = BlackjackGameState();
    room.gameState!.phase = GamePhase.betting;

    for (var client in room.clients) {
      sendToClient(client, {
        'type': 'betting_phase_start',
        'minBet': 10,
        'maxBet': 500,
        'initialChips': room.playerStates[client.id]?.chips ?? 1000,
      });
    }
  }

  void handlePlaceBet(Client client, int amount) {
    if (client.currentRoom == null) return;

    GameRoom? room = rooms[client.currentRoom] as GameRoom?;
    if (room == null || room.gameState == null) return;

    PlayerState playerState = room.playerStates[client.id]!;

    // Validate bet
    if (amount < 10 || amount > 500 || amount > playerState.chips) {
      sendToClient(client, {
        'type': 'error',
        'message': 'Invalid bet amount',
      });
      return;
    }

    playerState.currentBet = amount;
    playerState.chips -= amount;

    // Check if all players have bet
    bool allBetsPlaced = room.clients.every((c) =>
    room.playerStates[c.id]!.currentBet > 0
    );

    if (allBetsPlaced) {
      startDealingPhase(room);
    } else {
      broadcastToRoom(room, {
        'type': 'bet_placed',
        'playerId': client.id,
        'amount': amount,
      });
    }
  }

  void startDealingPhase(GameRoom room) {
    room.gameState!.phase = GamePhase.dealing;
    room.gameState!.deck.reset();

    // Deal initial cards
    for (int i = 0; i < 2; i++) {
      // Deal to players
      for (var client in room.clients) {
        var card = room.gameState!.deck.drawCard()!;
        room.playerStates[client.id]!.hand.addCard(card);
      }

      // Deal to dealer
      var dealerCard = room.gameState!.deck.drawCard()!;
      if (i == 1) dealerCard.faceUp = false; // Second dealer card face down
      room.gameState!.dealerHand.addCard(dealerCard);
    }

    // Check for blackjacks
    checkForBlackjacks(room);

    // Start playing phase
    room.gameState!.phase = GamePhase.playing;
    room.gameState!.currentPlayerId = room.clients.first.id;

    broadcastGameState(room);
  }

  void checkForBlackjacks(GameRoom room) {
    bool dealerBlackjack = room.gameState!.dealerHand.isBlackjack;

    for (var client in room.clients) {
      var playerState = room.playerStates[client.id]!;

      if (playerState.hand.isBlackjack) {
        if (dealerBlackjack) {
          // Push - return bet
          playerState.chips += playerState.currentBet;
        } else {
          // Blackjack pays 3:2
          playerState.chips += (playerState.currentBet * 2.5).round();
        }
        playerState.hasStood = true;
      }
    }
  }

  void handlePlayerHit(Client client) {
    if (client.currentRoom == null) return;

    GameRoom? room = rooms[client.currentRoom] as GameRoom?;
    if (room == null || room.gameState == null) return;

    // Verify it's this player's turn
    if (room.gameState!.currentPlayerId != client.id) {
      sendToClient(client, {
        'type': 'error',
        'message': 'Not your turn',
      });
      return;
    }

    PlayerState playerState = room.playerStates[client.id]!;

    // Draw card
    var card = room.gameState!.deck.drawCard()!;
    playerState.hand.addCard(card);

    // Check for bust
    if (playerState.hand.isBust) {
      playerState.hasBusted = true;
      nextPlayer(room);
    }

    broadcastGameState(room);
  }

  void handlePlayerStand(Client client) {
    if (client.currentRoom == null) return;

    GameRoom? room = rooms[client.currentRoom] as GameRoom?;
    if (room == null || room.gameState == null) return;

    if (room.gameState!.currentPlayerId != client.id) return;

    room.playerStates[client.id]!.hasStood = true;
    nextPlayer(room);
    broadcastGameState(room);
  }

  void handleDoubleDown(Client client) {
    if (client.currentRoom == null) return;

    GameRoom? room = rooms[client.currentRoom] as GameRoom?;
    if (room == null || room.gameState == null) return;

    if (room.gameState!.currentPlayerId != client.id) return;

    PlayerState playerState = room.playerStates[client.id]!;

    // Can only double down on first two cards
    if (playerState.hand.cards.length != 2) {
      sendToClient(client, {
        'type': 'error',
        'message': 'Can only double down on first two cards',
      });
      return;
    }

    // Check if player has enough chips
    if (playerState.chips < playerState.currentBet) {
      sendToClient(client, {
        'type': 'error',
        'message': 'Insufficient chips to double down',
      });
      return;
    }

    // Double the bet
    playerState.chips -= playerState.currentBet;
    playerState.currentBet *= 2;
    playerState.hasDoubledDown = true;

    // Draw one card and stand
    var card = room.gameState!.deck.drawCard()!;
    playerState.hand.addCard(card);
    playerState.hasStood = true;

    nextPlayer(room);
    broadcastGameState(room);
  }

  void nextPlayer(GameRoom room) {
    var clients = room.clients.toList();
    var currentIndex = clients.indexWhere((c) => c.id == room.gameState!.currentPlayerId);

    // Find next active player
    for (int i = 1; i <= clients.length; i++) {
      var nextIndex = (currentIndex + i) % clients.length;
      var nextClient = clients[nextIndex];
      var state = room.playerStates[nextClient.id]!;

      if (!state.hasStood && !state.hasBusted && !state.hand.isBlackjack) {
        room.gameState!.currentPlayerId = nextClient.id;
        broadcastGameState(room);
        return;
      }
    }

    // All players done, dealer's turn
    dealerPlay(room);
  }

  void dealerPlay(GameRoom room) {
    room.gameState!.phase = GamePhase.dealerTurn;
    room.gameState!.currentPlayerId = "";

    // Flip dealer's hidden card
    room.gameState!.dealerHand.cards.last.faceUp = true;

    // Dealer must hit on 16 and below, stand on 17 and above
    while (room.gameState!.dealerHand.value < 17) {
      var card = room.gameState!.deck.drawCard()!;
      room.gameState!.dealerHand.addCard(card);

      // Send update after each card
      broadcastGameState(room);

      // Add a small delay for dramatic effect (optional)
      Future.delayed(Duration(milliseconds: 500));
    }

    // Game finished, calculate results
    calculateResults(room);
  }

  void calculateResults(GameRoom room) {
    room.gameState!.phase = GamePhase.finished;

    int dealerValue = room.gameState!.dealerHand.value;
    bool dealerBust = room.gameState!.dealerHand.isBust;

    Map<String, GameResult> results = {};

    for (var client in room.clients) {
      var playerState = room.playerStates[client.id]!;
      var result = GameResult();

      if (playerState.hasBusted) {
        result.outcome = 'lost';
        result.winnings = 0;
      } else if (dealerBust || playerState.hand.value > dealerValue) {
        result.outcome = 'won';
        result.winnings = playerState.currentBet * 2;
        playerState.chips += result.winnings;
      } else if (playerState.hand.value == dealerValue) {
        result.outcome = 'push';
        result.winnings = playerState.currentBet;
        playerState.chips += result.winnings;
      } else {
        result.outcome = 'lost';
        result.winnings = 0;
      }

      result.finalChips = playerState.chips;
      results[client.id] = result;
    }

    broadcastToRoom(room, {
      'type': 'game_over',
      'dealerValue': dealerValue,
      'dealerBust': dealerBust,
      'results': results.map((id, result) => MapEntry(id, result.toJson())),
    });

    // Reset game state after a delay
    Future.delayed(Duration(seconds: 5), () {
      resetGame(room);
    });
  }

  void resetGame(GameRoom room) {
    room.gameState = null;

    for (var playerState in room.playerStates.values) {
      playerState.hand.clear();
      playerState.currentBet = 0;
      playerState.isReady = false;
      playerState.hasStood = false;
      playerState.hasBusted = false;
      playerState.hasDoubledDown = false;
    }

    broadcastToRoom(room, {
      'type': 'game_reset',
      'message': 'Ready for next game',
    });
  }

  void broadcastGameState(GameRoom room) {
    var gameState = room.gameState!.toJson();

    for (var client in room.clients) {
      var personalizedState = Map<String, dynamic>.from(gameState);

      // Add all players' states
      personalizedState['players'] = {};
      for (var c in room.clients) {
        personalizedState['players'][c.id] = room.playerStates[c.id]!.toJson();
      }

      personalizedState['yourId'] = client.id;
      personalizedState['type'] = 'game_update';

      sendToClient(client, personalizedState);
    }
  }

  void broadcastToRoom(GameRoom room, Map<String, dynamic> message) {
    for (var client in room.clients) {
      sendToClient(client, message);
    }
  }

  void handleLeaveRoom(Client client) {
    if (client.currentRoom != null) {
      String roomName = client.currentRoom!;
      leaveRoom(client);

      sendToClient(client, {
        "type": "status",
        "message": "left room $roomName"
      });

      // Notify other players in the room
      GameRoom? room = rooms[roomName];
      if (room != null) {
        broadcastToRoom(room, {
          'type': 'player_left',
          'playerId': client.id,
          'playersRemaining': room.clients.length,
        });
      }
    }
  }
}

void main() async {
  final server = TcpServerForWidget();
  await server.start(host: '0.0.0.0', port: 1234);

  print('TCP Server is running on port 1234');
  print('Press Ctrl+C to stop.');

  // keep server running
  await ProcessSignal.sigint.watch().first;

  print('\nShutting down server...');
  server.stop();
}