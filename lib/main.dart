import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'presentation/auth/auth_wrapper.dart';
import 'services/notification_service.dart';
import 'services/migration_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'presentation/booking/my_bookings_screen.dart';

import 'widgets/main_shell.dart';
import 'presentation/messages/messages_screen.dart';
import 'presentation/notifications/notifications_screen.dart';

/* -------------------------------------------------------------------------- */
/* 🔥 LIVE SENSOR → FIRESTORE SYNC (SAFE – RELEASE READY)                      */
/* -------------------------------------------------------------------------- */
void startSensorSync() {
  FirebaseDatabase.instance
      .ref("sensor_slots/F1A04/taken")
      .onValue
      .listen(
        (event) async {
          try {
            final rawValue = event.snapshot.value;
            bool taken = false;

            if (rawValue is bool) {
              taken = rawValue;
            } else if (rawValue is Map) {
              taken = rawValue['taken'] == true;
            }

            await FirebaseFirestore.instance
                .collection("parking_locations")
                .doc("gardenia_apartment_parking")
                .collection("slots")
                .doc("F1A04")
                .update({
                  "taken": taken,
                  "last_updated": FieldValue.serverTimestamp(),
                });
          } catch (e) {
            debugPrint("⚠️ Sensor Sync Error: $e");
          }
        },
        onError: (error) {
          debugPrint("❌ Database Listen Error: $error");
        },
      );
}

/* -------------------------------------------------------------------------- */
/* 🚀 APP ENTRY POINT                                                         */
/* -------------------------------------------------------------------------- */
// 🔔 Background FCM handler — Must be registered before Firebase.initializeApp
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase may already be initialized in this isolate.
  }
  debugPrint('📬 Background FCM: ${message.notification?.title}');
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _installProductionGuards() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (!kReleaseMode) {
      debugPrintStack(
        label: details.exceptionAsString(),
        stackTrace: details.stack,
      );
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (!kReleaseMode) {
      debugPrint('Uncaught async error: $error');
      debugPrintStack(stackTrace: stack);
    }
    return true;
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installProductionGuards();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!kReleaseMode) {
      return ErrorWidget(details.exception);
    }
    return const _RecoverableErrorScreen();
  };

  runZonedGuarded(
    () async {
      debugPrint('🚀 App starting...');
      debugPrint('✅ Flutter binding initialized');

      // Register background handler BEFORE Firebase.initializeApp
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        debugPrint('✅ Firebase initialized');
      } catch (e, stack) {
        debugPrint('❌ Firebase init error: $e');
        if (!kReleaseMode) {
          debugPrintStack(stackTrace: stack);
        }
        runApp(_StartupFailureApp(error: e));
        return;
      }

      // Load theme (fast, local SharedPreferences only)
      await ThemeController.loadTheme();
      debugPrint('✅ Theme loaded');

      // ✅ Set notification navigator key (actual init happens after UI mounts)
      NotificationService.navigatorKey = navigatorKey;

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Color(0x00000000),
          statusBarIconBrightness: Brightness.light,
        ),
      );

      debugPrint('✅ Running app...');
      runApp(const TechxParkApp());
    },
    (error, stack) {
      if (!kReleaseMode) {
        debugPrint('Uncaught zoned error: $error');
        debugPrintStack(stackTrace: stack);
      }
    },
  );
}

/* -------------------------------------------------------------------------- */
/* 🧠 ROOT APP (STATEFUL – IMPORTANT FOR RELEASE)                              */
/* -------------------------------------------------------------------------- */
class TechxParkApp extends StatefulWidget {
  const TechxParkApp({super.key});

  @override
  State<TechxParkApp> createState() => _TechxParkAppState();
}

class _StartupFailureApp extends StatelessWidget {
  final Object error;

  const _StartupFailureApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: AppTheme.primary,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TechXPark could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your connection and reopen the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Color(0xFF62667A),
                    ),
                  ),
                  if (!kReleaseMode) ...[
                    const SizedBox(height: 16),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoverableErrorScreen extends StatelessWidget {
  const _RecoverableErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFFF8F9FF),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something went wrong. Please go back and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
    );
  }
}

class _TechxParkAppState extends State<TechxParkApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Development-only data repair/listener tasks must not run on customer
      // devices in release builds.
      if (!kReleaseMode) {
        startSensorSync();
      }

      // ✅ Initialize notification system — non-blocking, with timeout
      NotificationService.instance
          .init()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              debugPrint('⚠️ Notification init timed out (non-fatal)');
            },
          )
          .then((_) {
            debugPrint('✅ Notifications initialized');
          })
          .catchError((e) {
            debugPrint('⚠️ Notification init error (non-fatal): $e');
          });

      // Re-save FCM token after UI ready (ensures user is logged in)
      NotificationService.instance.saveTokenToFirestore().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ FCM token save timed out (non-fatal)');
        },
      );

      if (!kReleaseMode) {
        MigrationService.runMigration().catchError((e) {
          debugPrint('⚠️ Migration error (non-fatal): $e');
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isOnline = state == AppLifecycleState.resumed;
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (_, mode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'TechXPark',
          themeMode: ThemeMode.light,
          theme: AppTheme.lightTheme,
          home: const AuthWrapper(),
          routes: {
            '/auth': (context) => const AuthWrapper(),
            '/notifications': (context) => const NotificationsScreen(),
            '/my_bookings': (context) => const MyBookingsScreen(),
            '/dashboard': (context) => const MainShell(),
            '/active_parking': (context) =>
                const MainShell(initialIndex: 2), // fallback to bookings
            '/slot_selection': (context) =>
                const MainShell(initialIndex: 2), // Bookings tab
            '/messages': (context) =>
                const MessagesScreen(showStandaloneNav: true),
          },
        );
      },
    );
  }
}
