import 'package:blackjack_with_friends/multiplayer_blackjack_screen.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'classes/tcp_sink.dart';

class RoomScreen extends StatefulWidget {
  final TCPChannel channel;

  const RoomScreen({super.key, required this.channel});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  List<dynamic> rooms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

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
        }
      } else if (data["type"] == "room_created") {

        fetchRooms();
      }
    });


    fetchRooms();
  }

  void fetchRooms() {
    widget.channel.sink.add(jsonEncode({
      "type": "fetch_rooms",
    }));
  }

  void joinRoom(String roomName) {
    widget.channel.sink.add(jsonEncode({
      "type": "join",
      "room": roomName,
    }));


    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiplayerBlackjackScreen(channel: widget.channel, roomName: roomName)
      ),
    ).then((_) {
      // Refresh
      fetchRooms();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Rooms'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: createRoom,
            tooltip: 'Create Room',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchRooms,
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
        onRefresh: () async => fetchRooms(),
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
    );
  }
}