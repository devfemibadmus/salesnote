import 'package:flutter/material.dart';

import 'content.dart';

class SettingsLoadingView extends StatelessWidget {
  const SettingsLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: const [
        SettingsSectionTitle('SHOP PROFILE'),
        SizedBox(height: 8),
        SettingsSkeletonCard(lines: 3),
        SizedBox(height: 16),
        SettingsSectionTitle('SECURITY'),
        SizedBox(height: 8),
        SettingsSkeletonCard(lines: 2),
        SizedBox(height: 16),
        SettingsSectionTitle('APP INFO'),
        SizedBox(height: 8),
        SettingsSkeletonCard(lines: 3),
      ],
    );
  }
}

class SettingsErrorView extends StatelessWidget {
  const SettingsErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to load settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }
}
