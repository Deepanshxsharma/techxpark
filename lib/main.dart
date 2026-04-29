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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
      statusBarIconBrightness: Brightness.light,
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

class _TechxParkAppState extends State<TechxParkApp>
    with WidgetsBindingObserver {
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
      builder: (_, mode, child) {
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
            '/messages': (context) =>
                const MessagesScreen(showStandaloneNav: true),
          },
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/* 🔤 SHARED POPPINS TYPOGRAPHY                                               */
/* -------------------------------------------------------------------------- */
TextTheme _poppinsTextTheme(Brightness brightness) {
  final baseTheme = ThemeData(brightness: brightness).textTheme;

  final isDark = brightness == Brightness.dark;
  final primaryTextColor = isDark
      ? AppColors.textPrimaryDark
      : AppColors.textPrimaryLight;
  final secondaryTextColor = isDark
      ? AppColors.textSecondaryDark
      : AppColors.textSecondaryLight;

  return baseTheme
      .apply(
        fontFamily: 'Poppins',
        bodyColor: primaryTextColor,
        displayColor: primaryTextColor,
      )
      .copyWith(
        headlineLarge: baseTheme.headlineLarge?.copyWith(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          color: primaryTextColor,
        ),
        headlineMedium: baseTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
        titleLarge: baseTheme.titleLarge?.copyWith(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
        titleMedium: baseTheme.titleMedium?.copyWith(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
        titleSmall: baseTheme.titleSmall?.copyWith(
          fontFamily: 'Poppins',
          color: secondaryTextColor,
        ),
        bodyLarge: baseTheme.bodyLarge?.copyWith(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w400,
          color: primaryTextColor,
        ),
        bodyMedium: baseTheme.bodyMedium?.copyWith(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w400,
          color: secondaryTextColor,
        ),
        bodySmall: baseTheme.bodySmall?.copyWith(
          fontFamily: 'Poppins',
          color: secondaryTextColor,
        ),
        labelLarge: baseTheme.labelLarge?.copyWith(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
        ),
      );
}

/* -------------------------------------------------------------------------- */
/* 🌤️ LIGHT THEME                                                             */
/* -------------------------------------------------------------------------- */
ThemeData _lightTheme() {
  final textTheme = _poppinsTextTheme(Brightness.light);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Poppins',
    textTheme: textTheme,
    primaryTextTheme: textTheme,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.success,
      surface: AppColors.surfaceLight,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.background,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.primary),
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 0,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: AppTextStyles.buttonText,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: const BorderSide(color: AppColors.border, width: 1.5),
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
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderLight),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      selectedLabelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(fontFamily: 'Poppins'),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.activeBlueLight,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textSecondary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontFamily: 'Poppins',
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textSecondary,
        );
      }),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
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
      hintStyle: AppTextStyles.body1.copyWith(color: AppColors.textSecondary),
      labelStyle: AppTextStyles.body2SemiBold.copyWith(
        color: AppColors.textSecondary,
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
  final textTheme = _poppinsTextTheme(Brightness.dark);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Poppins',
    textTheme: textTheme,
    primaryTextTheme: textTheme,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      secondary: AppColors.success,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.bgDark,

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: AppColors.primaryLight),
      titleTextStyle: AppTextStyles.h3Dark,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
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
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderDark),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: AppColors.textSecondaryDark,
      selectedLabelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(fontFamily: 'Poppins'),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      indicatorColor: AppColors.primary.withValues(alpha: 0.22),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryLight
              : AppColors.textSecondaryDark,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontFamily: 'Poppins',
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryLight
              : AppColors.textSecondaryDark,
        );
      }),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
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
