import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_lang.dart';

class ShopPage extends StatelessWidget {
  final AppLang lang;
  final int gold;
  final bool xpBarGreen;
  final bool destinyPurchased;
  final bool destinyStyle;
  final Color paperColor;
  final Color paperBorder;
  final VoidCallback onBuyGreenXp;
  final VoidCallback onToggleDestiny;

  const ShopPage({
    super.key,
    required this.lang,
    required this.gold,
    required this.xpBarGreen,
    required this.destinyPurchased,
    required this.destinyStyle,
    required this.paperColor,
    required this.paperBorder,
    required this.onBuyGreenXp,
    required this.onToggleDestiny,
  });

  String _tr(AppLang lang, String key) {
    final m = {
      'shop':         {AppLang.de: 'Shop',          AppLang.en: 'Shop'},
      'greenXpTitle': {AppLang.de: 'Green XP Bar',  AppLang.en: 'Green XP Bar'},
      'destinyTitle': {AppLang.de: 'Destiny Style', AppLang.en: 'Destiny Style'},
      'buy':          {AppLang.de: 'Kaufen',        AppLang.en: 'Buy'},
      'on':           {AppLang.de: 'An',            AppLang.en: 'On'},
      'off':          {AppLang.de: 'Aus',           AppLang.en: 'Off'},
      'gold':         {AppLang.de: 'Gold',          AppLang.en: 'gold'},
    };
    return m[key]?[lang] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 200) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0805),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0805),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Color(0xFFC9A84C), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _tr(lang, 'shop'),
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFC9A84C),
              letterSpacing: 1,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [

              // ── Hero Badge ──
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC9A84C).withOpacity(0.35),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icons/Shop.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Gold Counter ──
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1610),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFC9A84C).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: Alignment(-0.3, -0.3),
                          colors: [Color(0xFFFFD86B), Color(0xFFB8860B)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$gold ${_tr(lang, 'gold')}',
                      style: GoogleFonts.cinzel(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC9A84C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Green XP Bar ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: paperColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: paperBorder, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr(lang, 'greenXpTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton(
                      onPressed:
                      xpBarGreen || gold < 10 ? null : onBuyGreenXp,
                      child: Text(
                        xpBarGreen ? '✓' : '${_tr(lang, 'buy')} (10)',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Destiny Style ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: paperColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: paperBorder, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr(lang, 'destinyTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton(
                      onPressed: (!destinyPurchased && gold < 20)
                          ? null
                          : onToggleDestiny,
                      child: Text(
                        !destinyPurchased
                            ? '${_tr(lang, "buy")} (20)'
                            : (destinyStyle
                            ? _tr(lang, 'off')
                            : _tr(lang, 'on')),
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}