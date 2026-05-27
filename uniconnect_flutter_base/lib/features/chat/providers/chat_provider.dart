import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';

final chatMessagesProvider = Provider<List<ChatMessage>>((ref) {
  return const [
    ChatMessage(
      text: 'Professor, a entrega do trabalho mudou mesmo para sexta?',
      author: 'Lucas Oliveira',
      time: '14:08',
      isMine: true,
    ),
    ChatMessage(
      text:
          'Sim. O UniConnect ja deve mostrar o novo prazo como prioridade alta.',
      author: 'Prof. Marina',
      time: '14:10',
      isMine: false,
    ),
    ChatMessage(
      text: 'Perfeito, vou anexar a documentacao hoje.',
      author: 'Lucas Oliveira',
      time: '14:12',
      isMine: true,
    ),
  ];
});
