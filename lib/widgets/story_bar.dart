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
    final myId = supabase.auth.currentUser?.id;
    final now = DateTime.now().toUtc();
    final yesterday = now.subtract(const Duration(hours: 24));
    List<Story> fetchedStories = [];

    try {
      // 1. Fetch Stories (No Join)
      final response = await supabase
          .from('stories')
          .select()
          .gte('created_at', yesterday.toIso8601String())
          .order('created_at', ascending: false);
      
      final rawStories = List<Map<String, dynamic>>.from(response as List);

      if (rawStories.isNotEmpty) {
        // 2. Fetch Profiles manualy
        final userIds = rawStories.map((s) => s['user_id'] as String).toSet().toList();
        final profilesResponse = await supabase
            .from('profiles')
            .select()
            .filter('id', 'in', userIds);
        
        final profilesMap = {
          for (var p in profilesResponse) p['id'] as String: p
        };

        // 3. Merge Data
        fetchedStories = rawStories.map((data) {
          final profile = profilesMap[data['user_id']];
          return Story(
            id: data['id'],
            userId: data['user_id'],
            imageUrl: data['image_url'],
            createdAt: DateTime.parse(data['created_at']),
            username: profile?['username'] ?? 'User',
            avatarUrl: profile?['avatar_url'],
          );
        }).toList();
      }

    } catch (e) {
      debugPrint('Story Query Failed: $e');
    }

    if (mounted) {
      setState(() {
        _stories = fetchedStories;
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadStory() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    try {
      final userId = supabase.auth.currentUser!.id;
      // Force simple filename: timestamp + jpg
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = fileName; // No folders, just filename for simplicity

      await supabase.storage.from('stories').uploadBinary(
        filePath,
        await image.readAsBytes(),
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
       
      // Get Public URL
      final imageUrl = supabase.storage.from('stories').getPublicUrl(filePath);
      
      // Manual Validation Log
      if (imageUrl.contains('//stories//')) {
        debugPrint('CRITICAL WARNING: Double slash detected in URL!');
      }
      debugPrint('VALIDATED URL [Standard]: $imageUrl');

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

    // Group other stories by User ID
    final Map<String, List<Story>> groupedStories = {};
    for (var story in otherStories) {
      if (!groupedStories.containsKey(story.userId)) {
        groupedStories[story.userId] = [];
      }
      groupedStories[story.userId]!.add(story);
    }

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 10),
          _buildMyStoryButton(myStories),
          ...groupedStories.entries.map((entry) {
             // Pass the LIST of stories for this user
             return _buildStoryItem(entry.value); 
          }),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildMyStoryButton(List<Story> myStories) {
    final hasStory = myStories.isNotEmpty;

    if (hasStory) {
      // Show Active Story (Gradient Ring) WITH persistent + button
      return Column(
        children: [
          Stack(
            children: [
              // 1. Main Avatar -> View Story
              GestureDetector(
                onTap: () async {
                  // Sort stories by createdAt (Oldest -> Newest) for playback
                  final sortedStories = List<Story>.from(myStories)
                    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                    
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                       builder: (context) => StoryViewPage(stories: sortedStories),
                    ),
                  );
                  // Refresh stories if changes occurred (delete/view)
                  if (result == true) {
                    _fetchStories();
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.pink, Colors.orange],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                ),
              ),
              // 2. Small Plus Button -> Add Story
              Positioned(
                bottom: 0,
                right: 5,
                child: GestureDetector(
                  onTap: _uploadStory, // Triggers upload immediately
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Your Story', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
    } else {
      // Show Upload Button (+ Badge)
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
                    color: Colors.transparent,
                  ),
                  child: const CircleAvatar(
                     radius: 32, // Slightly larger match visual
                     backgroundColor: Colors.grey,
                     child: Icon(Icons.person, color: Colors.white),
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
                      border: Border.fromBorderSide(BorderSide(color: Colors.black, width: 2)),
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
  }

  Widget _buildStoryItem(List<Story> userStories) {
    if (userStories.isEmpty) return const SizedBox.shrink();
    
    // Use the first story for the avatar/name (all should be same user)
    final mainStory = userStories.first; 

    return GestureDetector(
      onTap: () async {
        // Sort stories chronologically for playback
        final sortedStories = List<Story>.from(userStories)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // Open story view with ALL stories from this user
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoryViewPage(stories: sortedStories),
          ),
        );
        if (result == true) {
           _fetchStories();
        }
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
                backgroundImage: mainStory.avatarUrl != null 
                    ? NetworkImage(mainStory.avatarUrl!) 
                    : null,
                backgroundColor: Colors.grey[800],
                child: mainStory.avatarUrl == null 
                    ? const Icon(Icons.person, color: Colors.white) 
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mainStory.username ?? 'User',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
