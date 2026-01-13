import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // For Ticker
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
  late AnimationController _storyProgressController;
  late List<Story> _currentStories;
  
  // Real-time & Physics Logic
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  RealtimeChannel? _subscription;
  
  // Physics Engine State
  List<PhysicsCommentObject> _physicsObjects = [];
  Ticker? _physicsTicker;
  final Random _random = Random();
  Size? _screenSize;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentStories = List.from(widget.stories);
    _setupAnimation();
    
    // Start Physics Engine
    _physicsTicker = createTicker(_updatePhysics)..start();
    
    // Load Data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenSize = MediaQuery.of(context).size;
      _loadCommentsAndSubscribe();
    });
  }

  void _setupAnimation() {
    _storyProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {}); // Repaint linear progress
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    
    _storyProgressController.forward();
  }

  // --- Physics Engine Loop ---
  void _updatePhysics(Duration elapsed) {
    if (_screenSize == null || _physicsObjects.isEmpty) return;

    final width = _screenSize!.width;
    final height = _screenSize!.height;
    
    // 1. Move & Rotate
    for (var obj in _physicsObjects) {
      obj.x += obj.vx;
      obj.y += obj.vy;
      obj.angle += obj.angularVelocity;
      
      // Wall Collision (Elastic)
      // Check boundaries taking strict radius into account
      // Margin to keep inside screen roughly
      final radius = 40.0; // Approximation of half-width
      
      if (obj.x < radius) {
        obj.x = radius;
        obj.vx = -obj.vx; 
      } else if (obj.x > width - radius) {
        obj.x = width - radius;
        obj.vx = -obj.vx;
      }
      
      if (obj.y < radius) {
        obj.y = radius;
        obj.vy = -obj.vy;
      } else if (obj.y > height - 150) { // Keep above input bar area roughly
        obj.y = height - 150;
        obj.vy = -obj.vy;
      }
    }

    // 2. Object-Object Collision
    // Simple O(N^2) check is fine for < 50 items
    for (int i = 0; i < _physicsObjects.length; i++) {
      for (int j = i + 1; j < _physicsObjects.length; j++) {
        _resolveCollision(_physicsObjects[i], _physicsObjects[j]);
      }
    }

    setState(() {}); // Trigger repaint of objects
  }

  void _resolveCollision(PhysicsCommentObject a, PhysicsCommentObject b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final distance = sqrt(dx*dx + dy*dy);
    final minDistance = 80.0; // Assume diameter ~80

    if (distance < minDistance) {
      // Collision detected!
      // Calculate normalized collision vector
      final nx = dx / distance;
      final ny = dy / distance;

      // Swap velocity components along the normal (perfect elastic collision for equal mass)
      // v' = v - 2 * (v . n) * n  <-- Reflection formula
      // But simpler for equal mass 1D collision along normal is just swap.
      // Let's do simple bounce separation first
      
      // Separate them to avoid sticking
      final overlap = minDistance - distance;
      final moveX = nx * overlap * 0.5;
      final moveY = ny * overlap * 0.5;
      
      a.x -= moveX;
      a.y -= moveY;
      b.x += moveX;
      b.y += moveY;

      // Exchange momentum
      // Approximate: Swap velocities? Or partial reflection?
      // Let's add some "chaos" (random spin change on hit)
      
      final tempVx = a.vx;
      final tempVy = a.vy;
      a.vx = b.vx;
      a.vy = b.vy;
      b.vx = tempVx;
      b.vy = tempVy;
      
      // Sparkle Spin
      a.angularVelocity = (a.angularVelocity + (_random.nextDouble() - 0.5) * 0.1).clamp(-0.2, 0.2);
      b.angularVelocity = (b.angularVelocity + (_random.nextDouble() - 0.5) * 0.1).clamp(-0.2, 0.2);
    }
  }

  // --- Data Logic ---
  void _loadCommentsAndSubscribe() {
    if (_currentStories.isEmpty) return;
    final storyId = _currentStories[_currentIndex].id;
    
    // Clear Physics World
    _physicsObjects.clear();

    // Fetch & Subscribe
    _fetchExistingComments(storyId);
    
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
          .select('*, profiles(*)')
          .eq('story_id', storyId);
      
      final data = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;
      
      for (var item in data) {
         final profile = item['profiles'] ?? {};
         _spawnObject(
             id: item['id'],
             message: item['message'],
             username: profile['username'] ?? 'User',
             avatarUrl: profile['avatar_url']
         );
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }
  }

  Future<void> _handleNewComment(Map<String, dynamic> record) async {
    try {
       final userId = record['user_id'];
       final profileResponse = await Supabase.instance.client
           .from('profiles')
           .select()
           .eq('id', userId)
           .single();
       
       if (!mounted) return;
       
       _spawnObject(
         id: record['id'],
         message: record['message'],
         username: profileResponse['username'] ?? 'User',
         avatarUrl: profileResponse['avatar_url'],
       );
       
    } catch (e) {
      debugPrint('Error handling new comment: $e');
    }
  }
  
  void _spawnObject({required String id, required String message, required String username, String? avatarUrl}) {
    if (_screenSize == null) return;
    
    // Random Start Position
    final x = _random.nextDouble() * (_screenSize!.width - 100) + 50;
    final y = _random.nextDouble() * (_screenSize!.height / 2) + 100;
    
    // Random Fast Velocity
    final vx = (_random.nextDouble() - 0.5) * 4.0; // Speed factor
    final vy = (_random.nextDouble() - 0.5) * 4.0;
    
    // Random Rotation
    final angle = _random.nextDouble() * pi * 2;
    final angularVelocity = (_random.nextDouble() - 0.5) * 0.05;

    final obj = PhysicsCommentObject(
      id: id,
      message: message,
      username: username,
      avatarUrl: avatarUrl,
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      angle: angle,
      angularVelocity: angularVelocity,
    );
    
    setState(() {
      _physicsObjects.add(obj);
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    _replyFocusNode.unfocus();
    
    if (!_storyProgressController.isAnimating) {
        _storyProgressController.forward();
    }

    try {
      final story = _currentStories[_currentIndex];
      final user = Supabase.instance.client.auth.currentUser!;
      
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
        _storyProgressController.reset();
        _storyProgressController.forward();
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
        _storyProgressController.reset();
        _storyProgressController.forward();
      });
      _loadCommentsAndSubscribe();
    } else {
      _storyProgressController.reset();
      _storyProgressController.forward();
    }
  }
  
  Future<void> _deleteStory(Story story) async {
    _storyProgressController.stop();
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
          _storyProgressController.reset();
          _storyProgressController.forward();
          _loadCommentsAndSubscribe();
        }
      });
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }

  @override
  void dispose() {
    _physicsTicker?.dispose();
    _storyProgressController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }
  
  String _timeAgo(DateTime dateTime) {
    // Simplified time ago
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
             _storyProgressController.forward();
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
            // 1. Image
            Positioned.fill(
              child: Image.network(story.imageUrl, fit: BoxFit.contain),
            ),

            // 2. Physics Objects
            ..._physicsObjects.map((obj) => Positioned(
               left: obj.x - 60, // Centers assuming ~120 width
               top: obj.y - 25,  // Centers assuming ~50 height
               child: Transform.rotate(
                 angle: obj.angle,
                 child: _buildGlassComment(obj),
               ),
            )).toList(),

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
                            ? _storyProgressController.value 
                            : (entry.key < _currentIndex ? 1.0 : 0.0),
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
             // Close Button
            Positioned(
              top: 55,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(_hasChanges),
              ),
            ),
            
             if (story.userId == Supabase.instance.client.auth.currentUser?.id)
              Positioned(
                top: 55,
                left: 16, // Moved to right for consistency or keep left if intended
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _deleteStory(story),
                ),
              ),


            // 4. Input
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 0, 
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.black.withOpacity(0.2),
                    child: SafeArea(
                       top: false,
                       child: Row(
                         children: [
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
                                    hintText: 'Zero-G Message...',
                                    hintStyle: TextStyle(color: Colors.white70),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  ),
                                  onTap: () => _storyProgressController.stop(),
                                  onSubmitted: (_) => _sendReply(),
                                ),
                              ),
                           ),
                           const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _sendReply,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
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

  Widget _buildGlassComment(PhysicsCommentObject obj) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               CircleAvatar(
                 radius: 10,
                 backgroundImage: obj.avatarUrl != null ? NetworkImage(obj.avatarUrl!) : null,
                 backgroundColor: Colors.white.withOpacity(0.3),
                 child: obj.avatarUrl == null ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
               ),
               const SizedBox(width: 6),
               Flexible(
                  child: Text(
                    obj.message,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
               ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhysicsCommentObject {
  final String id;
  final String message;
  final String username;
  final String? avatarUrl;
  
  double x;
  double y;
  double vx; // X Velocity
  double vy; // Y Velocity
  double angle;
  double angularVelocity;

  PhysicsCommentObject({
    required this.id,
    required this.message,
    required this.username,
    this.avatarUrl,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angle,
    required this.angularVelocity,
  });
}
