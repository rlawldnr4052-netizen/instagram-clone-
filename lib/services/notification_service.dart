import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // For BackdropFilter

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize(BuildContext context) async {
    // 1. Request Permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[FCM_READY] Permission Granted');
      
      // 2. Get Token
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM_READY] Token: $token');
        await _saveTokenToSupabase(token);
      } else {
        debugPrint('[FCM_ERROR] Token is null');
      }
      
      // 3. Listen for Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          _showGlassOverlay(context, message.notification!.title, message.notification!.body);
        }
      });
      
      // 4. Check if token is actually in DB (Verification)
      _verifyTokenInDb(token);

    } else {
      debugPrint('[FCM_ERROR] Permission Denied or Not Accepted: ${settings.authorizationStatus}');
      // Show snackbar instructing to enable
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: const Text('알림을 켜야 서비스를 제대로 이용할 수 있습니다'),
             action: SnackBarAction(label: '설정', onPressed: () {
               // Future: open settings
             }),
           ),
         );
      }
    }
  }

  Future<void> _verifyTokenInDb(String? currentToken) async {
    if (currentToken == null) return;
    try {
       final user = Supabase.instance.client.auth.currentUser;
       if (user == null) return;
       final data = await Supabase.instance.client
           .from('profiles')
           .select('fcm_token')
           .eq('id', user.id)
           .maybeSingle();
       
       if (data == null || data['fcm_token'] != currentToken) {
         debugPrint('Token mismatch or missing in DB. Updating...');
         await _saveTokenToSupabase(currentToken);
       }
    } catch (e) {
      debugPrint('Error verifying token: $e');
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('profiles').update({
        'fcm_token': token,
      }).eq('id', user.id);
      debugPrint('FCM Token saved to Supabase');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  void _showGlassOverlay(BuildContext context, String? title, String? body) {
    if (title == null && body == null) return;
    
    // Using OverlayEntry to show on top of everything
    final overlayState = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                         padding: const EdgeInsets.all(8),
                         decoration: const BoxDecoration(
                           color: Colors.white,
                           shape: BoxShape.circle,
                         ),
                         child: const Icon(Icons.notifications_active, color: Colors.pink, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null)
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            if (body != null)
                              Text(
                                body,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);

    // Remove after 3 seconds
    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry.remove();
    });
  }
}
