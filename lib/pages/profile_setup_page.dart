import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _usernameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  Uint8List? _avatarBytes;
  bool _isLoading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    // Potentially load existing data here if needed
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
      });
    }
  }

  Future<void> _completeSetup() async {
    final username = _usernameController.text.trim();
    
    // Validation
    if (username.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a username')));
      return;
    }
    if (username.length < 3) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username must be at least 3 characters')));
      return;
    }
    if (username.startsWith('user_') || username == 'unknown') {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a valid username')));
       return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      String? avatarUrl;

      // 1. Upload Avatar
      if (_avatarBytes != null) {
        final fileName = 'avatar_${const Uuid().v4()}.jpg';
        final path = '$userId/$fileName';
        await supabase.storage.from('avatars').uploadBinary(
              path,
              _avatarBytes!,
              fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
            );
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(path);
      }

      // 2. Update Profile & Job Title
      final jobTitle = _jobTitleController.text.trim();
      
      await supabase.from('profiles').update({
        'username': username,
        'job_title': jobTitle.isNotEmpty ? jobTitle : null,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        context.go('/feed'); // Redirect Logic in main.dart will verify this
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                   CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[800],
                    backgroundImage:
                        _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                    child: _avatarBytes == null
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.add_a_photo, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Set a profile picture', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            
            // Username
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter a unique username',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[800]!)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                filled: true,
                fillColor: Colors.grey[900],
                prefixIcon: const Icon(Icons.alternate_email, color: Colors.grey),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),

            // Job Title
            TextField(
              controller: _jobTitleController,
              decoration: InputDecoration(
                labelText: 'Job Title',
                hintText: 'e.g. AI Creator',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[800]!)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                filled: true,
                fillColor: Colors.grey[900],
                prefixIcon: const Icon(Icons.work_outline, color: Colors.grey),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _completeSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
