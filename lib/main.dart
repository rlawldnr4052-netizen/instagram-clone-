import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:instagram_clone/firebase_options.dart';
import 'package:instagram_clone/services/notification_service.dart';

import 'package:instagram_clone/pages/login_page.dart';
import 'package:instagram_clone/pages/signup_page.dart';
import 'package:instagram_clone/pages/main_page.dart';
import 'package:instagram_clone/pages/create_post_page.dart';
import 'package:instagram_clone/pages/comments_page.dart';
import 'package:instagram_clone/pages/search_page.dart';
import 'package:instagram_clone/pages/profile_setup_page.dart';
import 'package:instagram_clone/pages/profile_page.dart';
import 'package:instagram_clone/pages/chat_page.dart';
import 'package:instagram_clone/pages/direct_messages_page.dart';
import 'package:instagram_clone/pages/activity_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lumsuaiybqvgcwhrszrw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1bXN1YWl5YnF2Z2N3aHJzenJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5NTg2ODQsImV4cCI6MjA4MzUzNDY4NH0.0zEUuSszizgpEbz_mzUz_HLfaWmCEOZlXz5up2JHlHA',
  );
  
  try {
    // Expect user to have configured this using CLI or manual file
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase Initialization Error: $e');
  }

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
      name: 'feed',
      builder: (context, state) => const MainPage(),
    ),
    GoRoute(
      path: '/activity',
      name: 'activity',
      builder: (context, state) => const ActivityPage(),
    ),
    GoRoute(
      path: '/direct',
      name: 'direct',
      builder: (context, state) => const DirectMessagesPage(),
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
  ],
  redirect: (context, state) async {
    final session = supabase.auth.currentSession;
    final location = state.uri.toString();
    final isLoggingIn = location == '/login' || location == '/signup';
    final isSetupPage = location == '/setup-profile';

    if (session == null) {
      if (!isLoggingIn) return '/login';
      return null;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', session.user.id)
          .maybeSingle();

      final username = profile?['username'] as String?;
      
      final isInvalid = 
          username == null || 
          username.isEmpty || 
          username.startsWith('user_') || 
          username == 'unknown';

      if (isInvalid) {
        if (!isSetupPage) return '/setup-profile';
        return null; 
      }

      if (isSetupPage || isLoggingIn) return '/feed';
      return null;

    } catch (e) {
      debugPrint('Redirect Error: $e');
      if (!isSetupPage) return '/setup-profile'; 
      if (location.startsWith('/direct')) return null;
      return null;
    }
  },
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  @override
  void initState() {
    super.initState();
    // Initialize Notification Logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize(context);
    });
  }

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
