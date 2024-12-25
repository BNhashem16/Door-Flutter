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
  bool isLoading = false; // Loading indicator for state change

  Future<void> toggleDoorState() async {
    setState(() {
      isLoading = true;
    });

    // Toggle the door state
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

    setState(() {
      isLoading = false;
      isDoorOpen = !isDoorOpen; // Toggle state
    });
  }

  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        duration: Duration(seconds: 2),
      ),
    );
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
        elevation: 8.0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Control your building gate remotely with ease!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'Press the button below to open or close the gate. The state of the door will automatically update.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: ElevatedButton(
                onPressed: isLoading ? null : toggleDoorState, // Disable button while loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDoorOpen ? Colors.green[700] : Colors.red[700], // Green when open, red when closed
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 40.0, vertical: 18.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50), // More rounded button for a soft feel
                  ),
                  elevation: 10,
                  shadowColor: Colors.grey[400],
                  textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLoading
                          ? Icons.hourglass_empty
                          : (isDoorOpen ? Icons.lock_open : Icons.lock),
                      size: 28,
                      color: Colors.white,
                    ),
                    SizedBox(width: 20),
                    Text(
                      isLoading
                          ? 'Processing...'
                          : (isDoorOpen ? 'Close Door' : 'Open Door'),
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: Text(
                'Current Door State: ${isDoorOpen ? "Open" : "Closed"}',
                key: ValueKey<bool>(isDoorOpen),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDoorOpen ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
