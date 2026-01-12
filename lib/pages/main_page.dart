import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_clone/pages/feed_page.dart';
import 'package:instagram_clone/pages/create_post_page.dart';
import 'package:instagram_clone/pages/profile_page.dart'; // Ensure this matches actual file
import 'package:instagram_clone/widgets/glass_button.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // Pages for each tab
  final List<Widget> _pages = [
    const FeedPage(), // Index 0: Home
    const Center(child: Text('Search Page', style: TextStyle(color: Colors.white))), // Index 1: Search
    const CreatePostPage(), // Index 2: Upload (Placeholder, actually used for padding/logic)
    const ProfilePage(), // Index 3: Profile
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      context.push('/create_post');
      return; 
    }
    
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Content Layer
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),

          // 2. Top Right Floating Buttons (Only on Feed)
          if (_selectedIndex == 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassButton(
                    icon: Icons.favorite_border,
                    onTap: () => context.push('/activity'),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    icon: Icons.send_rounded,
                    color: Colors.pinkAccent,
                    onTap: () => context.goNamed('direct'),
                  ),
                ],
              ),
            ),

          // 3. Bottom Floating Glass Bar
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildIcon(Icons.home, 0),
                      _buildIcon(Icons.search, 1),
                      _buildAddButton(),
                      _buildIcon(Icons.favorite, 999), // Placeholder logic if Heart is needed in bottom? 
                      // User said: "Bottom: Home, Search, +, Heart(Notification), Profile".
                      // Wait, "Heart" is also on Top Right? 
                      // User said: "Upper right: Heart icon, Pink paper airplane... Lower: Home, Search, +, Heart(notification), Profile".
                      // Okay, I will put Heart in both places as requested, or maybe the bottom one is "Activity" and top is "Likes"? 
                      // Usually Instagram has Heart at top. User asked for both. 
                      // I'll assume Bottom Heart is Activity too.
                      // Let's us index 4 for Heart if it was a page, but Heart is /activity.
                      
                      // Actually, if I click Heart in bottom, do I switch tab or push?
                      // Standard is usually tab. But /activity is a pushed page.
                      // I'll make the bottom heart push /activity for now, same as top.
                      GlassButton(
                        icon: Icons.favorite_border,
                        size: 40,
                        isSelected: false,
                        onTap: () => context.push('/activity'),
                      ),
                      
                      _buildIcon(Icons.person, 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white, // Always white
          size: 28,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}
