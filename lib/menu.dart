import 'dart:io';

import 'package:blackjack_with_friends/accounts.dart';
import 'package:blackjack_with_friends/daily_login.dart';
import 'package:blackjack_with_friends/menu_for_selecting_mode.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widgets/decorations.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainMenu(),
    );
  }
}

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  bool isLoggedIn = false;
  String username = "";

  void loadUsername() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try {
      DocumentSnapshot snapshot = await firestore
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      var userData = snapshot.data() as Map<String, dynamic>;

      username = userData["username"] ?? "";
      setState(() {});
    } catch (e) {
      print("failed to fetch user $e");
    }
  }

  void checkLoginStatus() {
    if (FirebaseAuth.instance.currentUser != null) {
      loadUsername();
      setState(() {
        isLoggedIn = true;
      });
    } else {
      setState(() {
        isLoggedIn = false;
        username = "";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Title
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "Blackjack with friends",
                      style: TextStyle(fontSize: 48),
                    ),
                  ),
                ),

                if (isLoggedIn)
                  Text("Hello $username"),

                SizedBox(height: 20),

                // Buttons
                Container(
                  constraints: BoxConstraints(maxWidth: 400),
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          style: AppDecorations.buttonStyle,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MenuForSelectingMode(),
                              ),
                            );
                          },
                          child: Text("Start"),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          style: AppDecorations.buttonStyleWhite,
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AccountTab(),
                              ),
                            );
                            checkLoginStatus();
                          },
                          child: Text("Accounts"),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () {
                            exit(0);
                          },
                          style: AppDecorations.buttonStyleRed,
                          child: Text("EXIT"),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: DailyBonusSystem(
                          key: ValueKey(isLoggedIn),
                          onBonusClaimed: () {
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}