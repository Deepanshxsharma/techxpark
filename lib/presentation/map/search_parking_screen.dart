import 'package:techxpark/theme/app_colors.dart';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchParkingScreen extends StatefulWidget {
  const SearchParkingScreen({super.key});

  @override
  State<SearchParkingScreen> createState() => _SearchParkingScreenState();
}

class _SearchParkingScreenState extends State<SearchParkingScreen>
    with TickerProviderStateMixin {
  // -- Data --
  List<Map<String, dynamic>> _allLocations = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  // -- Controllers --
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _entryAnimController;
  late Animation<double> _entryFadeAnim;
  late Animation<Offset> _entrySlideAnim;

  // -- Design Tokens --
  static const Color _dark = Color(0xFF0F172A);
  static const Color _slate = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _blue = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entryFadeAnim = CurvedAnimation(
      parent: _entryAnimController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
    _entrySlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryAnimController,
            curve: Curves.easeOutCubic,
          ),
        );

    _loadLocations();
    // Short delay so the screen can mount before autofocusing
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('parking_locations')
          .get();
      final data = snap.docs.map((d) {
        final map = d.data();
        map['id'] = d.id;
        return map;
      }).toList();

      if (!mounted) return;
      setState(() {
        _allLocations = data;
        _filtered = data; // 🌟 Show ALL results immediately on open
        _loading = false;
      });
      _entryAnimController.forward();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filtered = _allLocations);
      return;
    }
    final q = query.toLowerCase().trim();
    setState(() {
      _filtered = _allLocations.where((loc) {
        final name = (loc['name'] ?? '').toString().toLowerCase();
        final addr = (loc['address'] ?? '').toString().toLowerCase();
        return name.contains(q) || addr.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _surface,
        body: Stack(
          children: [
            // -- Premium Gradient Background --
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF0F4FF), Color(0xFFF8FAFC)],
                  ),
                ),
              ),
            ),

            // -- Content --
            Column(
              children: [
                SizedBox(height: topPad),
                _buildSearchBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? _buildShimmer()
                      : _filtered.isEmpty
                      ? _buildEmptyState()
                      : _buildResultsList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── SEARCH BAR ────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            // Back button
            _PressableIcon(
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.pop(context),
            ),
            // Input
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                onChanged: _search,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _dark,
                  letterSpacing: -0.2,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search parking lots, areas...',
                  hintStyle: TextStyle(
                    color: Color(0xFFADB5BD),
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            // Clear button (appears only when text is present)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _searchCtrl.text.isNotEmpty
                  ? _PressableIcon(
                      key: const ValueKey('clear'),
                      icon: Icons.close_rounded,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _searchCtrl.clear();
                        _search('');
                      },
                    )
                  : const SizedBox(width: 16, key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RESULTS LIST ──────────────────────────────────────────────────
  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: _filtered.length,
      itemBuilder: (context, i) {
        return TweenAnimationBuilder<double>(
          key: ValueKey(_filtered[i]['id'] ?? i),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 60).clamp(0, 500)),
          curve: Curves.easeOutCubic,
          builder: (ctx, val, child) => Opacity(
            opacity: val,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - val)),
              child: child,
            ),
          ),
          child: _SearchResultCard(
            location: _filtered[i],
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context, {
                'lat': _filtered[i]['latitude'],
                'lng': _filtered[i]['longitude'],
              });
            },
          ),
        );
      },
    );
  }

  // ─── EMPTY STATE ───────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _entryFadeAnim,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _blue.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 52,
                color: const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No results found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different name or area',
              style: TextStyle(fontSize: 14, color: _slate.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHIMMER LOADING ───────────────────────────────────────────────
  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: 6,
      itemBuilder: (_, i) => _ShimmerCard(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🃏 Premium Search Result Card
// ─────────────────────────────────────────────────────────────────────────────
class _SearchResultCard extends StatefulWidget {
  final Map<String, dynamic> location;
  final VoidCallback onTap;
  const _SearchResultCard({required this.location, required this.onTap});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.location['name'] ?? 'Parking';
    final address = widget.location['address'] ?? '';
    final slots = widget.location['available_slots'];

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_parking_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                // Text info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (slots != null) ...[
                        const SizedBox(height: 6),
                        _SlotsChip(slots: slots),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🟢 Available Slots Chip
// ─────────────────────────────────────────────────────────────────────────────
class _SlotsChip extends StatelessWidget {
  final dynamic slots;
  const _SlotsChip({required this.slots});

  @override
  Widget build(BuildContext context) {
    final count = int.tryParse(slots.toString()) ?? 0;
    final available = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: available
            ? const Color(0xFF22C55E).withValues(alpha: 0.1)
            : const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        available ? '$count slots available' : 'Full',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: available ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ✨ Animated Press Icon Button
// ─────────────────────────────────────────────────────────────────────────────
class _PressableIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _PressableIcon({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_PressableIcon> createState() => _PressableIconState();
}

class _PressableIconState extends State<_PressableIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Icon(widget.icon, color: const Color(0xFF0F172A), size: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 💀 Shimmer Loading Card
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmer = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment(_shimmer.value - 1, 0),
                    end: Alignment(_shimmer.value + 1, 0),
                    colors: [
                      const Color(0xFFE2E8F0),
                      const Color(0xFFF1F5F9),
                      const Color(0xFFE2E8F0),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerLine(width: 0.6, shimmer: _shimmer),
                    const SizedBox(height: 8),
                    _ShimmerLine(width: 0.85, shimmer: _shimmer, height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  final double height;
  final Animation<double> shimmer;
  const _ShimmerLine({
    required this.width,
    required this.shimmer,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: width,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment(shimmer.value - 1, 0),
            end: Alignment(shimmer.value + 1, 0),
            colors: const [
              Color(0xFFE2E8F0),
              Color(0xFFF1F5F9),
              Color(0xFFE2E8F0),
            ],
          ),
        ),
      ),
    );
  }
}
