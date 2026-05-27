class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.author,
    required this.time,
    required this.isMine,
  });

  final String text;
  final String author;
  final String time;
  final bool isMine;
}
