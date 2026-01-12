import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone/models/post.dart';

final supabase = Supabase.instance.client;

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    final response = await supabase
        .from('posts')
        .select('*, profiles(username, avatar_url, status_emoji), likes(user_id)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> scrollToTopAndRefresh() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
    setState(() {}); // Triggers FutureBuilder to re-run _fetchPosts
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removed for Glass UI
      extendBodyBehindAppBar: true, // Allow content to go behind top buttons if any

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return const Center(child: Text('No posts yet!'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 100, bottom: 100), // Add padding for floating UI
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final postData = posts[index];
                final post = Post.fromMap(postData);
                final likes = (postData['likes'] as List).length;
                final myUserId = supabase.auth.currentUser?.id;
                final isLiked = (postData['likes'] as List)
                    .any((like) => like['user_id'] == myUserId);

                return PostWidget(
                  post: post,
                  initialLikes: likes,
                  initialIsLiked: isLiked,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class PostWidget extends StatefulWidget {
  final Post post;
  final int initialLikes;
  final bool initialIsLiked;

  const PostWidget({
    super.key,
    required this.post,
    required this.initialLikes,
    required this.initialIsLiked,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late int _likes;
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLikes;
    _isLiked = widget.initialIsLiked;
  }

  Future<void> _toggleLike() async {
    final userId = supabase.auth.currentUser!.id;
    final postId = widget.post.id;

    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        await supabase.from('likes').insert({
          'user_id': userId,
          'post_id': postId,
        });
      } else {
        await supabase
            .from('likes')
            .delete()
            .match({'user_id': userId, 'post_id': postId});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likes += _isLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/profile/${widget.post.userId}'),
                child: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      radius: 16,
                      backgroundImage: widget.post.avatarUrl != null
                          ? NetworkImage(widget.post.avatarUrl!)
                          : null,
                      child: widget.post.avatarUrl == null
                          ? const Icon(Icons.person, size: 20, color: Colors.white)
                          : null,
                    ),
                    if (widget.post.statusEmoji != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Text(
                          widget.post.statusEmoji!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.push('/profile/${widget.post.userId}'),
                child: Text(
                  widget.post.username ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: Colors.white),
            ],
          ),
        ),
        Image.network(
          widget.post.imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          height: 400, // Taller image for Instagram look
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 400,
              color: Colors.grey[900],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => context.push('/comments/${widget.post.id}'),
                child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.send, color: Colors.white, size: 28),
              const Spacer(),
              const Icon(Icons.bookmark_border, color: Colors.white, size: 28),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_likes likes',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white),
                  children: [
                    TextSpan(
                      text: '${widget.post.username ?? 'User'} ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: widget.post.caption),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'View all comments',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
