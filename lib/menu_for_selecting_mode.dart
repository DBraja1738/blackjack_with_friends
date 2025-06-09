import 'package:blackjack_with_friends/connection_screen.dart';
import 'package:blackjack_with_friends/game_screen.dart';
import 'package:flutter/material.dart';
import 'widgets/decorations.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MenuForSelectingMode extends StatefulWidget {
  const MenuForSelectingMode({super.key});

  @override
  State<MenuForSelectingMode> createState() => _MenuForSelectingModeState();
}

class _MenuForSelectingModeState extends State<MenuForSelectingMode> {
  bool isLoggedin = false;

  void checkLoggedInStatus(){
    final user = FirebaseAuth.instance.currentUser;

    if(user!=null) isLoggedin = true;

    return;
  }

  @override
  void initState() {
    super.initState();
    checkLoggedInStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Select mode"),
      ),
      body: Row(
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.green[500]!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 8.0),
                      child: ElevatedButton(
                        style: AppDecorations.buttonStyleWhite,
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BlackjackGame()));
                        },
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person, size: 100,),
                            Text("Singleplayer")
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 8.0),
                      child: ElevatedButton(
                        style: AppDecorations.buttonStyleWhite,
                        onPressed: isLoggedin
                            ? (){
                              Navigator.push(context, MaterialPageRoute(builder: (context) => InputIPScreen()));
                            }
                            : null,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group, size: 100,),
                            Text("Multiplayer"),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
