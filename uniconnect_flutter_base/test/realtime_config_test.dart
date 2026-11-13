import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/config/realtime_config.dart';

void main() {
  test('chat realtime points to the published Supabase websocket', () {
    expect(RealtimeConfig.isConfigured, isTrue);
    // The Realtime client appends `/websocket` to the endpoint.
    expect('${RealtimeConfig.endpoint}/websocket',
        'wss://pvacwfypqsstdrfxajkg.supabase.co/realtime/v1/websocket');
  });
}
