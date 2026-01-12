import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone/models/story.dart';

class StoryViewPage extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoryViewPage({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _animationController;
  Timer? _nextStoryTimer;
  late List<Story> _currentStories;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentStories = List.from(widget.stories);
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    
    _animationController.forward();
  }
  
  void _startTimer() {
    _animationController.forward();
  }

  void _nextStory() {
    if (_currentIndex < _currentStories.length - 1) {
      setState(() {
        _currentIndex++;
        _animationController.reset();
        _animationController.forward();
      });
    } else {
      context.pop(_hasChanges); // Close if last story
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _animationController.reset();
        _animationController.forward();
      });
    } else {
      _animationController.reset();
      _animationController.forward();
    }
  }

  Future<void> _deleteStory(Story story) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('stories').delete().eq('id', story.id);
      
      setState(() {
        _hasChanges = true;
        _currentStories.remove(story);
        if (_currentStories.isEmpty) {
          Navigator.of(context).pop(true); 
        } else {
          // Adjust index if needed
          if (_currentIndex >= _currentStories.length) {
            _currentIndex = _currentStories.length - 1;
          }
           _animationController.reset();
           _startTimer(); 
        }
      });
      debugPrint('Story deleted: ${story.id}');
    } catch (e) {
      debugPrint('Error deleting story: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nextStoryTimer?.cancel();
    super.dispose();
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStories.isEmpty) return const SizedBox();
    final story = _currentStories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // Image
            Center(
              child: Builder(
                builder: (context) {
                  debugPrint('STORY_IMAGE_URL: ${story.imageUrl}');
                  return Image.network(
                    story.imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                   if (loadingProgress == null) return child;
                   return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('StoryView: Failed to load image: ${story.imageUrl}');
                  debugPrint('StoryView Error: $error');
                  return Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const Icon(Icons.error, color: Colors.white, size: 40),
                       Text(story.imageUrl, style: const TextStyle(color: Colors.white, fontSize: 10)),
                     ],
                  );
                },
              );
            }),
            ),

            // Progress Bar
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: Row(
                children: _currentStories.asMap().entries.map((entry) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: LinearProgressIndicator(
                        value: entry.key == _currentIndex 
                            ? _animationController.value 
                            : (entry.key < _currentIndex ? 1.0 : 0.0),
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // User Info - Moved to Bottom Left
            Positioned(
              bottom: 40,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: story.avatarUrl != null ? NetworkImage(story.avatarUrl!) : null,
                    backgroundColor: Colors.grey,
                    child: story.avatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    story.username ?? 'User',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _timeAgo(story.createdAt),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            // Delete Button (Only for own stories) - Moved to Top Left to avoid overlap
            if (story.userId == Supabase.instance.client.auth.currentUser?.id)
              Positioned(
                top: 50,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    _animationController.stop(); // Pause timer
                    showDialog(
                      context: context, 
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Story?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () {
                             Navigator.pop(context);
                             _startTimer(); // Resume
                          }, child: const Text('Cancel')),
                          TextButton(onPressed: () {
                             Navigator.pop(context);
                             _deleteStory(story);
                          }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      )
                    );
                  },
                ),
              ),

            // Close Button
            Positioned(
              top: 50,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(_hasChanges),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
