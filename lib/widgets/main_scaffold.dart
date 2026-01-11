import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        context.go('/feed');
        break;
      case 1:
        // TODO: Implement Search
        // context.go('/search');
        break;
      case 2:
        context.push('/create_post');
        // Reset index to 0 or keep it? 
        // Typically upload is a modal or separate screen, not a tab.
        // But requested as a tab. Let's keep it 0 for now as push doesn't change tab state effectively.
        // Or we can simple go back to feed after push returns.
        setState(() => _selectedIndex = 0);
        break;
      case 3:
        // TODO: Implement Profile
        // context.go('/profile');
        break;
    }
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/feed')) return 0;
    if (location.startsWith('/search')) return 1;
    // Upload is usually not a persisted tab
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
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
        currentIndex: _calculateSelectedIndex(context),
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
