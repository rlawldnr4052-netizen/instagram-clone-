import 'package:flutter/material.dart';
import 'package:instagram_clone/main.dart';
import 'package:instagram_clone/models/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  final String otherUserId;

  const ChatPage({super.key, required this.otherUserId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  late final Stream<List<Message>> _messagesStream;

  @override
  void initState() {
    super.initState();
    final myUserId = supabase.auth.currentUser!.id;
    
    // Supabase Stream
    // We fetch all messages and filter client-side for this conversation
    // because standard stream() filters are limited for OR conditions.
    // RLS ensures we only get messages relevant to us.
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true) // Ensure correct order
        .map((maps) {
          final messages = maps.map((map) => Message.fromMap(map, myUserId)).toList();
          // Filter only messages between me and the other user
          return messages.where((m) => 
            (m.senderId == myUserId && m.receiverId == widget.otherUserId) ||
            (m.senderId == widget.otherUserId && m.receiverId == myUserId)
          ).toList();
        });
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
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return const Center(child: Text('Start a conversation!'));
                }

                return ListView.builder(
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
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? Colors.blue[700] : Colors.grey[800],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMine ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
