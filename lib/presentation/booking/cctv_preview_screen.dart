import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Full-screen mock CCTV live preview.
/// Uses animated gradients, scan lines, and a blinking LIVE badge
/// to simulate a realistic parking surveillance feed.
class CCTVPreviewScreen extends StatefulWidget {
  final String parkingName;
  final String slotId;
  final int floorIndex;

  const CCTVPreviewScreen({
    super.key,
    required this.parkingName,
    required this.slotId,
    required this.floorIndex,
  });

  @override
  State<CCTVPreviewScreen> createState() => _CCTVPreviewScreenState();
}

class _CCTVPreviewScreenState extends State<CCTVPreviewScreen>
    with TickerProviderStateMixin {
  // Camera selector
  int _selectedCamera = 0;
  static const _cameras = [
    'Camera 1 — Entrance',
    'Camera 2 — Exit Gate',
    'Camera 3 — Basement',
  ];

  // Animations
  late AnimationController _scanCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _scanAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  // Time
  late Timer _clockTimer;
  String _currentTime = '';

  // Mock status
  bool _isConnecting = true;
  bool _vehicleDetected = false;

  static const Color _liveRed = Color(0xFFFF3B30);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Scan line moving top to bottom
    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _scanAnim = Tween<double>(begin: -0.1, end: 1.1).animate(
        CurvedAnimation(parent: _scanCtrl, curve: Curves.linear));

    // Pulse for LIVE badge
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseCtrl);

    // Initial fade-in
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Clock
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    // Simulate connection
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _isConnecting = false);
        _fadeCtrl.forward();
      }
    });

    // Random "vehicle detected" mock event
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _vehicleDetected = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _vehicleDetected = false);
      });
    });
  }

  void _updateClock() {
    if (!mounted) return;
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  void _switchCamera(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _isConnecting = true;
      _selectedCamera = index;
    });
    _fadeCtrl.reset();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isConnecting = false);
        _fadeCtrl.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildCameraFeed()),
            _buildCameraSelector(),
            _buildSecurityBadges(),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  /* ── Top Bar ───────────────────────────────────────────────────────────── */
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_cameras[_selectedCamera],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text(widget.parkingName,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12)),
              ],
            ),
          ),
          // LIVE badge
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _liveRed.withOpacity(_pulseAnim.value * 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _liveRed.withOpacity(_pulseAnim.value)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _liveRed.withOpacity(_pulseAnim.value),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('LIVE',
                      style: TextStyle(
                          color: _liveRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ── Camera Feed (Mock) ────────────────────────────────────────────────── */
  Widget _buildCameraFeed() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4D6FFF).withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dark gradient background simulating camera ──────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF0A0A1A),
                      const Color(0xFF0D1B2A), _selectedCamera / 2.0)!,
                  Color.lerp(const Color(0xFF1A1A2E),
                      const Color(0xFF162447), _selectedCamera / 2.0)!,
                ],
              ),
            ),
          ),

          // ── Grid overlay for parking lot simulation ──────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: CustomPaint(painter: _ParkingGridPainter()),
          ),

          // ── Scan line ───────────────────────────────────────────────
          AnimatedBuilder(
            animation: _scanAnim,
            builder: (_, __) => Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height,
              child: Align(
                alignment: Alignment(0, -1 + 2 * _scanAnim.value),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Subtle noise texture ────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: Opacity(
              opacity: 0.03,
              child: Container(color: Colors.white),
            ),
          ),

          // ── Connecting overlay ───────────────────────────────────────
          if (_isConnecting)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                    SizedBox(height: 16),
                    Text('Connecting to camera...',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

          // ── Vehicle Detected overlay ────────────────────────────────
          if (_vehicleDetected && !_isConnecting)
            Positioned(
              left: 40,
              top: 60,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.greenAccent.withOpacity(0.1),
                ),
                child: const Text('🚗 Vehicle Detected',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),

          // ── Bottom overlays ─────────────────────────────────────────
          if (!_isConnecting)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timestamp
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_currentTime,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600)),
                  ),
                  // Connection status
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_rounded,
                            color: Colors.greenAccent, size: 12),
                        SizedBox(width: 4),
                        Text('Live • 1.2s',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /* ── Camera Selector ───────────────────────────────────────────────────── */
  Widget _buildCameraSelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _cameras.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isActive = i == _selectedCamera;
          return GestureDetector(
            onTap: () => _switchCamera(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF4D6FFF).withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isActive
                        ? const Color(0xFF4D6FFF)
                        : Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    color: isActive
                        ? const Color(0xFF4D6FFF)
                        : Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(_cameras[i].split(' — ').last,
                      style: TextStyle(
                          color: isActive
                              ? const Color(0xFF4D6FFF)
                              : Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /* ── Security Badges ───────────────────────────────────────────────────── */
  Widget _buildSecurityBadges() {
    const badges = [
      {'icon': Icons.shield_outlined, 'text': '24/7 Surveillance'},
      {'icon': Icons.psychology_outlined, 'text': 'AI Detection'},
      {'icon': Icons.person_outline, 'text': 'Staff On-Site'},
      {'icon': Icons.cloud_outlined, 'text': '30 Day Storage'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: badges.map((b) {
          return Expanded(
            child: Column(
              children: [
                Icon(b['icon'] as IconData,
                    color: Colors.white24, size: 18),
                const SizedBox(height: 4),
                Text(b['text'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /* ── Bottom Actions ────────────────────────────────────────────────────── */
  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Screenshot saved (mock)'),
                    backgroundColor: Color(0xFF00C853),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Screenshot',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showReportSheet();
              },
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: const Text('Report Activity',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _liveRed.withOpacity(0.15),
                foregroundColor: _liveRed,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Report Suspicious Activity',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Our security team will be notified immediately.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report submitted. Team notified.'),
                        backgroundColor: Color(0xFF00C853),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _liveRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Submit Report',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
/*  PARKING GRID PAINTER (simulates overhead parking lot view)               */
/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */
class _ParkingGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw parking grid lines
    const cols = 4;
    const rows = 6;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (int i = 0; i <= cols; i++) {
      canvas.drawLine(
          Offset(i * cellW, 0), Offset(i * cellW, size.height), paint);
    }
    for (int j = 0; j <= rows; j++) {
      canvas.drawLine(
          Offset(0, j * cellH), Offset(size.width, j * cellH), paint);
    }

    // Draw some "parked car" rectangles
    final carPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final rng = Random(42); // deterministic "random"
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (rng.nextDouble() > 0.5) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  c * cellW + 8, r * cellH + 6, cellW - 16, cellH - 12),
              const Radius.circular(4),
            ),
            carPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
