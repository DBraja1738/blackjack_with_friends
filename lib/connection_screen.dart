
import 'package:blackjack_with_friends/multiplayer_rooms.dart';
import 'package:flutter/material.dart';

import 'classes/tcp_sink.dart';

class InputIPScreen extends StatefulWidget {
  const InputIPScreen({super.key});

  @override
  State<InputIPScreen> createState() => _InputIPScreenState();
}

class _InputIPScreenState extends State<InputIPScreen> {
  String status= "status";
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("enter ip"),),

      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Enter ip"),
            SizedBox(height: 16,),
            Text(status),
            SizedBox(height: 16,),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                  border: OutlineInputBorder()
              ),
            ),
            ElevatedButton(onPressed: connectToServer, child: const Text("Connect"))
          ],
        ),
      ),
    );
  }
  Future<void> connectToServer() async {
    setState(() {
      status = "Connecting to server...";
    });

    try {
      final channel = await TCPChannel.connect(
        controller.text.trim(),
        1234,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          throw 'Connection timeout - server unreachable';
        },
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RoomScreen(channel: channel),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (e.toString().contains('timeout')) {
          status = "Server unreachable";
        } else {
          status = "Connection error: ${e.toString()}";
        }
      });
    }
  }
}