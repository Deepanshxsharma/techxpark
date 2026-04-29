import 'package:flutter/material.dart';

import '../messages/messages_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MessagesScreen(
      initialTab: InboxTab.notifications,
      showStandaloneNav: true,
    );
  }
}
