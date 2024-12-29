import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:Door/toast/toast_service.dart';

class FirebaseUpdateScreen extends StatefulWidget {
  @override
  _FirebaseUpdateScreenState createState() => _FirebaseUpdateScreenState();
}

class _FirebaseUpdateScreenState extends State<FirebaseUpdateScreen> {
  bool isDoorOpen = false;
  bool isLoading = false;

  Future<void> toggleDoorState() async {
    setState(() {
      isLoading = true;
    });

    String doorState = isDoorOpen ? "ON" : "OFF";

    final response = await http.put(
      Uri.parse(
          'https://microiot.firebaseio.com/users/1BEy97EhEObAeP7U6s4CFM66IPr2/devices/D.json?auth=VSV5R6QkmXOT12rrR6fuawILTpJdM8GjUQhiyShM'),
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
      showToast(context, 'Door state updated successfully');
    } else {
      showToast(context, 'Failed to update door state');
    }

    setState(() {
      isLoading = false;
      isDoorOpen = !isDoorOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Building Gate Controller',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
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
              'Press the button below to open or close the gate.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: isLoading ? null : toggleDoorState,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDoorOpen ? Colors.green : Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 40.0, vertical: 18.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
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
                    style: TextStyle(fontSize: 20, color: Colors.white),
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
