import 'package:flutter/material.dart';

import '../../../../shared/widgets/landing_footer.dart';
import '../../../../shared/widgets/landing_header.dart';
import '../widgets/cta_section.dart';
import '../widgets/dashboard_preview_section.dart';
import '../widgets/features_section.dart';
import '../widgets/hero_section.dart';
import '../widgets/how_it_works_section.dart';
import '../widgets/stats_bar.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _mobileMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                LandingHeader(
                  onMenuToggle: () =>
                      setState(() => _mobileMenuOpen = !_mobileMenuOpen),
                  menuOpen: _mobileMenuOpen,
                ),
                if (_mobileMenuOpen) const LandingMobileNav(),
                const HeroSection(),
                const StatsBar(),
                const FeaturesSection(),
                const HowItWorksSection(),
                const DashboardPreviewSection(),
                const CtaSection(),
                const LandingFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
