class Story {
  final String id;
  final String userId;
  final String imageUrl;
  final DateTime createdAt;
  final String? username; // Joined from profiles
  final String? avatarUrl; // Joined from profiles

  Story({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.createdAt,
    this.username,
    this.avatarUrl,
  });

  factory Story.fromMap(Map<String, dynamic> map) {
    return Story(
      id: map['id'],
      userId: map['user_id'],
      imageUrl: map['image_url'],
      createdAt: DateTime.parse(map['created_at']),
      username: map['profiles']?['username'],
      avatarUrl: map['profiles']?['avatar_url'],
    );
  }
}
