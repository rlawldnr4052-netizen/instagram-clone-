import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_clone/pages/feed_page.dart';
import 'package:instagram_clone/pages/create_post_page.dart';
import 'package:instagram_clone/pages/profile_page.dart'; 
import 'package:instagram_clone/widgets/glass_button.dart';
import 'package:google_fonts/google_fonts.dart';

// Key to access FeedPage state for refresh
final GlobalKey<FeedPageState> feedKey = GlobalKey<FeedPageState>();

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

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
    // Pages for each tab
    final List<Widget> pages = [
       FeedPage(key: feedKey), // Index 0: Home
       const Center(child: Text('Search Page', style: TextStyle(color: Colors.white))), // Index 1: Search
       const CreatePostPage(), // Index 2: Upload (Placeholder)
       const ProfilePage(), // Index 3: Profile
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Content Layer
          IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),

          // 2. Top Floating Bar (Logo & DM) - Only on Feed
          if (_selectedIndex == 0)
             Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   // Logo Box with Refresh
                   GestureDetector(
                     onTap: () {
                       // Trigger Scroll to Top & Refresh
                       final state = feedKey.currentState;
                       if (state != null) {
                         // We made the method public but the class is private _FeedPageState.
                         // Dynamic dispatch allows calling it if we suppress/ignore or cast.
                         // But better to just expose the State class.
                         // I will handle this in the next tool call by making FeedPageState public.
                         (state as dynamic).scrollToTopAndRefresh();
                       }
                     },
                     child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Fakegram',
                                  style: GoogleFonts.lobster(
                                    fontSize: 22,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.circle, size: 8, color: Colors.pinkAccent),
                              ],
                            ),
                          ),
                        ),
                     ),
                   ),

                   // DM Button (Pink Plane)
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
                      // 1. Home
                      _buildIcon(Icons.home, 0),
                      // 2. Search
                      _buildIcon(Icons.search, 1),
                      // 3. Add (Center)
                      _buildAddButton(),
                      // 4. Heart (Activity) - Navigates to /activity
                      GlassButton(
                        icon: Icons.favorite_border,
                        size: 40,
                        isSelected: false,
                        onTap: () => context.push('/activity'),
                      ),
                      // 5. Profile
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
  
  // ... _buildAddButton and _onItemTapped ...

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
