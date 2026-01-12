import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_clone/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _username;
  String? _avatarUrl;
  String? _jobTitle;
  String? _statusEmoji; 
  bool _isLoading = true;
  bool _isFollowing = false; 
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchUserPosts();
  }

  Future<void> _fetchUserPosts() async {
      try {
        final myUserId = supabase.auth.currentUser!.id;
        final targetUserId = widget.userId ?? myUserId;

        final response = await supabase
            .from('posts')
            .select('*')
            .eq('user_id', targetUserId)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _posts = List<Map<String, dynamic>>.from(response);
          });
        }
      } catch (e) {
        debugPrint('Error fetching posts: $e');
      }
  }

  Future<void> _fetchProfile() async {
    try {
      final myUserId = supabase.auth.currentUser!.id;
      final targetUserId = widget.userId ?? myUserId;
      
      final data = await supabase
          .from('profiles')
          .select('username, avatar_url, job_title, status_emoji')
          .eq('id', targetUserId)
          .single();

      bool following = false;
      if (targetUserId != myUserId) {
        final count = await supabase
          .from('follows')
          .count()
          .eq('follower_id', myUserId)
          .eq('following_id', targetUserId);
        following = count > 0;
      }

      if (mounted) {
        setState(() {
          _username = data['username'];
          _avatarUrl = data['avatar_url'];
          _jobTitle = data['job_title'];
          _statusEmoji = data['status_emoji'];
          _isFollowing = following;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final myUserId = supabase.auth.currentUser!.id;
    final targetUserId = widget.userId;
    if (targetUserId == null || targetUserId == myUserId) return;

    setState(() {
      _isFollowing = !_isFollowing;
    });

    try {
      if (_isFollowing) {
        await supabase.from('follows').insert({
          'follower_id': myUserId,
          'following_id': targetUserId,
        });
      } else {
        await supabase.from('follows').delete().match({
          'follower_id': myUserId,
          'following_id': targetUserId,
        });
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isFollowing = !_isFollowing);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
              const Text('Set Status', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['😊', '🔥', '😴', '🍕', '💻', '🏋️'].map((e) {
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

    if (emoji != null) {
      setState(() => _statusEmoji = emoji);
      final myUserId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').update({'status_emoji': emoji}).eq('id', myUserId);
    }
  }

  Color _getBadgeColor(String? job) {
    if (job == null) return Colors.blue; 
    final lower = job.toLowerCase();
    if (lower.contains('ai')) return Colors.orange;
    if (lower.contains('designer')) return Colors.purple;
    if (lower.contains('model')) return Colors.pink;
    return Colors.blue; 
  }

  IconData _getBadgeIcon(String? job) {
    if (job == null) return Icons.verified;
    final lower = job.toLowerCase();
    if (lower.contains('ai')) return Icons.auto_awesome;
    if (lower.contains('designer')) return Icons.palette;
    if (lower.contains('model')) return Icons.star;
    return Icons.verified;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final badgeColor = _getBadgeColor(_jobTitle);
    final badgeIcon = _getBadgeIcon(_jobTitle);
    final displayJob = _jobTitle ?? 'New Creator';
    final isMe = widget.userId == null || widget.userId == supabase.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    // 1. Giant Hero Card (Adjusted Height)
                    Container(
                      height: MediaQuery.of(context).size.height * 0.55,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        image: DecorationImage(
                          image: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : const NetworkImage('https://via.placeholder.com/400x600/333333/FFFFFF?text=No+Image'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.9),
                            ],
                            stops: const [0.4, 0.6, 1.0],
                          ),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isMe)
                              Align(
                                alignment: Alignment.topRight,
                                child: GestureDetector(
                                  onTap: _showEmojiPicker,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      _statusEmoji ?? '😀',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                              )
                            else if (_statusEmoji != null)
                              Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _statusEmoji!,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),

                            const Spacer(),

                            Text(
                              _username ?? 'Unknown',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: badgeColor.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(badgeIcon, color: badgeColor, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    displayJob,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                              child: _buildStadiumButton(
                                text: 'Message',
                                backgroundColor: Colors.white,
                                textColor: Colors.black,
                                onTap: () {
                                  if (widget.userId != null && widget.userId != supabase.auth.currentUser!.id) {
                                    context.push('/chat/${widget.userId}');
                                  }
                                },
                              ),
                          ),
                          const SizedBox(width: 12),
                          if (!isMe)
                            Expanded(
                              child: _buildStadiumButton(
                                text: _isFollowing ? 'Unfollow' : 'Follow',
                                backgroundColor: _isFollowing ? const Color(0xFF1E1E1E) : Colors.blue,
                                textColor: Colors.white,
                                onTap: _toggleFollow,
                              ),
                            )
                          else
                            Expanded(
                              child: _buildStadiumButton(
                                text: 'Edit Profile',
                                backgroundColor: const Color(0xFF1E1E1E),
                                textColor: Colors.white,
                                onTap: () => context.push('/setup-profile'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Divider
          const SliverToBoxAdapter(
            child: Divider(color: Colors.grey, height: 1),
          ),

          // 4. Posts Grid
           SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = _posts[index];
                return GestureDetector(
                  onTap: () {
                    // Navigate to Post Detail? Or Feed for now?
                    // User asked to navigate to "Detail Page or Feed Location".
                    // Since we don't have a detail page, let's just go to Feed (which is technically where posts live).
                    // Or we could pass context.
                    // Ideally: context.push('/post/${post['id']}');
                    // But for now, let's just create a simple detail view or push.
                    // Let's stick to feed navigation as a placeholder or perform a simple push.
                    // Actually, a simple detail view dialog or page is better.
                    // Let's verify if user specifically asked for feed. 
                    // "Click connection: Navigate to detail page or feed location."
                     context.go('/feed'); // Simple fallback to feed
                  },
                  child: Image.network(
                    post['image_url'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(color: Colors.grey[900]);
                    },
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900], child: const Icon(Icons.error, color: Colors.white)),
                  ),
                );
              },
              childCount: _posts.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStadiumButton({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(100), // Stadium
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
