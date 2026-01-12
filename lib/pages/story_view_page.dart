import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _animationController.reset();
        _animationController.forward();
      });
    } else {
      context.pop(); // Close if last story
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

  @override
  void dispose() {
    _animationController.dispose();
    _nextStoryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

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
              child: Image.network(
                story.imageUrl,
                fit: BoxFit.cover,
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
              ),
            ),

            // Progress Bar
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: LinearProgressIndicator(
                value: _animationController.value,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

            // User Info
            Positioned(
              top: 55,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: story.avatarUrl != null 
                      ? NetworkImage(story.avatarUrl!) 
                      : null,
                    radius: 16,
                    backgroundColor: Colors.grey,
                    child: story.avatarUrl == null ? const Icon(Icons.person, size: 16) : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    story.username ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Close Button
            Positioned(
              top: 50,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
