import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_clone/main.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final myUserId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('profiles')
          .select()
          .neq('id', myUserId); // Don't show myself
      
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error fetching users: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Users')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[800],
                    backgroundImage: user['avatar_url'] != null 
                        ? NetworkImage(user['avatar_url']) 
                        : null,
                    child: user['avatar_url'] == null 
                        ? const Icon(Icons.person, color: Colors.white) 
                        : null,
                  ),
                  title: Text(
                    user['username'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                  onTap: () {
                    // Navigate to Chat Page
                    context.push('/chat/${user['id']}');
                  },
                );
              },
            ),
    );
  }
}
