import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/communication/models/communication_models.dart';
import 'package:uniconnect/features/communication/services/communication_service.dart';

const _now = '2026-11-10T12:00:00.000Z';

Map<String, dynamic> noticeJson({String state = 'published', String? readAt}) =>
    {
      'id': 'notice-1',
      'authorId': 'teacher-1',
      'title': 'Prova remarcada',
      'content': 'A prova N1 será na sexta-feira.',
      'audienceType': 'class',
      'courseId': null,
      'classId': 'class-1',
      'state': state,
      'priority': 'high',
      'revision': 2,
      'expiresAt': null,
      'publishedAt': _now,
      'createdAt': _now,
      'updatedAt': _now,
      'readAt': readAt,
      'readRevision': readAt == null ? 0 : 2,
    };

Map<String, dynamic> messageJson(int sequence, {String sender = 'student-1'}) =>
    {
      'id': 'message-$sequence',
      'conversationId': 'conversation-1',
      'senderId': sender,
      'content': 'Mensagem $sequence',
      'sequence': sequence,
      'clientMessageId': '00000000-0000-4000-8000-00000000000$sequence',
      'createdAt': _now,
      'readByRecipient': false,
    };

Map<String, dynamic> realtimeJson({bool canSendNow = true, int last = 2}) => {
      'transport': 'supabase-broadcast',
      'private': true,
      'topic': 'uc:chat:tenant-1:conversation-1:auth-1',
      'events': ['message.created', 'conversation.read'],
      'lastSequence': last,
      'serverTime': _now,
      'serviceWindow': {
        'timeZone': 'America/Rio_Branco',
        'weekdays': [1, 2, 3, 4, 5],
        'opensAt': '13:00',
        'closesAt': '18:00',
        'canSendNow': canSendNow,
      },
    };

CommunicationService serviceWith(
    Future<http.Response> Function(http.Request request) handler) {
  return CommunicationService(
    ApiClient(
        baseUrl: 'https://fixture.invalid/api/v1',
        httpClient: MockClient(handler)),
    accessToken: 'token',
    tenantSlug: 'campus',
  );
}

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  test('lists notices of the requested view and flags unread ones', () async {
    late Uri requested;
    final service = serviceWith((request) async {
      requested = request.url;
      return json({
        'data': [noticeJson(), noticeJson(readAt: _now)],
        'meta': {'page': 1, 'limit': 50, 'total': 2},
      });
    });

    final notices = await service.notices(view: 'history');

    expect(requested.path, '/api/v1/tenants/campus/notices');
    expect(requested.queryParameters['view'], 'history');
    expect(notices.map((n) => n.isUnread), [true, false]);
    expect(notices.first.priority, NoticePriority.high);
  });

  test('creating and publishing a class notice sends the revision', () async {
    final bodies = <String, Map<String, dynamic>>{};
    final service = serviceWith((request) async {
      bodies[request.url.path] =
          jsonDecode(request.body) as Map<String, dynamic>;
      return json(request.url.path.endsWith('/publish')
          ? noticeJson()
          : noticeJson(state: 'draft'));
    });

    final notice = await service.createClassNotice(
      classId: 'class-1',
      title: 'Prova remarcada',
      content: 'A prova N1 será na sexta-feira.',
      priority: NoticePriority.high,
      publish: true,
    );

    expect(bodies['/api/v1/tenants/campus/notices'], {
      'title': 'Prova remarcada',
      'content': 'A prova N1 será na sexta-feira.',
      'priority': 'high',
      'audienceType': 'class',
      'classId': 'class-1',
    });
    expect(bodies['/api/v1/tenants/campus/notices/notice-1/publish'],
        {'expectedRevision': 2});
    expect(notice.isPublished, isTrue);
  });

  test('loads every page of messages after the last sequence', () async {
    final afters = <String?>[];
    final service = serviceWith((request) async {
      final after = request.url.queryParameters['afterSequence'];
      afters.add(after);
      return after == '0'
          ? json({
              'data': [messageJson(1), messageJson(2)],
              'meta': {'hasMore': true, 'nextAfterSequence': 2},
            })
          : json({
              'data': [messageJson(3)],
              'meta': {'hasMore': false, 'nextAfterSequence': 3},
            });
    });

    final messages = await service.messages('conversation-1');

    expect(afters, ['0', '2']);
    expect(messages.map((m) => m.sequence), [1, 2, 3]);
  });

  test('sends a message with a fresh UUID v4 idempotency id', () async {
    late Map<String, dynamic> body;
    final service = serviceWith((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return json(messageJson(4), 201);
    });

    await service.sendMessage('conversation-1', 'Olá, professor');

    expect(body['content'], 'Olá, professor');
    expect(
        body['clientMessageId'],
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
  });

  test('rejects a malformed notice instead of showing partial data', () async {
    final service = serviceWith((_) async => json({
          'data': [
            {...noticeJson(), 'title': ''}
          ],
        }));

    expect(service.notices(), throwsA(isA<ApiException>()));
  });
}
