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
  
  // Real-time & Comment Logic
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  RealtimeChannel? _subscription;
  
  // Using a Set or Map to prevent duplicates might be smart, but List is fine for now
  List<CommentModel> _comments = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentStories = List.from(widget.stories);
    _setupAnimation();
    _loadCommentsAndSubscribe();
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

  // --- Data Logic ---
  void _loadCommentsAndSubscribe() {
    final storyId = _currentStories[_currentIndex].id;
    
    // 1. Reset Comments for new story
    setState(() {
      _comments = [];
    });

    // 2. Fetch Existing Comments (with Profiles)
    _fetchExistingComments(storyId);

    // 3. Subscribe to New Comments
    _subscription?.unsubscribe();
    _subscription = Supabase.instance.client
        .channel('public:story_replies:$storyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'story_replies',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'story_id', value: storyId),
          callback: (payload) {
             _handleNewComment(payload.newRecord);
          },
        )
        .subscribe();
  }

  Future<void> _fetchExistingComments(String storyId) async {
    try {
      final response = await Supabase.instance.client
          .from('story_replies')
          .select('*, profiles(*)') // Assuming FK is setup correctly or we might need manual fetch if not
          .eq('story_id', storyId);
          // Note: If 'profiles' relation isn't detected automatically, we'd need to manually join.
          // Since we just created the table without explicit FK name in Dart side, let's hope Supabase infers it 
          // or we simply fetch user info manually to be safe.
      
      final data = List<Map<String, dynamic>>.from(response);
      
      // If simple join fails, failover: fetch profiles manually? 
      // Let's assume standard select for now. If user_id is FK to profiles.id, Supabase works well.
      
      if (!mounted) return;
      
      final List<CommentModel> loaded = [];
      for (var item in data) {
         final profile = item['profiles'] ?? {}; // Might be null if join failed
         loaded.add(
           CommentModel(
             id: item['id'],
             message: item['message'],
             username: profile['username'] ?? 'User',
             avatarUrl: profile['avatar_url'],
             // Random position for "Floating" effect (0.1 to 0.8 of screen w/h)
             initialX: 0.1 + _random.nextDouble() * 0.7,
             initialY: 0.1 + _random.nextDouble() * 0.6,
           )
         );
      }
      
      setState(() {
        _comments = loaded;
      });

    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }
  }

  Future<void> _handleNewComment(Map<String, dynamic> record) async {
    // We need to fetch the profile for this user to display avatar
    try {
       final userId = record['user_id'];
       final profileResponse = await Supabase.instance.client
           .from('profiles')
           .select()
           .eq('id', userId)
           .single();
       
       if (!mounted) return;
       
       final newComment = CommentModel(
         id: record['id'],
         message: record['message'],
         username: profileResponse['username'] ?? 'User',
         avatarUrl: profileResponse['avatar_url'],
         initialX: 0.1 + _random.nextDouble() * 0.7,
         initialY: 0.1 + _random.nextDouble() * 0.6,
       );

       setState(() {
         _comments.add(newComment);
       });
       
    } catch (e) {
      debugPrint('Error handling new comment: $e');
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    _replyFocusNode.unfocus();
    
    if (!_progressController.isAnimating) {
        _progressController.forward();
    }

    try {
      final story = _currentStories[_currentIndex];
      final user = Supabase.instance.client.auth.currentUser!;
      
      await Supabase.instance.client.from('story_replies').insert({
        'story_id': story.id,
        'user_id': user.id,
        'message': text,
      });
      // Logic above (_handleNewComment) will catch the Realtime event and add it to UI
      // So we don't double add here manually.
      
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
      _loadCommentsAndSubscribe(); 
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
      _loadCommentsAndSubscribe();
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
          _loadCommentsAndSubscribe();
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
      resizeToAvoidBottomInset: false, 
      body: GestureDetector(
        onTapUp: (details) {
          if (_replyFocusNode.hasFocus) {
            _replyFocusNode.unfocus();
            _progressController.forward(); 
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
                   return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                   child: Icon(Icons.error, color: Colors.white),
                ),
              ),
            ),

            // 2. Persistent Floating Comments Layer
            ..._comments.map((c) => PersistentFloatingComment(key: ValueKey(c.id), model: c)).toList(),

            // 3. UI Overlay
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
                right: 16, 
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _deleteStory(story),
                ),
              ),

             // Close Button
            Positioned(
              top: 55,
              right: story.userId == Supabase.instance.client.auth.currentUser?.id ? 56 : 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(_hasChanges),
              ),
            ),

            // 4. Glassmorphism Reply Input
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.black.withOpacity(0.2), // Darker glass
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                           // Add an Avatar here for current user? Maybe later.
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: TextField(
                                controller: _replyController,
                                focusNode: _replyFocusNode,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Send a floating message...',
                                  hintStyle: TextStyle(color: Colors.white70),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                                onTap: () => _progressController.stop(), 
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

class CommentModel {
  final String id;
  final String message;
  final String username;
  final String? avatarUrl;
  final double initialX; // Normalized 0..1
  final double initialY; // Normalized 0..1
  
  CommentModel({
    required this.id, 
    required this.message, 
    required this.username, 
    this.avatarUrl,
    required this.initialX,
    required this.initialY,
  });
}

class PersistentFloatingComment extends StatefulWidget {
  final CommentModel model;
  
  const PersistentFloatingComment({super.key, required this.model});

  @override
  State<PersistentFloatingComment> createState() => _PersistentFloatingCommentState();
}

class _PersistentFloatingCommentState extends State<PersistentFloatingComment> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final double _driftRange = 20.0; // Amount of pixels to drift

  @override
  void initState() {
    super.initState();
    // Drifting Animation: Slow sine wave loop
    _controller = AnimationController(
       vsync: this,
       duration: Duration(seconds: 3 + Random().nextInt(3)), // 3-6 seconds
    )..repeat(reverse: true);
    
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
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
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        // Base Position
        final baseX = widget.model.initialX * screenWidth;
        final baseY = widget.model.initialY * screenHeight;
        
        // Add Drift
        final dx = 0.0; // Keep horizontal steady for reading? Or slight drift
        final dy = _animation.value * _driftRange; // Move up and down gently

        return Positioned(
          left: baseX + dx,
          top: baseY + dy,
          child: child!,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), // Requested Glass Style
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                 CircleAvatar(
                   radius: 12,
                   backgroundImage: widget.model.avatarUrl != null 
                      ? NetworkImage(widget.model.avatarUrl!)
                      : null,
                   backgroundColor: Colors.white.withOpacity(0.3),
                   child: widget.model.avatarUrl == null 
                       ? const Icon(Icons.person, color: Colors.white, size: 14) 
                       : null,
                 ),
                 const SizedBox(width: 8),
                 Flexible(
                   child: Text(
                      widget.model.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 2)]
                      ),
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
