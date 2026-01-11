class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final bool isMine; // Helper to distinguish my messages

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    required this.isMine,
  });

  factory Message.fromMap(Map<String, dynamic> map, String myUserId) {
    return Message(
      id: map['id'],
      senderId: map['sender_id'],
      receiverId: map['receiver_id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      isMine: map['sender_id'] == myUserId,
    );
  }
}
