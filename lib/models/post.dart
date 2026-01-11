class Post {
  final String id;
  final String userId;
  final String imageUrl;
  final String caption;
  final DateTime createdAt;
  final String? username; // Fetched from profiles
  final String? avatarUrl;

  Post({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.caption,
    required this.createdAt,
    this.username,
    this.avatarUrl,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'],
      userId: map['user_id'],
      imageUrl: map['image_url'],
      caption: map['caption'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      username: map['profiles'] != null ? map['profiles']['username'] : null,
      avatarUrl: map['profiles'] != null ? map['profiles']['avatar_url'] : null,
    );
  }
}
