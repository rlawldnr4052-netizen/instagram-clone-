import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

final supabase = Supabase.instance.client;

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    try {
      final myUserId = supabase.auth.currentUser!.id;

      // Fetch likes on MY posts
      // Logic: Get likes where post_id IN (posts where user_id = me)
      // Supabase Filter: inner join on posts
      final response = await supabase
          .from('likes')
          .select('created_at, profiles:user_id(username, avatar_url), posts!inner(user_id, image_url)')
          .eq('posts.user_id', myUserId)
          .neq('user_id', myUserId) // Don't show my own likes? Usually not.
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activities = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error fetching activities: $e');
      }
    }
  }

  String _timeAgo(String timestamp) {
    final date = DateTime.parse(timestamp);
    final difference = DateTime.now().difference(date);

    if (difference.inDays > 7) {
      return '${date.year}.${date.month}.${date.day}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.pink),
          onPressed: () => context.goNamed('feed'),
        ),
        title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _activities.isEmpty
              ? const Center(child: Text('No new activity.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    final profile = activity['profiles'];
                    final username = profile['username'] ?? 'Unknown';
                    final avatarUrl = profile['avatar_url'];
                    final postImage = activity['posts']['image_url']; // Assuming we select this
                    final timeAgo = _timeAgo(activity['created_at']);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                                children: [
                                  TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const TextSpan(text: ' liked your post.'),
                                  TextSpan(text: ' $timeAgo', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          if (postImage != null)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(image: NetworkImage(postImage), fit: BoxFit.cover),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
