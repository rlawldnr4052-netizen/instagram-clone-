import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_clone/main.dart';
import 'package:instagram_clone/models/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatPage extends StatefulWidget {
  final String otherUserId;

  const ChatPage({super.key, required this.otherUserId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<Message>> _messagesStream;
  String? _otherUsername;
  String? _otherAvatarUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchOtherUserProfile();
    _setupMessageStream();
  }

  Future<void> _fetchOtherUserProfile() async {
    try {
      final myUserId = supabase.auth.currentUser!.id;

      // 1. Guard: Check for Mutual Follow
      final mutualCheck = await supabase
          .from('follows')
          .select()
          .or('and(follower_id.eq.$myUserId,following_id.eq.${widget.otherUserId}),and(follower_id.eq.${widget.otherUserId},following_id.eq.$myUserId)');
      
      // Must have 2 records (I follow them, They follow me)
      // Or we can query individually if RLS complicates .or()
      
      final iFollowThem = await supabase
          .from('follows')
          .count()
          .eq('follower_id', myUserId)
          .eq('following_id', widget.otherUserId);
      
      final theyFollowMe = await supabase
          .from('follows')
          .count()
          .eq('follower_id', widget.otherUserId)
          .eq('following_id', myUserId);

      if (iFollowThem == 0 || theyFollowMe == 0) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('You can only DM mutual followers!')),
           );
           context.go('/feed'); // Redirect to Feed
        }
        return;
      }

      // 2. Fetch Profile Checks out
      final data = await supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', widget.otherUserId)
          .single();
      if (mounted) {
        setState(() {
          _otherUsername = data['username'];
          _otherAvatarUrl = data['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching user or checking mutuals: $e');
      if (mounted) context.go('/feed');
    }
  }

  void _setupMessageStream() {
    final myUserId = supabase.auth.currentUser!.id;
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((maps) {
          final messages = maps.map((map) => Message.fromMap(map, myUserId)).toList();
          return messages.where((m) =>
            (m.senderId == myUserId && m.receiverId == widget.otherUserId) ||
            (m.senderId == widget.otherUserId && m.receiverId == myUserId)
          ).toList();
        });
  }

  // Scroll to bottom when new messages arrive
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100, // Add buffer
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final myUserId = supabase.auth.currentUser!.id;
      final fileName = 'chat_${const Uuid().v4()}.jpg';
      final path = 'chat_images/$fileName';

      // Upload
      await supabase.storage.from('chat_images').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final imageUrl = supabase.storage.from('chat_images').getPublicUrl(path);

      // Send Message with Image
      await supabase.from('messages').insert({
        'sender_id': myUserId,
        'receiver_id': widget.otherUserId,
        'content': '', // No text content
        'image_url': imageUrl,
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final myUserId = supabase.auth.currentUser!.id;
    _messageController.clear();

    try {
      await supabase.from('messages').insert({
        'sender_id': myUserId,
        'receiver_id': widget.otherUserId,
        'content': text,
        'image_url': null,
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: _otherAvatarUrl != null ? NetworkImage(_otherAvatarUrl!) : null,
              child: _otherAvatarUrl == null ? const Icon(Icons.person, size: 16) : null,
            ),
            const SizedBox(width: 10),
            Text(_otherUsername ?? 'Chat', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  // Hacky scroll to bottom on initial load
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('Say hello! 👋', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _ChatBubble(message: message);
                  },
                );
              },
            ),
          ),
          
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Colors.blue),
            ),

          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey[900]!)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Image Button
            GestureDetector(
              onTap: _pickAndSendImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            
            // Text Field
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),

            // Send Button (only show if typing? or always)
            GestureDetector(
              onTap: _sendMessage,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Send', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Message message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final hasImage = message.imageUrl != null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF3797F0) : const Color(0xFF262626), // Messenger Blue : Dark Grey
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                Image.network(
                  message.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: 200,
                      color: Colors.grey[900],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              if (message.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    message.content,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
