import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../services/media.dart';

class SettingsMainView extends StatelessWidget {
  const SettingsMainView({
    super.key,
    required this.shop,
    required this.devices,
    required this.signatures,
    required this.pushEnabled,
    required this.busy,
    required this.onTogglePush,
    required this.onRemoveDevice,
    required this.onEditShopName,
    required this.onEditProfilePicture,
    required this.onEditPhone,
    required this.onEditEmail,
    required this.onEditAddress,
    required this.onAddSignature,
    required this.onDeleteSignature,
    required this.onPrivacy,
    required this.onTerms,
    required this.onSupport,
    required this.onLogout,
    required this.appVersion,
  });

  final ShopProfile shop;
  final List<DeviceSession> devices;
  final List<SignatureItem> signatures;
  final bool pushEnabled;
  final bool busy;
  final ValueChanged<bool> onTogglePush;
  final ValueChanged<DeviceSession> onRemoveDevice;
  final VoidCallback onEditShopName;
  final VoidCallback onEditProfilePicture;
  final VoidCallback onEditPhone;
  final VoidCallback onEditEmail;
  final VoidCallback onEditAddress;
  final VoidCallback onAddSignature;
  final ValueChanged<SignatureItem> onDeleteSignature;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onSupport;
  final VoidCallback onLogout;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const SettingsSectionTitle('SHOP PROFILE'),
        const SizedBox(height: 8),
        SettingsWhiteCard(
          children: [
            SettingsProfilePictureRow(
              logoUrl: shop.logoUrl,
              onTap: onEditProfilePicture,
            ),
            SettingsInfoRow(
              label: 'Shop Name',
              value: shop.name,
              onTap: onEditShopName,
            ),
            SettingsInfoRow(
              label: 'Phone',
              value: shop.phone,
              onTap: onEditPhone,
            ),
            SettingsInfoRow(
              label: 'Email',
              value: shop.email,
              singleLineValue: true,
              onTap: onEditEmail,
            ),
            SettingsInfoRow(
              label: 'Address',
              value: (shop.address ?? '').isEmpty ? 'Not set' : shop.address!,
              onTap: onEditAddress,
            ),
            SettingsInfoRow(
              label: 'Timezone',
              value: shop.timezone,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SettingsSectionTitle('SIGNATURES'),
        const SizedBox(height: 8),
        SettingsWhiteCard(
          children: [
            SettingsActionRow(title: 'Upload Signature', onTap: onAddSignature),
            if (signatures.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Text(
                  'No signature added yet.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ...signatures.map(
              (signature) => SettingsSignatureRow(
                signature: signature,
                busy: busy,
                onDelete: () => onDeleteSignature(signature),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SettingsSectionTitle('NOTIFICATIONS'),
        const SizedBox(height: 8),
        SettingsWhiteCard(
          children: [
            SettingsSwitchRow(
              title: 'Push Notifications',
              value: pushEnabled,
              onChanged: onTogglePush,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SettingsSectionTitle('LOGGED-IN DEVICES'),
        const SizedBox(height: 8),
        SettingsWhiteCard(
          children: devices.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Text(
                      'No active device session found.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ]
              : devices
                    .map(
                      (device) => SettingsDeviceRow(
                        device: device,
                        busy: busy,
                        onRemove: () => onRemoveDevice(device),
                      ),
                    )
                    .toList(),
        ),
        const SizedBox(height: 16),
        const SettingsSectionTitle('APP INFO'),
        const SizedBox(height: 8),
        SettingsWhiteCard(
          children: [
            SettingsActionRow(title: 'Privacy Policy', onTap: onPrivacy),
            SettingsActionRow(title: 'Terms of Service', onTap: onTerms),
            SettingsActionRow(title: 'Contact Support', onTap: onSupport),
            SettingsInfoRow(
              label: 'App Version',
              value: appVersion,
            ),
          ],
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onLogout,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFFECACA)),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text(
            'Logout',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    );
  }
}

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
      ),
    );
  }
}

class SettingsWhiteCard extends StatelessWidget {
  const SettingsWhiteCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: _joinWithDivider(children)),
    );
  }

  List<Widget> _joinWithDivider(List<Widget> widgets) {
    final out = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      out.add(widgets[i]);
      if (i < widgets.length - 1) {
        out.add(
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
        );
      }
    }
    return out;
  }
}

class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    this.singleLineValue = false,
    this.onTap,
  });

  final String label;
  final String? hint;
  final String value;
  final bool singleLineValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if ((hint ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: singleLineValue ? 1 : 2,
              softWrap: !singleLineValue,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class SettingsProfilePictureRow extends StatelessWidget {
  const SettingsProfilePictureRow({
    super.key,
    required this.logoUrl,
    required this.onTap,
  });

  final String? logoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: (logoUrl ?? '').trim().isEmpty
                  ? const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF64748B),
                    )
                  : Image(
                      image: MediaService.imageProvider(logoUrl!)!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => const Icon(
                        Icons.storefront_rounded,
                        color: Color(0xFF64748B),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Picture',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.title,
    required this.onTap,
  });
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF007AFF),
          ),
        ],
      ),
    );
  }
}

