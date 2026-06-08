import 'dart:convert';
import 'package:http/http.dart' as http;

/// Single source of truth for gate state read/toggle over Firebase REST.
///
/// Used by both the in-app control screen and the home-screen widget
/// background callback, so the HTTP contract lives in exactly one place.
class GateService {
  GateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Firebase RTDB REST endpoint for the gate device. Token is embedded
  /// (intentional config, same as the legacy in-app screen).
  static const String _url =
      'https://microiot.firebaseio.com/users/1BEy97EhEObAeP7U6s4CFM66IPr2/devices/D.json?auth=VSV5R6QkmXOT12rrR6fuawILTpJdM8GjUQhiyShM';

  static const Duration _timeout = Duration(seconds: 10);

  /// Reads current gate state. `true` = open (ON), `false` = closed (OFF).
  /// Throws on network / non-200 so callers can surface a disconnected state.
  Future<bool> fetchState() async {
    final response =
        await _client.get(Uri.parse(_url)).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('status ${response.statusCode}', Uri.parse(_url));
    }
    final data = jsonDecode(response.body);
    if (data is Map && data['state'] != null) {
      return data['state'] == 'ON';
    }
    return false;
  }

  /// Flips the gate. Sends the opposite of [currentOpen] and returns the
  /// new state on success. Throws on network / non-200.
  Future<bool> toggle({required bool currentOpen}) async {
    final newOpen = !currentOpen;
    final response = await _client
        .put(
          Uri.parse(_url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'apikey': 'D',
            'changedby': 'ahmed hashem',
            'state': newOpen ? 'ON' : 'OFF',
            'name': 'Door',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'type': 'Motor',
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('status ${response.statusCode}', Uri.parse(_url));
    }
    return newOpen;
  }

  void dispose() => _client.close();
}
