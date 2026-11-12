import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uniconnect/features/communication/models/communication_models.dart';
import 'package:uniconnect/features/communication/presentation/conversation_page.dart';
import 'package:uniconnect/features/communication/presentation/new_conversation_sheet.dart';
import 'package:uniconnect/features/communication/providers/communication_providers.dart';
import 'package:uniconnect/features/communication/realtime/chat_signal_source.dart';
import 'package:uniconnect/features/communication/realtime/conversation_sync.dart';
import 'package:uniconnect/features/teacher/providers/class_students_provider.dart';
import 'package:uniconnect/features/teacher/providers/teacher_activity_provider.dart';
import 'package:uniconnect/features/teacher/services/teacher_activity_service.dart';

import 'communication_service_test.dart'
    show json, messageJson, realtimeJson, serviceWith;
import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';

const _me = 'student-1';
const _other = 'teacher-1';

/// In-memory API for one conversation, paging two messages at a time.
class _FakeChatApi {
  final messages = <Map<String, dynamic>>[];
  final requests = <String>[];
  final sentIds = <String>[];
  bool canSendNow = true;
  bool loseNextSendResponse = false;
  bool failNextSendBeforeSaving = false;
  bool outsideHours = false;

  void add(String sender, String content, {String? clientId}) {
    final sequence = messages.length + 1;
    messages.add({
      ...messageJson(sequence, sender: sender),
      'id': 'message-$sequence',
      'content': content,
      'clientMessageId':
          clientId ?? '00000000-0000-4000-8000-0000000000${sequence + 10}',
    });
  }

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    requests.add('${request.method} ${path.split('/').last}'
        '${request.url.query.isEmpty ? '' : '?${request.url.query}'}');
    if (path.endsWith('/realtime')) {
      return json(realtimeJson(canSendNow: canSendNow, last: messages.length));
    }
    if (path.endsWith('/read')) return json({});
    if (request.method == 'POST' && path.endsWith('/messages')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final clientId = body['clientMessageId'] as String;
      sentIds.add(clientId);
      if (outsideHours) {
        return json({
          'error': {
            'code': 'CHAT_OUTSIDE_SERVICE_HOURS',
            'message': 'Fora do horario.'
          }
        }, 403);
      }
      if (failNextSendBeforeSaving) {
        failNextSendBeforeSaving = false;
        throw http.ClientException('offline');
      }
      final existing =
          messages.where((row) => row['clientMessageId'] == clientId);
      if (existing.isEmpty) {
        add(_me, body['content'] as String, clientId: clientId);
      }
      final saved =
          messages.firstWhere((row) => row['clientMessageId'] == clientId);
      if (loseNextSendResponse) {
        loseNextSendResponse = false;
        throw http.ClientException('response lost');
      }
      return json(saved, 201);
    }
    final after =
        int.parse(request.url.queryParameters['afterSequence'] ?? '0');
    final rest = messages.where((row) => (row['sequence'] as int) > after);
    final page = rest.take(2).toList();
    final hasMore = rest.length > 2;
    return json({
      'data': page,
      'meta': {
        'hasMore': hasMore,
        'nextAfterSequence':
            page.isEmpty ? after : page.last['sequence'] as int,
      },
    });
  }
}

class _FakeSubscription implements ChatSubscription {
  bool closed = false;
  final tokens = <String>[];
  @override
  Future<void> close() async => closed = true;
  @override
  Future<void> updateToken(String accessToken) async => tokens.add(accessToken);
}

class _FakeSignals implements ChatSignalSource {
  late void Function(String, Map<String, dynamic>) emit;
  late void Function(ChatConnection) state;
  String? topic;
  final subscription = _FakeSubscription();

  @override
  ChatSubscription subscribe({
    required String topic,
    required String accessToken,
    required void Function(String event, Map<String, dynamic> payload) onSignal,
    required void Function(ChatConnection state) onState,
  }) {
    this.topic = topic;
    emit = onSignal;
    state = onState;
    return subscription;
  }
}

