import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'classes/tcp_sink.dart';
import 'multiplayer_blackjack_screen.dart';

class RoomScreen extends StatefulWidget {
  final TCPChannel channel;

  const RoomScreen({super.key, required this.channel});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  List<dynamic> rooms = [];
  bool isLoading = true;
  String? currentRoom;
  int playerChips = 1000;

  @override
  void initState() {
    super.initState();

    // Load player chips first
    _loadPlayerChips();

    widget.channel.stream.listen((message) {
      final data = jsonDecode(message);

      if (data["type"] == "rooms_list") {
        setState(() {
          rooms = data["rooms"];
          isLoading = false;
        });
      } else if (data["type"] == "status") {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );

          // If successfully joined a room, navigate to game
          if (data['message'].startsWith('joined room')) {
            String roomName = data['message'].substring('joined room '.length);
            navigateToGame(roomName);
          }
        }
      } else if (data["type"] == "room_created") {
        fetchRooms();
      }
    });

    fetchRooms();
  }

  Future<void> _loadPlayerChips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (doc.exists) {
          setState(() {
            playerChips = doc.data()?["current_chips"] ?? 1000;
          });
        }
      } catch (e) {
        print('Error loading player chips: $e');
      }
    }
  }

  @override
  void dispose() {
    // If in a room, leave it
    if (currentRoom != null) {
      widget.channel.sink.add(jsonEncode({
        "type": "leave",
        "room": currentRoom,
      }));
    }
    super.dispose();
  }

  void fetchRooms() {
    widget.channel.sink.add(jsonEncode({
      "type": "fetch_rooms",
    }));
  }

  void joinRoom(String roomName) {
    setState(() {
      currentRoom = roomName;
    });

    // Send chips info when joining
    widget.channel.sink.add(jsonEncode({
      "type": "join",
      "room": roomName,
      "chips": playerChips,  // Include player's actual chips
    }));
  }

  void navigateToGame(String roomName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiplayerBlackjackScreen(
          channel: widget.channel,
          roomName: roomName,
        ),
      ),
    ).then((_) {
      // User returned from game
      setState(() {
        currentRoom = null;
      });
      // Refresh room list and reload chips
      fetchRooms();
      _loadPlayerChips();
    });
  }

  void createRoom() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Create New Room'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Room name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  widget.channel.sink.add(jsonEncode({
                    "type": "create",
                    "name": controller.text.trim(),
                  }));
                  Navigator.pop(context);
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _disconnect() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect from server?'),
        content: Text('You will be disconnected from the game server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Close the channel
              widget.channel.close();

              // Pop both the dialog and this screen
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to IP input screen
            },
            child: Text(
              'Disconnect',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _disconnect();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chat Rooms'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _disconnect,
          ),
          actions: [
            // Show player chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                avatar: Icon(Icons.casino, size: 18),
                label: Text('$playerChips chips'),
                backgroundColor: Colors.amber[700],
              ),
            ),
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
              color: Colors.red,
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: createRoom,
              tooltip: 'Create Room',
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                fetchRooms();
                _loadPlayerChips();
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : rooms.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text("No rooms available", style: TextStyle(fontSize: 18)),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: createRoom,
                icon: Icon(Icons.add),
                label: Text('Create First Room'),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: () async {
            fetchRooms();
            await _loadPlayerChips();
          },
          child: ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final isFull = room["occupancy"] >= room["capacity"];

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isFull ? Colors.red : Colors.green,
                    child: Icon(
                      isFull ? Icons.block : Icons.chat,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(room["name"]),
                  subtitle: Text("${room["occupancy"]}/${room["capacity"]} users"),
                  trailing: isFull
                      ? Chip(
                    label: Text("FULL"),
                    backgroundColor: Colors.red.shade100,
                  )
                      : ElevatedButton(
                    onPressed: () => joinRoom(room["name"]),
                    child: Text("Join"),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}