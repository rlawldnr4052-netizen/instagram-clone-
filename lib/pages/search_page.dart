import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_clone/main.dart'; // Verified: Status Emoji UI Implemented

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _myProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final myUserId = supabase.auth.currentUser!.id;

      // 0. Fetch My Profile (for Notes)
      final myProfileResponse = await supabase
          .from('profiles')
          .select('username, avatar_url, status_emoji')
          .eq('id', myUserId)
          .single();
      
      // 1. Get IDs of people I follow
      final followingResponse = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', myUserId);
      final followingIds = (followingResponse as List)
          .map((e) => e['following_id'] as String)
          .toSet();

      // 2. Get IDs of people following me
      final followersResponse = await supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', myUserId);
      final followerIds = (followersResponse as List)
          .map((e) => e['follower_id'] as String)
          .toSet();

      // 3. Find Mutuals (Intersection)
      final mutualIds = followingIds.intersection(followerIds).toList();

      final response = mutualIds.isEmpty 
          ? [] 
          : await supabase
              .from('profiles')
              .select('*, status_emoji')
              .inFilter('id', mutualIds);
      
      if (mounted) {
        setState(() {
          _myProfile = myProfileResponse;
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error fetching users: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Users')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_myProfile != null) _buildMyNoteHeader(),
                Expanded(
                  child: _users.isEmpty
                      ? const Center(child: Text('No mutual followers.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        backgroundImage: user['avatar_url'] != null 
                            ? NetworkImage(user['avatar_url']) 
                            : null,
                        child: user['avatar_url'] == null 
                            ? const Icon(Icons.person, color: Colors.white) 
                            : null,
                      ),
                      if (user['status_emoji'] != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Text(
                            user['status_emoji'],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    user['username'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                  onTap: () {
                    // Navigate to Chat Page
                    context.push('/chat/${user['id']}');
                  },
                );
                          },
                        ),
                ),
              ],
            ),
    );
  }
  Widget _buildMyNoteHeader() {
    final avatarUrl = _myProfile!['avatar_url'];
    final statusEmoji = _myProfile!['status_emoji'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      color: Colors.black, // Background matches
      child: Column(
        children: [
          GestureDetector(
            onTap: _showEmojiPicker,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                    ),
                    if (statusEmoji != null)
                      Positioned(
                        top: -10,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            statusEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      )
                    else 
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Note',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.grey, height: 30),
        ],
      ),
    );
  }

  Future<void> _showEmojiPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 200,
          child: Column(
            children: [
              const Text('Set Note', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['😊', '🔥', '😴', '🍕', '💻', '🏋️', '✨', '🤔'].map((e) {
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, e),
                    child: Text(e, style: const TextStyle(fontSize: 32)),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );

    if (emoji != null && mounted) {
      final myUserId = supabase.auth.currentUser!.id;
      // Optimistic update
      setState(() {
        _myProfile!['status_emoji'] = emoji;
      });
      await supabase.from('profiles').update({'status_emoji': emoji}).eq('id', myUserId);
    }
  }
}
