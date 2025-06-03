import 'dart:io';

import 'package:blackjack_with_friends/accounts.dart';
import 'package:blackjack_with_friends/game_screen.dart';
import 'package:flutter/material.dart';

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

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Column(

        children: <Widget>[
          Padding(padding: EdgeInsets.symmetric(vertical: 100), child: Text("Blackjack with friends", textScaler: TextScaler.linear(2),),),
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
