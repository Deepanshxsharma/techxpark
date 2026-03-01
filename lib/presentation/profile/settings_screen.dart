import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Toggle States
  bool _darkMode = false;
  bool _notifications = true;
  bool _biometric = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFF),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Settings", 
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 10),
          _buildSectionTitle("PREFERENCES"),
          _buildSettingsGroup([
            _buildSwitchTile(
              icon: Icons.dark_mode_outlined,
              title: "Dark Mode",
              value: _darkMode,
              onChanged: (val) => setState(() => _darkMode = val),
            ),
            _buildSwitchTile(
              icon: Icons.notifications_active_outlined,
              title: "Push Notifications",
              value: _notifications,
              onChanged: (val) => setState(() => _notifications = val),
            ),
          ]),
          
          const SizedBox(height: 30),
          _buildSectionTitle("SECURITY"),
          _buildSettingsGroup([
            _buildSwitchTile(
              icon: Icons.fingerprint_rounded,
              title: "Biometric Login",
              value: _biometric,
              onChanged: (val) => setState(() => _biometric = val),
            ),
            _buildActionTile(Icons.lock_outline_rounded, "Change Password"),
          ]),

          const SizedBox(height: 30),
          _buildSectionTitle("SUPPORT"),
          _buildSettingsGroup([
            _buildActionTile(Icons.help_outline_rounded, "Help Center"),
            _buildActionTile(Icons.privacy_tip_outlined, "Privacy Policy"),
            _buildActionTile(Icons.info_outline_rounded, "About TechXPark", isLast: true),
          ]),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
              "BUILD VERSION 1.0.0 (25)",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1)),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required bool value, required Function(bool) onChanged}) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: const Color(0xFF0081C9), size: 22),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          trailing: Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF0081C9),
            onChanged: (val) {
              HapticFeedback.lightImpact();
              onChanged(val);
            },
          ),
        ),
        Divider(height: 1, indent: 55, color: Colors.grey.shade50),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String title, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.grey.shade600, size: 22),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          onTap: () => HapticFeedback.lightImpact(),
        ),
        if (!isLast) Divider(height: 1, indent: 55, color: Colors.grey.shade50),
      ],
    );
  }
}