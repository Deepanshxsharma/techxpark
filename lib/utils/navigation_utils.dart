import 'package:flutter/material.dart';

/// Small set of safe navigation helpers to avoid crashes when
/// the widget tree was disposed or the navigation stack is empty.
/// These keep behaviour predictable and add lightweight debug logs.

Future<T?> safePush<T>(BuildContext context, Widget page) {
  if (!context.mounted) return Future.value(null);
  debugPrint('Navigating to: ${page.runtimeType}');
  return Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));
}

Future<T?> safePushReplacement<T, TO>(BuildContext context, Widget page) {
  if (!context.mounted) return Future.value(null);
  debugPrint('Replacing with: ${page.runtimeType}');
  return Navigator.pushReplacement<T, TO>(
    context,
    MaterialPageRoute(builder: (_) => page),
  );
}

Future<T?> safePushAndRemoveUntil<T>(BuildContext context, Widget page) {
  if (!context.mounted) return Future.value(null);
  debugPrint('Push and remove until: ${page.runtimeType}');
  return Navigator.of(context).pushAndRemoveUntil<T>(
    MaterialPageRoute(builder: (_) => page),
    (route) => false,
  );
}

void safeShowAuthState(BuildContext context) {
  if (!context.mounted) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/auth', (route) => false);
  });
}

void safePop(BuildContext context, [Object? result]) {
  if (!context.mounted) return;
  if (Navigator.canPop(context)) {
    debugPrint('Popping screen');
    Navigator.pop(context, result);
  } else {
    debugPrint('safePop: cannot pop, stack empty');
  }
}
