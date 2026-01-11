import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

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
        // title: const Text('Direct Messages v2', style: TextStyle(fontWeight: FontWeight.bold)), // Removed for clean look
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

                // 4. Vertical Chat List with Long Press Effect
                Expanded(
                  child: _users.isEmpty
                      ? const Center(child: Text('No messages', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return LongPressHeartTile(
                              user: user,
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
    if (user['status_emoji'] == null) return const SizedBox.shrink(); 
    
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

// ---------------------------------------------------------------------------
// Custom Widgets for Long Press & Heart Burst
// ---------------------------------------------------------------------------

class LongPressHeartTile extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const LongPressHeartTile({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  State<LongPressHeartTile> createState() => _LongPressHeartTileState();
}

class _LongPressHeartTileState extends State<LongPressHeartTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Long press duration
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Trigger Burst and Navigation!
        _triggerBurstAndNavigate();
      }
    });
  }

  void _triggerBurstAndNavigate() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(renderBox.size.center(Offset.zero));

    // 1. Show Burst
    final overlayEntry = OverlayEntry(
      builder: (context) => HeartBurstOverlay(position: position),
    );
    Overlay.of(context).insert(overlayEntry);

    // Remove overlay after animation
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });

    // 2. Navigate immediately (or with slight delay? User said "simultaneously")
    widget.onTap();
    
    // Reset controller for when/if they come back
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) => _controller.forward(),
      onLongPressEnd: (_) {
        if (_controller.status != AnimationStatus.completed) {
          _controller.reverse();
        }
      },
      child: Stack(
        children: [
          // Background Fill Animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return FractionallySizedBox(
                  widthFactor: _scaleAnimation.value,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    color: Colors.pink.withOpacity(0.3 + (_scaleAnimation.value * 0.4)), // Fade to stronger pink
                  ),
                );
              },
            ),
          ),
          // Content
          ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.user['avatar_url'] != null 
                  ? NetworkImage(widget.user['avatar_url']) 
                  : null,
              child: widget.user['avatar_url'] == null 
                  ? const Icon(Icons.person, color: Colors.white) 
                  : null,
            ),
            title: Text(
              widget.user['username'] ?? 'Unknown',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Sent a message',
              style: TextStyle(color: Colors.grey),
            ),
            trailing: const Icon(Icons.camera_alt_outlined, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class HeartBurstOverlay extends StatefulWidget {
  final Offset position;

  const HeartBurstOverlay({super.key, required this.position});

  @override
  State<HeartBurstOverlay> createState() => _HeartBurstOverlayState();
}

class _HeartBurstOverlayState extends State<HeartBurstOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<HeartParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Generate particles
    for (int i = 0; i < 15; i++) {
        _particles.add(HeartParticle(
            angle: _random.nextDouble() * 2 * pi,
            speed: _random.nextDouble() * 100 + 50,
            scale: _random.nextDouble() * 0.5 + 0.5,
        ));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _controller.forward().then((_) {
        // Remove overlay when done
        if (mounted) {
            // Find the overlay entry? In this structure, we can't easily self-remove 
            // without passing the entry. 
            // Actually, usually the parent removes it, or we rely on it being invisible.
            // But OverlayEntries sticks around. 
            // A common pattern is to pass the entry to the widget or use a Timer in the parent builder.
            // Simplified: This widget is built inside the OverlayEntry builder. 
            // We can't remove the entry from here easily.
            // BETTER APPROACH: The parent `_triggerBurstAndNavigate` created it.
            // But `OverlayEntry` doesn't auto-dispose.
            // Fix: We'll modify `_triggerBurstAndNavigate` to handle disposal. 
            // But wait, `builder` context is separate.
            // Let's make this widget self-disposing is tricky.
            // Standard way: store entry in a var, pass to widget, widget calls remove.
        }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _particles.map((p) {
            final distance = p.speed * _controller.value;
            final dx = cos(p.angle) * distance;
            final dy = sin(p.angle) * distance - (100 * _controller.value); // Float up
            final opacity = (1.0 - _controller.value).clamp(0.0, 1.0);

            return Positioned(
              left: widget.position.dx + dx - 10,
              top: widget.position.dy + dy - 10,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: p.scale,
                  child: const Text('💖', style: TextStyle(fontSize: 24, decoration: TextDecoration.none)),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class HeartParticle {
  final double angle;
  final double speed;
  final double scale;

  HeartParticle({required this.angle, required this.speed, required this.scale});
}
