import 'package:flutter/material.dart';
import 'package:pose_detection/presentation/pages/capture_page.dart';
import 'package:pose_detection/presentation/pages/documentation_page.dart';
import 'package:pose_detection/presentation/pages/playground_page.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// Home page with navigation to different app sections.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlaygroundTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PlaygroundTheme.spacingXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: PlaygroundTheme.spacingXl),

              // Header
              const _Header(),

              const SizedBox(height: PlaygroundTheme.spacingXl * 2),

              // Navigation Cards
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                    // Playground Card
                    _NavigationCard(
                      title: 'Developer Playground',
                      subtitle: 'Explore motion tracking capabilities',
                      description:
                          'Full-featured UI with real-time visualization of joint angles, velocities, and range of motion. Adjust all configuration parameters with live preview.',
                      icon: Icons.science,
                      color: PlaygroundTheme.accent,
                      features: const [
                        'Real-time motion analysis',
                        'Configuration presets & sliders',
                        'Performance metrics dashboard',
                      ],
                      onTap: () => _navigateTo(context, const PlaygroundPage()),
                    ),

                    const SizedBox(height: PlaygroundTheme.spacingLg),

                    // Capture Card
                    _NavigationCard(
                      title: 'Simple Capture',
                      subtitle: 'Minimal pose detection view',
                      description:
                          'Clean camera view with skeleton overlay. Basic FPS and latency metrics. Ideal for integration testing.',
                      icon: Icons.camera_alt,
                      color: PlaygroundTheme.success,
                      features: const [
                        'Skeleton overlay',
                        'Basic metrics',
                        'Camera switching',
                      ],
                      onTap: () => _navigateTo(context, const CapturePage()),
                    ),

                    const SizedBox(height: PlaygroundTheme.spacingLg),

                    // Documentation Card
                    _NavigationCard(
                      title: 'Documentation',
                      subtitle: 'Developer reference guide',
                      description:
                          'Complete documentation of all configurable parameters, data models, and motion analysis features.',
                      icon: Icons.menu_book,
                      color: PlaygroundTheme.warning,
                      features: const [
                        'Configuration reference',
                        'Data model docs',
                        'API overview',
                      ],
                      onTap: () => _navigateTo(context, const DocumentationPage()),
                    ),

                    const SizedBox(height: PlaygroundTheme.spacingXl),

                    // Version info
                    const _VersionInfo(),
                    const SizedBox(height: PlaygroundTheme.spacingLg),
                  ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PlaygroundTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(PlaygroundTheme.radiusMd),
                border: Border.all(
                  color: PlaygroundTheme.accent.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.accessibility_new,
                color: PlaygroundTheme.accent,
                size: 32,
              ),
            ),
            const SizedBox(width: PlaygroundTheme.spacingLg),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motion Tracking',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: PlaygroundTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Provider-agnostic pose detection system',
                    style: TextStyle(
                      fontSize: 13,
                      color: PlaygroundTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PlaygroundTheme.spacingLg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PlaygroundTheme.spacingMd,
            vertical: PlaygroundTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: PlaygroundTheme.surfaceLight,
            borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 14, color: PlaygroundTheme.textMuted),
              SizedBox(width: 8),
              Text(
                'iOS Only • ML Kit 33 Landmarks • Clean Architecture',
                style: TextStyle(
                  fontSize: 11,
                  color: PlaygroundTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavigationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;
  final VoidCallback onTap;

  const _NavigationCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PlaygroundTheme.surface,
      borderRadius: BorderRadius.circular(PlaygroundTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlaygroundTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(PlaygroundTheme.spacingLg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PlaygroundTheme.radiusLg),
            border: Border.all(color: PlaygroundTheme.border),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(PlaygroundTheme.radiusMd),
                ),
                child: Icon(icon, color: color, size: 28),
              ),

              const SizedBox(width: PlaygroundTheme.spacingLg),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PlaygroundTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: PlaygroundTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: features.map((f) => _FeatureChip(text: f)).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: PlaygroundTheme.spacingSm),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String text;

  const _FeatureChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: PlaygroundTheme.surfaceLight,
        borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          color: PlaygroundTheme.textMuted,
        ),
      ),
    );
  }
}

class _VersionInfo extends StatelessWidget {
  const _VersionInfo();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Motion Tracking Base v1.0 • Branch: agnostic_motion_tracking',
        style: TextStyle(
          fontSize: 10,
          color: PlaygroundTheme.textMuted,
        ),
      ),
    );
  }
}
