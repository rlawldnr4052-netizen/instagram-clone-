class Comment {
  final String id;
  final String userId;
  final String postId;
  final String content;
  final DateTime createdAt;
  final String? username; // Fetched from profiles

  Comment({
    required this.id,
    required this.userId,
    required this.postId,
    required this.content,
    required this.createdAt,
    this.username,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      userId: map['user_id'],
      postId: map['post_id'],
      content: map['content'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      username: map['profiles'] != null ? map['profiles']['username'] : null,
    );
  }
}
