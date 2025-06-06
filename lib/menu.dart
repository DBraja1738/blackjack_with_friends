import 'dart:io';

import 'package:blackjack_with_friends/accounts.dart';
import 'package:blackjack_with_friends/daily_login.dart';
import 'package:blackjack_with_friends/game_screen.dart';
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


  void loadUsername() async{
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    try{
      DocumentSnapshot snapshot = await firestore
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      var userData = snapshot.data() as Map<String, dynamic>;

      username = userData["username"] ?? "";
      setState(() {

      });
    }catch(e){
      print("failed to fetch user $e");
      rethrow;
    }
  }

  @override
  void initState(){

    super.initState();
    if(FirebaseAuth.instance.currentUser != null){
      loadUsername();

      isLoggedIn = true;

    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Column(

        children: <Widget>[
          Padding(padding: EdgeInsets.symmetric(vertical: 100), child: Text("Blackjack with friends", textScaler: TextScaler.linear(2),),),
          if(isLoggedIn) Text("hello $username"),
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: Container(color: Colors.green[600],),

              ),
              Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[

                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                            style: AppDecorations.buttonStyle,
                            onPressed: (){
                              Navigator.push(context, MaterialPageRoute(builder: (context)=>const BlackjackGame()));
                            },
                            child: Text("Start")
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                            style: AppDecorations.buttonStyleWhite,
                            onPressed: (){
                              Navigator.push(context, MaterialPageRoute(builder: (context)=> AccountTab()));
                            },
                            child: Text("Accounts")
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: (){
                            exit(0);
                          },
                          style: AppDecorations.buttonStyleRed,
                          child: Text("EXIT"),

                        ),

                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: DailyBonusSystem(
                          onBonusClaimed: (){
                            setState(() {

                            });
                          },
                        )

                      ),
                    ],
                  )

              ),
              Expanded(
                flex: 2,
                child: Container(color: Colors.green,),

              ),

            ],
          ),
        ],
      ),
    );
  }
}
