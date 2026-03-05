import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../app/routes.dart';
import '../../data/models.dart';
import '../../services/api_client.dart';
import '../../services/cache/loader.dart';
import '../../services/cache/local.dart';
import '../../services/notification.dart';
import '../../services/phone.dart';
import '../../services/region.dart';
import '../../services/token_store.dart';
import '../../services/validators.dart';
import '../../widgets/add_signature_sheet.dart';
import '../../widgets/app_bottom_nav.dart';
import 'content.dart';
import 'states.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ApiClient _api = ApiClient(TokenStore());
  final TokenStore _tokenStore = TokenStore();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _busy = false;
  String? _error;

  ShopProfile? _shop;
  List<DeviceSession> _devices = <DeviceSession>[];
  List<SignatureItem> _signatures = <SignatureItem>[];
  bool _pushEnabled = false;
  String _appVersion = '-';

  void _goTo(String route, {bool reset = false}) {
    _api.cancelInFlight();
    if (!mounted) return;
    if (reset) {
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
      return;
    }
    Navigator.pushNamed(context, route);
  }

  @override
  void initState() {
    super.initState();
    _loadSettingsFromCacheOrApi();
  }

  Future<void> _loadSettingsFromCacheOrApi() async {
    final settings = await CacheLoader.loadOrFetchSettingsSummary(_api);
    final cachedSignatures = CacheLoader.loadSignaturesCache();
    if (settings != null) {
      final packageInfo = await PackageInfo.fromPlatform();
      final permissionGranted =
          await NotificationService.hasGrantedPermission();
      final pushEnabled =
          settings.currentDevicePushEnabled && permissionGranted;
      if (!mounted) return;
      setState(() {
        _shop = settings.shop;
        _devices = settings.devices;
        _signatures = cachedSignatures;
        _pushEnabled = pushEnabled;
        _appVersion = packageInfo.version;
        _loading = false;
        _error = null;
      });
      unawaited(_loadSignaturesInBackground(refresh: true));
      return;
    }
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
      _signatures = CacheLoader.loadSignaturesCache();
    });
    try {
      final results = await Future.wait([
        CacheLoader.fetchAndCacheSettingsSummary(_api),
        PackageInfo.fromPlatform(),
      ]);
      if (!mounted) return;
      final settings = results[0] as SettingsSummary;
      final packageInfo = results[1] as PackageInfo;
      final permissionGranted =
          await NotificationService.hasGrantedPermission();
      final pushEnabled =
          settings.currentDevicePushEnabled && permissionGranted;
      if (!mounted) return;
      setState(() {
        _shop = settings.shop;
        _devices = settings.devices;
        _pushEnabled = pushEnabled;
        _appVersion = packageInfo.version;
        _error = null;
        _loading = false;
      });
      unawaited(_loadSignaturesInBackground(refresh: true));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Unable to load settings.';
      });
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _refreshSettings() async {
    try {
      final results = await Future.wait([
        CacheLoader.fetchAndCacheSettingsSummary(_api),
        PackageInfo.fromPlatform(),
      ]);
      if (!mounted) return;
      final settings = results[0] as SettingsSummary;
      final packageInfo = results[1] as PackageInfo;
      final permissionGranted =
          await NotificationService.hasGrantedPermission();
      final pushEnabled =
          settings.currentDevicePushEnabled && permissionGranted;
      if (!mounted) return;
      setState(() {
        _shop = settings.shop;
        _devices = settings.devices;
        _pushEnabled = pushEnabled;
        _appVersion = packageInfo.version;
      });
      unawaited(_loadSignaturesInBackground(refresh: true));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to refresh settings.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _togglePush(bool value) async {
    if (value == _pushEnabled) {
      return;
    }

    if (!value) {
      setState(() => _busy = true);
      try {
        await _api.unsubscribeFcm();
        await LocalCache.setNotificationOptedOut(true);
        if (!mounted) return;
        setState(() => _pushEnabled = false);
        await _saveSettingsCache();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Push notifications turned off.')),
        );
      } catch (e) {
        if (!mounted) return;
        final message = _caughtErrorMessage(
          e,
          fallback: 'Unable to update notification setting.',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final granted = await NotificationService.ensurePermissionEnabled(context);
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permission was not granted.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final subscribed = await _subscribeCurrentDeviceFcm();
      if (!mounted) return;
      if (!subscribed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get device token. Please try again.'),
          ),
        );
        return;
      }
      await LocalCache.setNotificationOptedOut(false);
      setState(() => _pushEnabled = true);
      await _saveSettingsCache();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Push notifications turned on.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = _caughtErrorMessage(
        e,
        fallback: 'Unable to update notification setting.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSettingsCache() async {
    if (_shop == null) return;
    await CacheLoader.saveSettingsSummaryCache(
      SettingsSummary(
        shop: _shop!,
        devices: _devices,
        currentDevicePushEnabled: _pushEnabled,
      ),
    );
  }

  String _caughtErrorMessage(Object error, {required String fallback}) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    final raw = error.toString().trim();
    return raw.isEmpty ? fallback : raw;
  }

  Future<void> _saveSignaturesCache() async {
    await CacheLoader.saveSignaturesCache(_signatures);
  }

  Future<bool> _subscribeCurrentDeviceFcm() async {
    final token = await NotificationService.getDeviceTokenWithRetry();
    if (token == null || token.trim().isEmpty) {
      return false;
    }
    await _api.subscribeFcm(token);
    return true;
  }

  Future<void> _removeDevice(DeviceSession device) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Remove Device?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'You will be signed out from ${deviceTitle(device)}.',
          style: const TextStyle(
            fontSize: 18,
            height: 1.4,
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;
    setState(() => _busy = true);
    try {
      await _api.removeDevice(device.id);
      if (!mounted) return;
      setState(() {
        _devices = _devices.where((d) => d.id != device.id).toList();
      });
      await _saveSettingsCache();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Device removed.')));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to remove device.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editProfilePicture() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image == null) return;

    setState(() => _busy = true);
    try {
      final updatedRaw = await _api.uploadShopLogo(image.path);
      final cacheBust = DateTime.now().millisecondsSinceEpoch;
      await LocalCache.setShopLogoCacheBust(cacheBust);
      final updated = ShopProfile(
        id: updatedRaw.id,
        name: updatedRaw.name,
        phone: updatedRaw.phone,
        email: updatedRaw.email,
        address: updatedRaw.address,
        logoUrl: _withLogoCacheBust(updatedRaw.logoUrl, cacheBust),
        timezone: updatedRaw.timezone,
        createdAt: updatedRaw.createdAt,
      );
      if (!mounted) return;
      setState(() => _shop = updated);
      await _saveSettingsCache();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated.')));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to upload profile picture.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _withLogoCacheBust(String? src, int cacheBust) {
    final value = (src ?? '').trim();
    if (value.isEmpty) return src;
    final uri = Uri.tryParse(value);
    if (uri == null) return src;
    final nextQuery = Map<String, String>.from(uri.queryParameters)
      ..['cb'] = cacheBust.toString();
    return uri.replace(queryParameters: nextQuery).toString();
  }

  Future<void> _editShopName() async {
    final initial = _shop?.name ?? '';
    final controller = TextEditingController(text: initial);
    final value = await _showSingleInputDialog(
      title: 'Edit Shop Name',
      hint: 'Enter shop name',
      controller: controller,
      keyboardType: TextInputType.name,
      validator: (v) {
        final text = v.trim();
        if (!Validators.isValidShopName(text)) {
          return 'Shop name must be 3-40 characters.';
        }
        return null;
      },
    );
    if (value == null || value == initial) return;
    await _updateShopField(
      input: ShopUpdateInput(name: value),
      successMessage: 'Shop name updated.',
    );
  }

  Future<void> _editEmail() async {
    final initial = _shop?.email ?? '';
    final controller = TextEditingController(text: initial);
    final value = await _showSingleInputDialog(
      title: 'Edit Email',
      hint: 'name@email.com',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      validator: (v) {
        final text = v.trim();
        if (!Validators.isValidEmail(text)) {
          return 'Enter a valid email.';
        }
        return null;
      },
    );
    if (value == null || value == initial) return;
    await _updateShopField(
      input: ShopUpdateInput(email: value),
      successMessage: 'Email updated.',
    );
  }

  Future<void> _editAddress() async {
    final initial = _shop?.address ?? '';
    final controller = TextEditingController(text: initial);
    final value = await _showSingleInputDialog(
      title: 'Edit Address',
      hint: 'Enter shop address',
      controller: controller,
      keyboardType: TextInputType.streetAddress,
      validator: (v) {
        final text = v.trim();
        if (text.length < 4) {
          return 'Address must be at least 4 characters.';
        }
        if (text.length > 120) {
          return 'Address must be 120 characters or less.';
        }
        return null;
      },
    );
    if (value == null || value == initial) return;
    await _updateShopField(
      input: ShopUpdateInput(address: value),
      successMessage: 'Address updated.',
    );
  }

  Future<void> _editPhone() async {
    final initial = _shop?.phone ?? '';
    final normalized = await _showPhoneInputDialog(initial: initial);
    if (normalized == null) return;
    if (normalized == initial) return;
    await _updateShopField(
      input: ShopUpdateInput(phone: normalized),
      successMessage: 'Phone updated.',
    );
  }

  Future<String?> _showPhoneInputDialog({required String initial}) async {
    final regionCode = RegionService.getDeviceRegionCode();
    Country selectedCountry;
    try {
      selectedCountry = CountryParser.parseCountryCode(regionCode);
    } catch (_) {
      selectedCountry = CountryParser.parseCountryCode('NG');
    }

    final digitsOnly = initial.replaceAll(RegExp(r'\D'), '');
    var localInput = digitsOnly;
    if (digitsOnly.startsWith(selectedCountry.phoneCode)) {
      localInput = digitsOnly.substring(selectedCountry.phoneCode.length);
    }
    final controller = TextEditingController(text: localInput);

    return showDialog<String>(
      context: context,
      builder: (_) {
        String? errorText;

        Future<void> validate(
          void Function(void Function()) setLocalState,
        ) async {
          final value = controller.text.trim();
          if (value.isEmpty) {
            setLocalState(() => errorText = 'Phone number is required.');
            return;
          }
          final valid = await PhoneService.isValid(
            value,
            selectedCountry.countryCode,
            countryPhoneCode: selectedCountry.phoneCode,
          );
          setLocalState(() {
            errorText = valid ? null : 'Enter a valid phone number.';
          });
          if (valid) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        }

        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: const Color(0xFFF3F4F6),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text('Edit Phone'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showPhoneCode: true,
                          onSelect: (country) {
                            setLocalState(() {
                              selectedCountry = country;
                            });
                            validate(setLocalState);
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              selectedCountry.flagEmoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+${selectedCountry.phoneCode}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '8104156984',
                          errorText: errorText,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1677E6),
                            ),
                          ),
                        ),
                        onChanged: (_) => validate(setLocalState),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await validate(setLocalState);
                  if (errorText != null) return;
                  final e164 = await PhoneService.normalizeE164(
                    controller.text.trim(),
                    selectedCountry.countryCode,
                    countryPhoneCode: selectedCountry.phoneCode,
                  );
                  if (e164 == null) {
                    setLocalState(
                      () => errorText = 'Enter a valid phone number.',
                    );
                    return;
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context, e164);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addSignature() async {
    final result = await showAddSignatureSheet(
      context: context,
      onUpload: (name, imagePath) async {
        setState(() => _busy = true);
        try {
          return await _api.uploadSignature(name: name, imagePath: imagePath);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );

    if (!mounted || result == null) return;
    if (result.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
      return;
    }
    if (result.signature == null) return;
    final created = result.signature!;

    try {
      setState(() {
        _signatures = [created, ..._signatures];
      });
      await _saveSignaturesCache();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signature added.')));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to add signature.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _loadSignaturesInBackground({bool refresh = false}) async {
    try {
      final signatures = refresh
          ? await CacheLoader.fetchAndCacheSignatures(_api)
          : await CacheLoader.loadOrFetchSignatures(_api);
      if (!mounted) return;
      setState(() {
        _signatures = signatures;
      });
    } catch (_) {}
  }

  Future<void> _deleteSignature(SignatureItem signature) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Signature?'),
        content: Text('Delete "${signature.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _api.deleteSignature(signature.id);
      if (!mounted) return;
      setState(() {
        _signatures = _signatures.where((s) => s.id != signature.id).toList();
      });
      await _saveSignaturesCache();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signature deleted.')));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to delete signature.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showSingleInputDialog({
    required String title,
    required String hint,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required String? Function(String value) validator,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: const Color(0xFFF3F4F6),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(title),
            content: TextField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hint,
                errorText: errorText,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1677E6)),
                ),
              ),
              onChanged: (value) {
                final validationError = validator(value);
                setLocalState(() {
                  errorText = validationError;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  final validationError = validator(value);
                  setLocalState(() {
                    errorText = validationError;
                  });
                  if (validationError != null) return;
                  Navigator.pop(context, value);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateShopField({
    required ShopUpdateInput input,
    required String successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      final updated = await _api.updateShop(input);
      if (!mounted) return;
      setState(() => _shop = updated);
      await CacheLoader.saveSettingsSummaryCache(
        SettingsSummary(
          shop: updated,
          devices: _devices,
          currentDevicePushEnabled: _pushEnabled,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Unable to update shop.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLogout() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        content: const Text(
          'Are you sure you want to log out? Any unsaved changes may be lost.',
          style: TextStyle(fontSize: 18, height: 1.4, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep working'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (leave != true) return;
    await _tokenStore.clear();
    await LocalCache.clearAll();
    await NotificationService.clearLocalState();
    if (!mounted) return;
    _api.cancelInFlight();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.auth, (_) => false);
  }

  Future<void> _openExternalUrl(String url, String label) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid $label link.')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open $label.')));
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const SettingsLoadingView()
        : (_error != null
              ? SettingsErrorView(message: _error!, onRetry: _loadSettings)
              : SettingsMainView(
                  shop: _shop!,
                  devices: _devices,
                  signatures: _signatures,
                  pushEnabled: _pushEnabled,
                  busy: _busy,
                  onTogglePush: _togglePush,
                  onRemoveDevice: _removeDevice,
                  onEditShopName: _editShopName,
                  onEditProfilePicture: _editProfilePicture,
                  onEditPhone: _editPhone,
                  onEditEmail: _editEmail,
                  onEditAddress: _editAddress,
                  onAddSignature: _addSignature,
                  onDeleteSignature: _deleteSignature,
                  onPrivacy: () => _openExternalUrl(
                    AppConfig.privacyPolicyUrl,
                    'privacy policy',
                  ),
                  onTerms: () => _openExternalUrl(
                    AppConfig.termsOfServiceUrl,
                    'terms of service',
                  ),
                  onSupport: () =>
                      _openExternalUrl(AppConfig.supportUrl, 'support'),
                  onLogout: _confirmLogout,
                  appVersion: _appVersion,
                ));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _busy,
              child: RefreshIndicator(onRefresh: _refreshSettings, child: body),
            ),
            if (_busy)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: AppBottomTab.settings,
        onHome: () => _goTo(AppRoutes.home, reset: true),
        onSales: () => _goTo(AppRoutes.sales, reset: true),
        onAdd: () => _goTo(AppRoutes.newSale),
        onItems: () => _goTo(AppRoutes.items, reset: true),
        onSettings: () {},
      ),
    );
  }
}
