import 'package:flutter_test/flutter_test.dart';
import 'package:Door/logs/gate_log.dart';

void main() {
  group('GateLog', () {
    test('toMap/fromMap round-trips all fields', () {
      const log = GateLog(
        id: 'log1',
        uid: 'user1',
        name: 'Ahmed',
        action: GateAction.open,
        source: GateSource.widget,
        timestamp: 1700000000000,
      );

      final restored = GateLog.fromMap('log1', 'user1', log.toMap());

      expect(restored.id, 'log1');
      expect(restored.uid, 'user1');
      expect(restored.name, 'Ahmed');
      expect(restored.action, GateAction.open);
      expect(restored.source, GateSource.widget);
      expect(restored.timestamp, 1700000000000);
    });

    test('fromMap defaults unknown action to close and source to app', () {
      final log = GateLog.fromMap('id', 'uid', const {
        'name': 'X',
        'timestamp': 1,
      });

      expect(log.action, GateAction.close);
      expect(log.source, GateSource.app);
    });

    test('toMap encodes close + app as strings', () {
      const log = GateLog(
        id: 'i',
        uid: 'u',
        name: 'n',
        action: GateAction.close,
        source: GateSource.app,
        timestamp: 5,
      );

      expect(log.toMap()['action'], 'close');
      expect(log.toMap()['source'], 'app');
    });
  });
}
