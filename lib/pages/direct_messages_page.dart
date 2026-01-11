import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DirectMessagesPage extends StatefulWidget {
  const DirectMessagesPage({super.key});

  @override
  State<DirectMessagesPage> createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage> {
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _myProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final myUserId = supabase.auth.currentUser!.id;

      // 0. Fetch My Profile (for My Note)
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

      // 3. Find Mutuals
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
        debugPrint('Error fetching DM data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Direct Messages v2', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.edit_square, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Search Bar (Cosmetic)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.search, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Search', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),

                // 2. Horizontal Notes List
                if (_myProfile != null) 
                  Container(
                    height: 110,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 1 + _users.length, // My Note + Friends
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildMyNoteItem(); // First item is ME
                        final user = _users[index - 1]; // Friends
                        return _buildFriendNoteItem(user);
                      },
                    ),
                  ),

                // 3. Messages Label
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Messages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),

                // 4. Vertical Chat List
                Expanded(
                  child: _users.isEmpty
                      ? const Center(child: Text('No messages', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: user['avatar_url'] != null 
                                    ? NetworkImage(user['avatar_url']) 
                                    : null,
                                child: user['avatar_url'] == null 
                                    ? const Icon(Icons.person, color: Colors.white) 
                                    : null,
                              ),
                              title: Text(
                                user['username'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              subtitle: const Text(
                                'Sent a message', // Placeholder for last message
                                style: TextStyle(color: Colors.grey),
                              ),
                              trailing: const Icon(Icons.camera_alt_outlined, color: Colors.grey),
                              onTap: () => context.push('/chat/${user['id']}'),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // My Note Widget (Click to update)
  Widget _buildMyNoteItem() {
    final avatarUrl = _myProfile!['avatar_url'];
    final statusEmoji = _myProfile!['status_emoji'];

    return GestureDetector(
      onTap: _showEmojiPicker,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 80, // Consistent width
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 32, // Slightly larger
                  backgroundColor: Colors.grey[800],
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, size: 30, color: Colors.white) : null,
                ),
                Positioned(
                  top: -6,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Text(
                      statusEmoji ?? '➕',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Your Note',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Friend Note Widget (Display only)
  Widget _buildFriendNoteItem(Map<String, dynamic> user) {
    if (user['status_emoji'] == null) return const SizedBox.shrink(); // Don't show if no note? Or show avatar? Instagram shows avatar.
    // Actually Instagram notes show avatars even without notes? No, "Notes" section is for notes.
    // If no emoji, we might skip showing them in the horizontal status list.
    // Let's hide if no emoji for now to keep it clean, or show just avatar. 
    // User requested: "Friend's emoji notes".
    
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: 80,
      child: Column(
        children: [
           Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                  child: user['avatar_url'] == null ? const Icon(Icons.person, size: 30, color: Colors.white) : null,
                ),
                Positioned(
                  top: -6,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200], // White bubble
                      shape: BoxShape.circle, // Or rounded rect? Circle is easier
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Text(
                      user['status_emoji'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              user['username'] ?? 'User',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
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
      setState(() {
        _myProfile!['status_emoji'] = emoji;
      });
      await supabase.from('profiles').update({'status_emoji': emoji}).eq('id', myUserId);
    }
  }
}
