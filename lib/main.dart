import 'package:flutter/material.dart';
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
import 'theme/theme_controller.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
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
  debugPrint('📬 Background FCM: ${message.notification?.title}');
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  debugPrint('🚀 App starting...');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ Flutter binding initialized');

  // Register background handler BEFORE Firebase.initializeApp
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase init error: $e');
  }

  // Load theme (fast, local SharedPreferences only)
  await ThemeController.loadTheme();
  debugPrint('✅ Theme loaded');

  // ✅ Initialize notification system — wrapped in try-catch to prevent crash
  NotificationService.navigatorKey = navigatorKey;
  try {
    await NotificationService.instance.init();
    debugPrint('✅ Notifications initialized');
  } catch (e) {
    debugPrint('⚠️ Notification init error (non-fatal): $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  debugPrint('✅ Running app...');
  runApp(const TechxParkApp());
}

/* -------------------------------------------------------------------------- */
/* 🧠 ROOT APP (STATEFUL – IMPORTANT FOR RELEASE)                              */
/* -------------------------------------------------------------------------- */
class TechxParkApp extends StatefulWidget {
  const TechxParkApp({super.key});

  @override
  State<TechxParkApp> createState() => _TechxParkAppState();
}

class _TechxParkAppState extends State<TechxParkApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ IMPORTANT: Firebase listeners must start AFTER UI is mounted
      startSensorSync();
      // Re-save FCM token after UI ready (ensures user is logged in)
      NotificationService.instance.saveTokenToFirestore();

      // 🚀 Run migration in background — NEVER block UI thread
      // This is safe to run async; it's idempotent and won't affect the user.
      MigrationService.runMigration().catchError((e) {
        debugPrint('⚠️ Migration error (non-fatal): $e');
      });
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
      builder: (_, mode, __) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'TechXPark',
          themeMode: mode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: const AuthWrapper(),
          routes: {
            '/notifications': (context) => const NotificationsScreen(),
            '/my_bookings': (context) => const MyBookingsScreen(),
            '/dashboard': (context) => const MainShell(),
            '/active_parking': (context) =>
                const MainShell(initialIndex: 2), // fallback to bookings
            '/slot_selection': (context) =>
                const MainShell(initialIndex: 2), // Bookings tab
            '/messages': (context) => const MessagesScreen(),
          },
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/* 🌤️ LIGHT THEME                                                             */
/* -------------------------------------------------------------------------- */
ThemeData _lightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.success,
      surface: AppColors.surfaceLight,
      background: AppColors.bgLight,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.bgLight,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
      titleTextStyle: AppTextStyles.h2,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 0,
        shadowColor: AppColors.primary.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: AppTextStyles.buttonText,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: const BorderSide(color: AppColors.borderLight, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: AppTextStyles.buttonText.copyWith(color: AppColors.primary),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTextStyles.textButton,
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.surfaceLight,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimaryLight,
      contentTextStyle: AppTextStyles.body2.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBgLight,
      hintStyle: AppTextStyles.body1.copyWith(
        color: AppColors.textSecondaryLight,
      ),
      labelStyle: AppTextStyles.body2SemiBold.copyWith(
        color: AppColors.textSecondaryLight,
      ),
      floatingLabelStyle: AppTextStyles.captionBold.copyWith(
        color: AppColors.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    ),
  );
}

/* -------------------------------------------------------------------------- */
/* 🌑 DARK THEME                                                              */
/* -------------------------------------------------------------------------- */
ThemeData _darkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      secondary: AppColors.success,
      surface: AppColors.surfaceDark,
      background: AppColors.bgDark,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.bgDark,

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      titleTextStyle: AppTextStyles.h2Dark,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: AppTextStyles.buttonText,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: const BorderSide(color: AppColors.borderDark, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: AppTextStyles.buttonText.copyWith(
          color: AppColors.primaryLight,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        textStyle: AppTextStyles.textButton,
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderDark),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      contentTextStyle: AppTextStyles.body2Dark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBgDark,
      hintStyle: AppTextStyles.body1Dark.copyWith(
        color: AppColors.textSecondaryDark,
      ),
      labelStyle: AppTextStyles.body2SemiBoldDark.copyWith(
        color: AppColors.textSecondaryDark,
      ),
      floatingLabelStyle: AppTextStyles.captionBoldDark.copyWith(
        color: AppColors.primaryLight,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    ),
  );
}
