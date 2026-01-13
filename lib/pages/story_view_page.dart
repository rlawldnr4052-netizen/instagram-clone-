import 'dart:async';
import 'dart:math';
import 'dart:ui';
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

class _StoryViewPageState extends State<StoryViewPage> with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  Timer? _nextStoryTimer;
  late List<Story> _currentStories;
  bool _hasChanges = false;
  
  // Real-time Reply Logic
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  RealtimeChannel? _subscription;
  final List<BubbleModel> _bubbles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentStories = List.from(widget.stories);
    _setupAnimation();
    _subscribeToReplies();
  }

  void _setupAnimation() {
    _progressController = AnimationController(
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
    
    _progressController.forward();
  }

  // --- Real-time Logic ---
  void _subscribeToReplies() {
    final storyId = _currentStories[_currentIndex].id;
    
    _subscription?.unsubscribe();
    _subscription = Supabase.instance.client
        .channel('public:story_replies:$storyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'story_replies',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'story_id', value: storyId),
          callback: (payload) {
             final message = payload.newRecord['message'] as String;
             _addBubble(message);
          },
        )
        .subscribe();
  }

  void _addBubble(String message) {
    if (!mounted) return;
    
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    // Random X start position (10% to 90% of screen width)
    final startX = 20.0 + _random.nextDouble() * (MediaQuery.of(context).size.width - 100);

    setState(() {
      _bubbles.add(BubbleModel(id: id, message: message, startX: startX));
    });

    // Auto remove after animation duration (e.g. 4 seconds)
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) {
        setState(() {
          _bubbles.removeWhere((b) => b.id == id);
        });
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    _replyFocusNode.unfocus();
    
    // Resume timer if paused by focus
    if (!_progressController.isAnimating) {
        _progressController.forward();
    }

    try {
      final story = _currentStories[_currentIndex];
      final user = Supabase.instance.client.auth.currentUser!;
      
      // Optimistic Update (Show my bubble immediately)
      // Note: Realtime might echo this back, handling dupes is hard without IDs, 
      // but simpler to just show it via realtime callback if latency is low.
      // However, for "instant" feel, we trigger locally. 
      // Ideally, the realtime callback handles it. We'll rely on realtime for "everyone sees it", 
      // including me. But to be safe vs latency, let's just insert.
      
      await Supabase.instance.client.from('story_replies').insert({
        'story_id': story.id,
        'user_id': user.id,
        'message': text,
      });
      
    } catch (e) {
      debugPrint('Reply failed: $e');
    }
  }

  // --- Navigation Logic ---
  void _nextStory() {
    if (_currentIndex < _currentStories.length - 1) {
      setState(() {
        _currentIndex++;
        _progressController.reset();
        _progressController.forward();
      });
      _subscribeToReplies(); // Resubscribe for new story
    } else {
      context.pop(_hasChanges); 
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _progressController.reset();
        _progressController.forward();
      });
      _subscribeToReplies();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  Future<void> _deleteStory(Story story) async {
    _progressController.stop();
    try {
      await Supabase.instance.client.from('stories').delete().eq('id', story.id);
      
      setState(() {
        _hasChanges = true;
        _currentStories.remove(story);
        if (_currentStories.isEmpty) {
          Navigator.of(context).pop(true); 
        } else {
          if (_currentIndex >= _currentStories.length) {
            _currentIndex = _currentStories.length - 1;
          }
          _progressController.reset();
          _progressController.forward();
          _subscribeToReplies();
        }
      });
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    _subscription?.unsubscribe();
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
      resizeToAvoidBottomInset: false, // Handle keyboard manually or allow overlay
      body: GestureDetector(
        onTapUp: (details) {
          // If keyboard is open, close it on tap
          if (_replyFocusNode.hasFocus) {
            _replyFocusNode.unfocus();
            _progressController.forward(); // Resume
            return;
          }
          
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // 1. Image Layer
            Positioned.fill(
              child: Image.network(
                story.imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                   if (loadingProgress == null) return child;
                   return const Center(
                     child: CircularProgressIndicator(color: Colors.white),
                   );
                },
                errorBuilder: (context, error, stackTrace) {
                   return Center(
                     child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.white, size: 40),
                          if (error.toString().contains('404'))
                             const Text('404 Not Found', style: TextStyle(color: Colors.red))
                          else if (error.toString().contains('403'))
                             const Text('403 Forbidden', style: TextStyle(color: Colors.red))
                          else
                             const Text('Error Loading Image', style: TextStyle(color: Colors.red)),
                        ],
                     ),
                   );
                },
              ),
            ),

            // 2. Floating Bubbles Layer
            ..._bubbles.map((b) => FloatingBubbleWidget(model: b)).toList(),

            // 3. UI Overlay (Progress, User Info, Buttons)
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
                            ? _progressController.value 
                            : (entry.key < _currentIndex ? 1.0 : 0.0),
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            Positioned(
              top: 55,
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
            
            // Delete Button
            if (story.userId == Supabase.instance.client.auth.currentUser?.id)
              Positioned(
                top: 55,
                right: 16, // Moved to right for consistency or keep left if intended
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _deleteStory(story),
                ),
              ),

             // Close Button (Top Right)
            Positioned(
              top: 55,
              right: story.userId == Supabase.instance.client.auth.currentUser?.id ? 56 : 16, // Adjust if delete btn exists
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(_hasChanges),
              ),
            ),

            // 4. Glassmorphism Reply Input (Bottom)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom, // Move up with keyboard
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.black.withOpacity(0.3),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: TextField(
                                controller: _replyController,
                                focusNode: _replyFocusNode,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Send a reply...',
                                  hintStyle: TextStyle(color: Colors.white70),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                                onTap: () => _progressController.stop(), // Pause story when typing
                                onSubmitted: (_) => _sendReply(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _sendReply,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.pink, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helper Classes ---

class BubbleModel {
  final String id;
  final String message;
  final double startX;
  
  BubbleModel({required this.id, required this.message, required this.startX});
}

class FloatingBubbleWidget extends StatefulWidget {
  final BubbleModel model;
  
  const FloatingBubbleWidget({super.key, required this.model});

  @override
  State<FloatingBubbleWidget> createState() => _FloatingBubbleWidgetState();
}

class _FloatingBubbleWidgetState extends State<FloatingBubbleWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Float duration
    );
    
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Calculate Position: Bottom -> Top
        // Start from bottom 100px up to top 100px
        final screenHeight = MediaQuery.of(context).size.height;
        final bottomOffset = 150.0; 
        final moveRange = screenHeight * 0.6;
        
        final currentBottom = bottomOffset + (moveRange * _animation.value);
        final opacity = 1.0 - _animation.value; // Fade out as it goes up

        return Positioned(
          bottom: currentBottom,
          left: widget.model.startX,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.5 + (_animation.value * 0.5), // Grow slightly or shrink? Let's stay steady or pop in
              child: child,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.model.message,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4)]
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