class SettingsDeviceRow extends StatelessWidget {
  const SettingsDeviceRow({
    super.key,
    required this.device,
    required this.busy,
    required this.onRemove,
  });

  final DeviceSession device;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final title = deviceTitle(device);
    final subtitle = deviceSubtitle(device);
    final icon = deviceIconData(device);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }
}

class SettingsSignatureRow extends StatelessWidget {
  const SettingsSignatureRow({
    super.key,
    required this.signature,
    required this.busy,
    required this.onDelete,
  });

  final SignatureItem signature;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image(
              image: MediaService.imageProvider(signature.imageUrl)!,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) =>
                  const Icon(Icons.draw_rounded, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              signature.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            onPressed: busy ? null : onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

IconData deviceIconData(DeviceSession device) {
  final platform = (device.devicePlatform ?? '').toLowerCase();
  final os = (device.deviceOs ?? '').toLowerCase();
  final name = (device.deviceName ?? '').toLowerCase();
  final fingerprint = '$platform $os $name';

  if (fingerprint.contains('android')) {
    return Icons.android_rounded;
  }
  if (fingerprint.contains('iphone') || fingerprint.contains('ios')) {
    return Icons.phone_iphone_rounded;
  }
  if (fingerprint.contains('phone') ||
      fingerprint.contains('mobile') ||
      fingerprint.contains('android') ||
      fingerprint.contains('ios')) {
    return Icons.smartphone_rounded;
  }
  return Icons.language_rounded;
}

class SettingsSkeletonCard extends StatelessWidget {
  const SettingsSkeletonCard({super.key, required this.lines});
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(lines, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EBF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7EBF1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

String deviceTitle(DeviceSession device) {
  final name = (device.deviceName ?? '').trim();
  final platform = (device.devicePlatform ?? '').trim();
  final os = (device.deviceOs ?? '').trim();
  if (name.isNotEmpty) return name;
  if (platform.isNotEmpty && os.isNotEmpty) return '$platform $os';
  if (platform.isNotEmpty) return platform;
  return 'Unknown device';
}

String deviceSubtitle(DeviceSession device) {
  final platform = (device.devicePlatform ?? '').trim();
  final os = (device.deviceOs ?? '').trim();
  final location = (device.location ?? '').trim();
  final parts = <String>[];
  if (platform.isNotEmpty || os.isNotEmpty) {
    parts.add([platform, os].where((e) => e.isNotEmpty).join(' '));
  }
  if (location.isNotEmpty) parts.add(location);
  if (parts.isEmpty) return 'No location info';
  return parts.join(' • ');
}
