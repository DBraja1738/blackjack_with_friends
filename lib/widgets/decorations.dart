import 'package:flutter/material.dart';

class AppDecorations {
  static const Color primaryColor = Colors.green;
  static const Color secondaryColor = Colors.greenAccent;

  static final BoxDecoration boxDecoration = BoxDecoration(
    color: Colors.green[600],
    borderRadius: BorderRadius.circular(10),
    boxShadow: [
      BoxShadow(
        color: Colors.green[900]!.withOpacity(0.5),
        spreadRadius: 3,
        blurRadius: 5,
        offset: Offset(0, 3),
      ),
    ],
  );

  static final TextStyle playerTextStyle = TextStyle(
    fontSize: 22,
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  static final TextStyle scoreTextStyle = TextStyle(
    fontSize: 24,
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  static final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.green[900],
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );
  static final ButtonStyle buttonStyleSubmit = ElevatedButton.styleFrom(
    backgroundColor: Colors.white38,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );

  static final ButtonStyle buttonStyleRed = ElevatedButton.styleFrom(
    backgroundColor: Colors.red[700],
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );

  static final ButtonStyle buttonStyleWhite = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );

  static final InputDecoration inputDecoration = InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    filled: true,
    fillColor: Colors.green[50],
  );

  static final BoxDecoration drawerHeaderDecoration = BoxDecoration(
    color: Colors.green[900],
    boxShadow: [
      BoxShadow(
        color: Colors.green[600]!.withOpacity(0.5),
        spreadRadius: 3,
        blurRadius: 5,
        offset: Offset(0, 3),
      ),
    ],
  );
}