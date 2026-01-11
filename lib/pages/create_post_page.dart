import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _captionController = TextEditingController();
  Uint8List? _imageBytes; // Changed from File to Uint8List for Web support
  bool _isLoading = false;
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _uploadPost() async {
    if (_imageBytes == null) return;
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('DEBUG: User is not logged in.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in to post.')),
          );
          context.go('/login');
        }
        return;
      }

      final userId = user.id;
      final fileName = '${const Uuid().v4()}.jpg';
      final path = '$userId/$fileName';

      print('DEBUG: Starting upload (Web compatible mode)...');
      print('DEBUG: User ID: $userId');
      print('DEBUG: Path: $path');
      print('DEBUG: File size: ${_imageBytes!.length} bytes');

      // 1. Upload image to Supabase Storage using uploadBinary (Works on Web & Mobile)
      await supabase.storage.from('post').uploadBinary(
            path,
            _imageBytes!,
            fileOptions: const FileOptions(
                upsert: true, contentType: 'image/jpeg'), // Ensure content type
          );
      print('DEBUG: Upload successful');

      // 2. Get public URL
      final imageUrl = supabase.storage.from('post').getPublicUrl(path);
      print('DEBUG: Image URL: $imageUrl');

      // 3. Insert post metadata into Database
      await supabase.from('posts').insert({
        'user_id': userId,
        'image_url': imageUrl,
        'caption': _captionController.text,
      });
      print('DEBUG: Database insert successful');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created!')),
        );
        // Pop back to the previous screen (MainPage) which serves the Feed
        if (context.canPop()) {
           context.pop();
        } else {
           context.go('/feed');
        }
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error caught: $e');
      print('DEBUG: Stack trace: $stackTrace');
      
      String errorMessage = 'Error creating post: $e';
      if (e.toString().contains('posts_user_id_fkey')) {
        errorMessage = 'Profile missing. Please Sign Out and Sign Up again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          IconButton(
            onPressed: _isLoading || _imageBytes == null ? null : _uploadPost,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_imageBytes != null)
              Image.memory(_imageBytes!, height: 300, fit: BoxFit.cover)
            else
              Container(
                height: 200,
                color: Colors.grey[900], // Dark mode friendly placeholder
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt, size: 40, color: Colors.white),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.photo, size: 40, color: Colors.white),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: null,
            ),
          ],
        ),
      ),
    );
  }
}

