import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum EvoluaLogoVariant { hero, sidebar }

class EvoluaLogo extends StatelessWidget {
  const EvoluaLogo({
    super.key,
    this.variant = EvoluaLogoVariant.hero,
  });

  final EvoluaLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final isHero = variant == EvoluaLogoVariant.hero;
    final logoSize = isHero ? 72.0 : 56.0;
    final logoRadius = isHero ? 24.0 : 18.0;
    final titleSize = isHero ? 30.0 : 23.0;
    final subtitleSize = isHero ? 16.0 : 13.0;
    final titleWeight = isHero ? FontWeight.w800 : FontWeight.w700;
    final spacing = isHero ? 18.0 : 14.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(logoRadius),
            boxShadow: [
              BoxShadow(
                color: const Color(0x225CE1E6),
                blurRadius: isHero ? 28 : 22,
                offset: Offset(0, isHero ? 10 : 8),
              ),
              if (isHero)
                const BoxShadow(
                  color: Color(0x145CE1E6),
                  blurRadius: 42,
                  offset: Offset(0, 16),
                ),
            ],
            border: Border.all(
              color: AppColors.outline.withValues(alpha: isHero ? 0.14 : 0.08),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(logoRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surfaceStrong.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: isHero ? 0.05 : 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(logoRadius - 2),
                child: Padding(
                  padding: EdgeInsets.all(isHero ? 1.2 : 1),
                  child: Image.asset(
                    'assets/branding/app_logo_trimmed.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: spacing),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Evolua',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: titleSize,
                  fontWeight: titleWeight,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              SizedBox(height: isHero ? 6 : 4),
              Text(
                'Autoconhecimento em movimento',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: subtitleSize,
                      letterSpacing: isHero ? 0.2 : 0.1,
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