Map<String, dynamic> _created(int sequence, {String id = 'conversation-1'}) => {
      'type': 'broadcast',
      'event': 'message.created',
      'payload': {
        'version': 1,
        'tenantId': 'tenant-1',
        'conversationId': id,
        'messageId': 'message-$sequence',
        'sequence': sequence,
      },
    };

ConversationSync _sync(_FakeChatApi api, {ChatSignalSource? signals}) =>
    ConversationSync(
      conversationId: 'conversation-1',
      myId: _me,
      service: serviceWith(api.handle),
      accessToken: 'token-1',
      signals: signals,
    );

void main() {
  test('catch-up follows every page and signals fetch only what is new',
      () async {
    final api = _FakeChatApi()
      ..add(_other, 'Olá')
      ..add(_me, 'Oi, professor')
      ..add(_other, 'Tudo certo?');
    final signals = _FakeSignals();
    final sync = _sync(api, signals: signals);
    addTearDown(sync.dispose);

    await sync.start();
    expect(signals.topic, startsWith('uc:chat:'));
    expect(sync.messages.map((m) => m.content),
        ['Olá', 'Oi, professor', 'Tudo certo?']);
    expect(sync.cursor, 3);
    expect(sync.canSend, isTrue);

    api.add(_other, 'Nova mensagem');
    api.requests.clear();
    signals.emit('message.created', _created(4));
    signals.emit('message.created', _created(4));
    signals.emit('message.created', _created(9, id: 'another'));
    await pumpEventQueue();

    expect(
        sync.messages.where((m) => m.content == 'Nova mensagem'), hasLength(1));
    expect(sync.cursor, 4);
    final fetches =
        api.requests.where((r) => r.startsWith('GET messages')).toList();
    expect(fetches.first, contains('afterSequence=3'));
    expect(fetches.skip(1), everyElement(contains('afterSequence=4')));
  });

  test('subscribing again after a reconnection recovers the gap', () async {
    final api = _FakeChatApi()..add(_other, 'Antes');
    final signals = _FakeSignals();
    final sync = _sync(api, signals: signals);
    addTearDown(sync.dispose);
    await sync.start();

    signals.state(ChatConnection.failed);
    api
      ..add(_other, 'Durante a queda 1')
      ..add(_other, 'Durante a queda 2')
      ..add(_other, 'Durante a queda 3');
    signals.state(ChatConnection.live);
    await pumpEventQueue();

    expect(sync.connection, ChatConnection.live);
    expect(sync.messages, hasLength(4));
    expect(sync.cursor, 4);
  });

  test('a lost send response converges to one message with the same id',
      () async {
    final api = _FakeChatApi()..add(_other, 'Olá');
    final sync = _sync(api);
    addTearDown(sync.dispose);
    await sync.start();

    api.loseNextSendResponse = true;
    await sync.send('Chegou?');
    await pumpEventQueue();

    expect(sync.messages.where((m) => m.content == 'Chegou?'), hasLength(1));
    expect(sync.pending, isEmpty);
    expect(api.sentIds, hasLength(1));
  });

  test('retrying a failed send reuses the same client message id', () async {
    final api = _FakeChatApi();
    final sync = _sync(api);
    addTearDown(sync.dispose);
    await sync.start();

    api.failNextSendBeforeSaving = true;
    await sync.send('Primeira tentativa');
    await pumpEventQueue();
    expect(sync.pending.single.error, 'Sem conexão. Toque para reenviar.');

    await sync.retry(sync.pending.single);
    await pumpEventQueue();

    expect(api.sentIds, hasLength(2));
    expect(api.sentIds.toSet(), hasLength(1));
    expect(sync.pending, isEmpty);
    expect(sync.messages.single.content, 'Primeira tentativa');
  });

  test('outside service hours keeps the text and closes sending', () async {
    final api = _FakeChatApi()..outsideHours = true;
    final sync = _sync(api);
    addTearDown(sync.dispose);
    await sync.start();

    await sync.send('Depois das 18h');

    expect(sync.canSend, isFalse);
    expect(sync.pending.single.error,
        'Fora do horário de atendimento. A mensagem não foi enviada.');
    expect(sync.messages, isEmpty);
  });

  test('read receipts of the other participant mark my messages', () async {
    final api = _FakeChatApi()
      ..add(_me, 'Primeira')
      ..add(_me, 'Segunda');
    final signals = _FakeSignals();
    final sync = _sync(api, signals: signals);
    addTearDown(sync.dispose);
    await sync.start();

    signals.emit('conversation.read', {
      'payload': {
        'version': 1,
        'conversationId': 'conversation-1',
        'readerId': _me,
        'upToSequence': 2,
      }
    });
    expect(sync.messages.any((m) => m.readByRecipient), isFalse);

    signals.emit('conversation.read', {
      'payload': {
        'version': 1,
        'conversationId': 'conversation-1',
        'readerId': _other,
        'upToSequence': 1,
      }
    });
    expect(sync.messages.map((m) => m.readByRecipient), [true, false]);
  });

  test('losing access closes the channel', () async {
    final api = _FakeChatApi();
    final signals = _FakeSignals();
    final sync = _sync(api, signals: signals);
    addTearDown(sync.dispose);
    await sync.start();

    final denied = serviceWith((_) async => json({
          'error': {'code': 'NOT_FOUND', 'message': 'x'}
        }, 404));
    await sync.updateAccess(denied, 'token-2');

    expect(signals.subscription.tokens, ['token-2']);
    expect(signals.subscription.closed, isTrue);
    expect(sync.connection, ChatConnection.unavailable);
  });

  test('signal parser accepts the SDK envelope and rejects other versions', () {
    expect(
        ChatSignal.parse('message.created', _created(5),
            conversationId: 'conversation-1'),
        isA<MessageCreatedSignal>());
    expect(
        ChatSignal.parse('message.created',
            {'version': 2, 'conversationId': 'conversation-1', 'sequence': 5},
            conversationId: 'conversation-1'),
        isNull);
    expect(
        ChatServiceWindow.fromJson(realtimeJson()['serviceWindow']).description,
        'Segunda a sexta, das 13h às 18h (horário do Acre)');
  });

  testWidgets('outside service hours the history stays readable',
      (tester) async {
    final api = _FakeChatApi()
      ..canSendNow = false
      ..add(_other, 'Mensagem antiga');
    await pumpDemoPage(
      tester,
      const ConversationPage(conversationId: 'conversation-1'),
      overrides: [
        unreadNotificationsProvider.overrideWith((ref) async => 0),
        communicationServiceProvider.overrideWithValue(serviceWith(api.handle)),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Mensagem antiga'), findsOneWidget);
    expect(find.text('Atendimento indisponível agora'), findsOneWidget);
    expect(
        find.text('Atualização automática a cada 30 segundos'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
  });

  testWidgets('teacher starts a conversation with a student of the class',
      (tester) async {
    final bodies = <Map<String, dynamic>>[];
    await pumpDemoPage(
      tester,
      const Scaffold(body: NewConversationSheet()),
      user: fakeTeacher,
      overrides: [
        teacherOfferingsProvider.overrideWith((ref) async =>
            const [TeacherOffering(id: 'class-1', name: 'Métodos Numéricos')]),
        classStudentsProvider.overrideWith((ref, classId) async => const [
              (id: 'student-9', name: 'Bruna Lima'),
              (id: 'student-1', name: 'Ana Souza'),
            ]),
        communicationServiceProvider
            .overrideWithValue(serviceWith((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return json({
            'id': 'conversation-7',
            'classId': 'class-1',
            'studentId': 'student-9',
            'teacherId': 'teacher-1',
            'lastSequence': 0,
            'createdAt': '2026-11-12T12:00:00.000Z',
            'updatedAt': '2026-11-12T12:00:00.000Z',
          }, 201);
        })),
      ],
    );
    await tester.pumpAndSettle();
    expect(
        find.text('Selecione uma turma para ver os alunos.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Métodos Numéricos').last);
    await tester.pumpAndSettle();
    expect(find.text('Bruna Lima'), findsOneWidget);

    await tester.tap(find.text('Bruna Lima'));
    await tester.pumpAndSettle();

    expect(bodies.single, {'classId': 'class-1', 'participantId': 'student-9'});
  });
}
