import 'package:flutter/material.dart';
import 'package:instagram_clone/main.dart';
import 'package:instagram_clone/models/comment.dart';

class CommentsPage extends StatefulWidget {
  final String postId;

  const CommentsPage({super.key, required this.postId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _commentController = TextEditingController();
  bool _isLoading = false;

  Future<List<Comment>> _fetchComments() async {
    final response = await supabase
        .from('comments')
        .select('*, profiles(username)')
        .eq('post_id', widget.postId)
        .order('created_at', ascending: true);

    final data = List<Map<String, dynamic>>.from(response);
    return data.map((map) => Comment.fromMap(map)).toList();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('comments').insert({
        'user_id': user.id,
        'post_id': widget.postId,
        'content': _commentController.text.trim(),
      });
      _commentController.clear();
      setState(() {}); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Comment>>(
              future: _fetchComments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[800],
                            child: const Icon(Icons.person, size: 20, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.white),
                                children: [
                                  TextSpan(
                                    text: '${comment.username ?? 'Unknown'} ',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: comment.content),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Colors.grey[900]!)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[800],
                    child: const Icon(Icons.person, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _addComment,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Post', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
