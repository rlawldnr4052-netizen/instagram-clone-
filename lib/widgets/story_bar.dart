import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone/models/story.dart';
import 'package:instagram_clone/pages/story_view_page.dart';

final supabase = Supabase.instance.client;

class StoryBar extends StatefulWidget {
  const StoryBar({super.key});

  @override
  State<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends State<StoryBar> {
  List<Story> _stories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStories();
  }

  Future<void> _fetchStories() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));
      
      final response = await supabase
          .from('stories')
          .select('*, profiles(username, avatar_url)')
          .gte('created_at', yesterday.toIso8601String())
          .order('created_at', ascending: false);

      final stories = (response as List).map((data) => Story.fromMap(data)).toList();
      
      if (mounted) {
        setState(() {
          _stories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stories (Table: stories): $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadStory() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    try {
      final userId = supabase.auth.currentUser!.id;
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = '$userId/$fileName';

      await supabase.storage.from('stories').uploadBinary(
        filePath,
        await image.readAsBytes(),
        fileOptions: FileOptions(contentType: image.mimeType!),
      );
       
      final imageUrl = supabase.storage.from('stories').getPublicUrl(filePath);

      await supabase.from('stories').insert({
        'user_id': userId,
        'image_url': imageUrl,
      });

      _fetchStories(); // Refresh
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story uploaded!')));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Group stories by user? For now just simple list as per request
    // "Story Circle: User profile... Pink gradient border if unread"
    // Since we don't track "read" status in DB yet, we'll assume all recent stories are "unread" or just style them all pink for now.
    
    // My Story Item
    final myId = supabase.auth.currentUser?.id;
    final myStories = _stories.where((s) => s.userId == myId).toList();
    final otherStories = _stories.where((s) => s.userId != myId).toList();

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 10),
          _buildMyStoryButton(myStories.isNotEmpty),
          ...otherStories.map((story) => _buildStoryItem(story)),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildMyStoryButton(bool hasStory) {
    // We should show the user's avatar here. Ideally check profile cache or fetch.
    // For now we can assume we might need to fetch it or just use a placeholder if not loaded in Feed.
    // FeedPage likely has it? No, it's separate. 
    // Let's rely on a simple fetch or placeholder. 
    // Actually, we can assume the user has a profile.
    
    // Simplification: Icon with +
    return GestureDetector(
      onTap: _uploadStory,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent, // No border for "My Story" unless posted?
                  // User said: "My profile and '+' icon at the front"
                ),
                child: const CircleAvatar(
                   radius: 32,
                   backgroundColor: Colors.grey,
                   child: Icon(Icons.person, color: Colors.white),
                   // TODO: Bind to real user avatar if available
                ),
              ),
              Positioned(
                bottom: 0,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Your Story', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStoryItem(Story story) {
    return GestureDetector(
      onTap: () {
        // Open story view
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoryViewPage(stories: [story]),
            // Ideally we pass all stories for that user or all stories in feed
          ),
        );
      },
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.purple, Colors.pink, Colors.orange],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
            padding: const EdgeInsets.all(3), // Border width
            child: Container(
              padding: const EdgeInsets.all(2), // Gap
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black, // Inner background
              ),
              child: CircleAvatar(
                radius: 28, // Image size
                backgroundImage: story.avatarUrl != null 
                    ? NetworkImage(story.avatarUrl!) 
                    : null,
                backgroundColor: Colors.grey[800],
                child: story.avatarUrl == null 
                    ? const Icon(Icons.person, color: Colors.white) 
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            story.username ?? 'User',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
