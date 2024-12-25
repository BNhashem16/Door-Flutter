import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Building Gate Controller',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FirebaseUpdateScreen(),
    );
  }
}

class FirebaseUpdateScreen extends StatefulWidget {
  @override
  _FirebaseUpdateScreenState createState() => _FirebaseUpdateScreenState();
}

class _FirebaseUpdateScreenState extends State<FirebaseUpdateScreen> {
  bool isDoorOpen = false;

  Future<void> toggleDoorState() async {
    // Toggle the door state
    setState(() {
      isDoorOpen = !isDoorOpen;
    });

    String doorState = isDoorOpen ? "ON" : "OFF";

    // Update Firebase JSON
    final response = await http.put(
      Uri.parse('https://microiot.firebaseio.com/users/1BEy97EhEObAeP7U6s4CFM66IPr2/devices/D.json?auth=VSV5R6QkmXOT12rrR6fuawILTpJdM8GjUQhiyShM'),
      body: jsonEncode({
        'apikey': "D",
        'changedby': "ahmed hashem",
        'state': doorState,
        'name': "Door",
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': "Motor",
      }),
    );

    if (response.statusCode == 200) {
      showToast('Door state updated successfully');
    } else {
      showToast('Failed to update door state');
    }
  }

  void showToast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Building Gate Controller',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepOrangeAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Control the gate remotely with ease!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'Press the button below to open or close the gate. The state of the door will automatically update, and the current state will be reflected in real-time.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: toggleDoorState,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDoorOpen ? Colors.green[700] : Colors.red[700], // Green when open, red when closed
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 20.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Rounded corners for a soft design
                ),
                elevation: 10,
                shadowColor: Colors.grey[400],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDoorOpen ? Icons.lock_open : Icons.lock,
                    size: 28,
                    color: Colors.white,
                  ),
                  SizedBox(width: 20),
                  Text(
                    isDoorOpen ? 'Close Door' : 'Open Door',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),
            Text(
              'Current Door State: ${isDoorOpen ? "Open" : "Closed"}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDoorOpen ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
