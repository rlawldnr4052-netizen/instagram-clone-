import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_clone/pages/feed_page.dart';
import 'package:instagram_clone/pages/create_post_page.dart';
import 'package:instagram_clone/pages/profile_page.dart';

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
    const CreatePostPage(), // Index 2: Upload
    const ProfilePage(), // Index 3: Profile
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // If "Upload" is tapped, push the CreatePostPage separately
      // so it has a full-screen feel and back button, or keeps the nav bar?
      // User said "Upload... in navigation bar".
      // Let's keep it simple: Just switch to the tab for now, or push.
      // Detailed user request: "(+) button ... select photo ... upload".
      // Let's Push it for better UX, or just show it.
      // Request said: "BottomNavigationBar ... (Home, Search, Upload, Profile)"
      // Let's behave like Instagram: + button pushes a new route or modal.
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}
