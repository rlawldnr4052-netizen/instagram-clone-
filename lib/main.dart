import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:instagram_clone/pages/login_page.dart';
import 'package:instagram_clone/pages/signup_page.dart';
import 'package:instagram_clone/pages/main_page.dart';
import 'package:instagram_clone/pages/create_post_page.dart';
import 'package:instagram_clone/pages/comments_page.dart';
import 'package:instagram_clone/pages/search_page.dart';
import 'package:instagram_clone/pages/profile_setup_page.dart';
import 'package:instagram_clone/pages/profile_page.dart';
import 'package:instagram_clone/pages/chat_page.dart';
import 'package:instagram_clone/pages/direct_messages_page.dart'; // Import


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lumsuaiybqvgcwhrszrw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1bXN1YWl5YnF2Z2N3aHJzenJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5NTg2ODQsImV4cCI6MjA4MzUzNDY4NH0.0zEUuSszizgpEbz_mzUz_HLfaWmCEOZlXz5up2JHlHA',
  );

  runApp(const ProviderScope(child: MyApp()));
}

final supabase = Supabase.instance.client;

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpPage(),
    ),
    GoRoute(
      path: '/feed',
      builder: (context, state) => const MainPage(),
    ),
    GoRoute(
      path: '/create_post',
      builder: (context, state) => const CreatePostPage(),
    ),
    GoRoute(
      path: '/comments/:postId',
      builder: (context, state) {
        final postId = state.pathParameters['postId']!;
        return CommentsPage(postId: postId);
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: '/setup-profile',
      builder: (context, state) => const ProfileSetupPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/profile/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return ProfilePage(userId: userId);
      },
    ),
    GoRoute(
      path: '/chat/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return ChatPage(otherUserId: userId);
      },
    ),
    GoRoute(
      path: '/direct',
      builder: (context, state) => const DirectMessagesPage(),
    ),
  ],
  redirect: (context, state) async {
    final session = supabase.auth.currentSession;
    final location = state.uri.toString();
    final isLoggingIn = location == '/login' || location == '/signup';
    final isSetupPage = location == '/setup-profile';

    // 1. Not Logged In -> Force Login
    if (session == null) {
      if (!isLoggingIn) return '/login';
      return null;
    }

    // 2. Logged In -> Strict Profile Check
    // We query the DB every time for safety. 
    try {
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', session.user.id)
          .maybeSingle();

      final username = profile?['username'] as String?;
      
      // Strict Validation Rules
      final isInvalid = 
          username == null || 
          username.isEmpty || 
          username.startsWith('user_') || 
          username == 'unknown';

      if (isInvalid) {
        // If profile is invalid, absolutely NO access to anything else
        if (!isSetupPage) return '/setup-profile';
        return null; // Stay on setup page
      }

      // 3. Profile Valid
      // If user is trying to go to setup page but is already valid, send to feed
      if (isSetupPage || isLoggingIn) return '/feed';

      // Allow access to requested page
      return null;

    } catch (e) {
      debugPrint('Redirect Error: $e');
      // On error (e.g. network), ideally show error or retry.
      // To prevent "open access" on error, we can default to staying put or setup.
      // But for usability, if network fails, we might just let them be or retry.
      // Let's enforce safety: if we can't verify, don't let them in.
      // However, to avoid blocking offline usage (not implemented yet), 
      // providing a fallback is tricky.
      // For this user: "Strictly Block".
      if (!isSetupPage) return '/setup-profile'; 
      // Explicitly allow direct messages
      if (location.startsWith('/direct')) return null;

      return null;
    }
  },
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fakegram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white,
          surface: Colors.black,
          background: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      routerConfig: _router,
    );
  }
}
