import 'dart:io';
import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../preview/preview.dart';
import '../../services/api_client.dart';
import '../../services/currency.dart';
import '../../services/local_cache.dart';
import '../../services/media.dart';
import '../../services/phone.dart';
import '../../services/region.dart';
import '../../services/token_store.dart';
import '../../services/validators.dart';

part 'states.dart';
part 'widgets/steps.dart';
part 'widgets/sheets.dart';
part 'widgets/cards.dart';
part 'widgets/controls.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen>
    with WidgetsBindingObserver {
  final ApiClient _api = ApiClient(TokenStore());

  static const String _legacyDraftKey = 'draft_new_sale';
  static const String _draftIndexKey = 'draft_new_sale_index';
  static const String _defaultDraftId = 'draft_1';
  static const String _defaultDraftLabel = 'New Sale';

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerContactController =
      TextEditingController();

  final List<_DraftSlot> _drafts = <_DraftSlot>[];
  final List<_DraftSaleItem> _items = <_DraftSaleItem>[];
  final List<SignatureItem> _signatures = <SignatureItem>[];

  bool _loadingSignatures = true;
  bool _submitting = false;
  bool _uploadingSignature = false;
  bool _switchingDraft = false;
  bool _hydratingDraft = false;
  bool _customerNameTouched = false;
  bool _customerContactTouched = false;
  bool _useEmailForContact = false;
  Country? _country;
  String? _phoneError;
  Timer? _phoneDebounce;
  Future<void>? _signaturesRequest;
  late final String _currencySymbol;
  late final String _currencyLocale;
  late final String _deviceRegionCode;

  int _step = 0;
  String? _selectedSignatureId;
  String _activeDraftId = _defaultDraftId;

  @override
  void initState() {
    super.initState();
    _deviceRegionCode = RegionService.getDeviceRegionCode();
    final ctx = CurrencyService.resolveContext();
    _currencyLocale = ctx.locale;
    _currencySymbol = ctx.symbol;
    WidgetsBinding.instance.addObserver(this);
    _initCountry();
    unawaited(_initializeScreen());
    _customerNameController.addListener(_onCustomerNameChanged);
    _customerContactController.addListener(_saveDraftDebounced);
  }

  String _formatAmount(num amount, {int decimalDigits = 2}) {
    return NumberFormat.currency(
      locale: _currencyLocale,
      symbol: _currencySymbol,
      decimalDigits: decimalDigits,
    ).format(amount);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_persistDraftSilently());
    _api.dispose();
    _phoneDebounce?.cancel();
    _customerNameController.dispose();
    _customerContactController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistDraftSilently());
    }
  }

  Future<void> _initializeScreen() async {
    await _loadDraftBootstrap();
    await _loadSignatures();
  }

  Future<void> _persistDraftSilently() async {
    try {
      await _saveDraft();
    } catch (_) {}
  }

  void _initCountry() {
    try {
      _country = CountryParser.parseCountryCode(_deviceRegionCode);
    } catch (_) {
      _country = CountryParser.parseCountryCode('NG');
    }
  }

  Future<void> _loadSignatures() async {
    final inFlight = _signaturesRequest;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final request = _loadSignaturesInternal();
    _signaturesRequest = request;
    try {
      await request;
    } finally {
      if (identical(_signaturesRequest, request)) {
        _signaturesRequest = null;
      }
    }
  }

  Future<void> _loadSignaturesInternal() async {
    setState(() => _loadingSignatures = true);
    final cached = LocalCache.loadSignatures();
    if (cached.isNotEmpty) {
      try {
        final cachedSignatures = cached.map(SignatureItem.fromJson).toList();
        if (mounted) {
          setState(() {
            _signatures
              ..clear()
              ..addAll(cachedSignatures);
            _selectedSignatureId ??= cachedSignatures.isNotEmpty
                ? cachedSignatures.first.id
                : null;
            _loadingSignatures = false;
          });
        }
        return;
      } catch (_) {
        // Fallback to API only when cached data is invalid.
      }
    }

    try {
      final signatures = await _api.listSignatures();
      if (!mounted) return;
      setState(() {
        _signatures
          ..clear()
          ..addAll(signatures);
        _selectedSignatureId ??= signatures.isNotEmpty
            ? signatures.first.id
            : null;
      });
      await LocalCache.saveSignatures(
        signatures.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e is ApiException ? e.message : 'Unable to load signatures.',
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSignatures = false);
      }
    }
  }

  String _draftStorageKey(String draftId) => 'draft_new_sale_$draftId';

  Future<void> _loadDraftBootstrap() async {
    final legacy = LocalCache.loadDraft(_legacyDraftKey);
    if (legacy != null) {
      await LocalCache.saveDraft(_draftStorageKey(_defaultDraftId), legacy);
      await LocalCache.clearDraft(_legacyDraftKey);
    }

    final index = LocalCache.loadDraft(_draftIndexKey);
    if (index == null) {
      _drafts
        ..clear()
        ..add(const _DraftSlot(id: _defaultDraftId, label: _defaultDraftLabel));
      _activeDraftId = _defaultDraftId;
      await _saveDraftIndex();
      await _loadDraft(_activeDraftId);
      return;
    }

    final draftMaps = (index['drafts'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    final idsLegacy = (index['ids'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (draftMaps.isEmpty && idsLegacy.isEmpty) {
      _drafts
        ..clear()
        ..add(const _DraftSlot(id: _defaultDraftId, label: _defaultDraftLabel));
      _activeDraftId = _defaultDraftId;
      await _saveDraftIndex();
      await _loadDraft(_activeDraftId);
      return;
    }

    if (draftMaps.isNotEmpty) {
      _drafts
        ..clear()
        ..addAll(
          draftMaps.map(
            (raw) => _DraftSlot(
              id: (raw['id'] ?? '').toString(),
              label:
                  ((raw['label'] ?? '').toString().trim().isEmpty
                          ? _defaultDraftLabel
                          : (raw['label'] ?? '').toString())
                      .trim(),
            ),
          ),
        );
    } else {
      _drafts
        ..clear()
        ..addAll(
          idsLegacy.map((id) => _DraftSlot(id: id, label: _defaultDraftLabel)),
        );
    }

    _drafts.removeWhere((d) => d.id.trim().isEmpty);
    if (_drafts.isEmpty) {
      _drafts.add(
        const _DraftSlot(id: _defaultDraftId, label: _defaultDraftLabel),
      );
    }

    final ids = _drafts.map((d) => d.id).toList();
    final active = (index['active_id'] ?? '').toString();
    _activeDraftId = ids.contains(active) ? active : ids.first;
    _activeDraftId = _pickBestActiveDraft(_activeDraftId);
    await _saveDraftIndex();
    await _loadDraft(_activeDraftId);
  }

  String _pickBestActiveDraft(String currentActiveId) {
    bool hasMeaningfulData(String draftId) {
      final draft = LocalCache.loadDraft(_draftStorageKey(draftId));
      if (draft == null) return false;
      final items = (draft['items'] as List<dynamic>? ?? const <dynamic>[]);
      if (items.isNotEmpty) return true;
      final customerName = (draft['customer_name'] ?? '').toString().trim();
      final customerContact = (draft['customer_contact'] ?? '')
          .toString()
          .trim();
      final signatureId = (draft['signature_id'] ?? '').toString().trim();
      return customerName.isNotEmpty ||
          customerContact.isNotEmpty ||
          signatureId.isNotEmpty;
    }

    if (hasMeaningfulData(currentActiveId)) {
      return currentActiveId;
    }

    for (final draft in _drafts.reversed) {
      if (hasMeaningfulData(draft.id)) {
        return draft.id;
      }
    }
    return currentActiveId;
  }

  Future<void> _loadDraft(String draftId) async {
    final draft = LocalCache.loadDraft(_draftStorageKey(draftId));
    if (draft == null) {
      if (!mounted) return;
      _hydratingDraft = true;
      setState(() {
        _customerNameController.text = '';
        _customerContactController.text = '';
        _useEmailForContact = false;
        _phoneError = null;
        _selectedSignatureId = _signatures.isNotEmpty
            ? _signatures.first.id
            : null;
        _step = 0;
        _customerNameTouched = false;
        _customerContactTouched = false;
        _items.clear();
      });
      _hydratingDraft = false;
      return;
    }

    final rawItems = (draft['items'] as List<dynamic>? ?? <dynamic>[]);
    final parsedItems = rawItems
        .map((raw) {
          final map = raw as Map<String, dynamic>;
          return _DraftSaleItem(
            productName: (map['product_name'] ?? '').toString(),
            quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
            unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
          );
        })
        .where((item) => item.productName.trim().isNotEmpty)
        .toList();

    if (!mounted) return;
    _hydratingDraft = true;
    setState(() {
      _customerNameController.text = (draft['customer_name'] ?? '').toString();
      _customerContactController.text = (draft['customer_contact'] ?? '')
          .toString();
      _useEmailForContact = draft['contact_use_email'] == true;
      final countryCode = (draft['contact_country'] ?? '').toString().trim();
      if (countryCode.isNotEmpty) {
        try {
          _country = CountryParser.parseCountryCode(countryCode);
        } catch (_) {}
      }
      _phoneError = null;
      _selectedSignatureId = draft['signature_id']?.toString();
      _step = (draft['step'] as num?)?.toInt().clamp(0, 1) ?? 0;
      _customerNameTouched = false;
      _customerContactTouched = false;
      _items
        ..clear()
        ..addAll(parsedItems);
    });
    _hydratingDraft = false;
  }

  void _saveDraftDebounced() {
    if (_switchingDraft || _hydratingDraft) return;
    unawaited(_saveDraft());
  }

  void _onCustomerNameChanged() {
    if (_switchingDraft || _hydratingDraft) return;
    final slotIndex = _drafts.indexWhere((d) => d.id == _activeDraftId);
    if (slotIndex >= 0) {
      final trimmed = _customerNameController.text.trim();
      final nextLabel = trimmed.isEmpty ? _defaultDraftLabel : trimmed;
      if (_drafts[slotIndex].label != nextLabel && mounted) {
        setState(() {
          _drafts[slotIndex] = _DraftSlot(id: _activeDraftId, label: nextLabel);
        });
      }
    }
    _saveDraftDebounced();
  }

  Future<void> _saveDraft() async {
    if (_switchingDraft || _hydratingDraft) return;
    final trimmedName = _customerNameController.text.trim();
    final nextLabel = trimmedName.isEmpty ? _defaultDraftLabel : trimmedName;
    final slotIndex = _drafts.indexWhere((d) => d.id == _activeDraftId);
    if (slotIndex >= 0 && _drafts[slotIndex].label != nextLabel) {
      _drafts[slotIndex] = _DraftSlot(id: _activeDraftId, label: nextLabel);
      await _saveDraftIndex();
    }

    await LocalCache.saveDraft(_draftStorageKey(_activeDraftId), {
      'customer_name': _customerNameController.text.trim(),
      'customer_contact': _customerContactController.text.trim(),
      'contact_use_email': _useEmailForContact,
      'contact_country': _country?.countryCode,
      'signature_id': _selectedSignatureId,
      'step': _step,
      'items': _items
          .map(
            (item) => {
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
            },
          )
          .toList(),
    });
  }

  Future<void> _saveDraftIndex() async {
    await LocalCache.saveDraft(_draftIndexKey, {
      'active_id': _activeDraftId,
      'drafts': _drafts.map((d) => {'id': d.id, 'label': d.label}).toList(),
    });
  }

  Future<void> _createDraft() async {
    await _saveDraft();
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'draft_$now';
    if (!mounted) return;
    setState(() {
      _drafts.add(const _DraftSlot(id: '', label: _defaultDraftLabel));
      _drafts[_drafts.length - 1] = _DraftSlot(
        id: id,
        label: _defaultDraftLabel,
      );
      _activeDraftId = id;
      _customerNameController.text = '';
      _customerContactController.text = '';
      _useEmailForContact = false;
      _phoneError = null;
      _selectedSignatureId = _signatures.isNotEmpty
          ? _signatures.first.id
          : null;
      _step = 0;
      _customerNameTouched = false;
      _customerContactTouched = false;
      _items.clear();
    });
    await _saveDraftIndex();
    await _saveDraft();
  }

  Future<void> _switchDraft(String draftId) async {
    if (_activeDraftId == draftId || _switchingDraft) return;
    _phoneDebounce?.cancel();
    await _saveDraft();
    if (!mounted) return;
    setState(() {
      _switchingDraft = true;
      _activeDraftId = draftId;
    });
    await _saveDraftIndex();
    await _loadDraft(draftId);
    if (mounted) {
      setState(() => _switchingDraft = false);
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    if (_drafts.length <= 1) {
      await LocalCache.clearDraft(_draftStorageKey(draftId));
      if (!mounted) return;
      setState(() {
        _customerNameController.text = '';
        _customerContactController.text = '';
        _useEmailForContact = false;
        _phoneError = null;
        _selectedSignatureId = _signatures.isNotEmpty
            ? _signatures.first.id
            : null;
        _step = 0;
        _customerNameTouched = false;
        _customerContactTouched = false;
        _items.clear();
      });
      await _saveDraft();
      return;
    }

    final wasActive = _activeDraftId == draftId;
    await LocalCache.clearDraft(_draftStorageKey(draftId));
    if (!mounted) return;
    setState(() {
      _drafts.removeWhere((d) => d.id == draftId);
      if (wasActive) {
        _activeDraftId = _drafts.first.id;
      }
    });
    await _saveDraftIndex();
    if (wasActive) {
      await _loadDraft(_activeDraftId);
    }
  }

  Future<void> _clearActiveDraftAfterSubmit() async {
    await LocalCache.clearDraft(_draftStorageKey(_activeDraftId));
    if (_drafts.length == 1) {
      if (!mounted) return;
      setState(() {
        _customerNameController.text = '';
        _customerContactController.text = '';
        _selectedSignatureId = _signatures.isNotEmpty
            ? _signatures.first.id
            : null;
        _step = 0;
        _customerNameTouched = false;
        _customerContactTouched = false;
        _items.clear();
      });
      await _saveDraft();
      return;
    }

    if (!mounted) return;
    setState(() {
      _drafts.removeWhere((d) => d.id == _activeDraftId);
      _activeDraftId = _drafts.first.id;
    });
    await _saveDraftIndex();
    await _loadDraft(_activeDraftId);
  }

  double get _saleTotal => _items.fold<double>(
    0,
    (sum, item) => sum + (item.quantity * item.unitPrice),
  );

  int get _itemCount =>
      _items.fold<int>(0, (sum, item) => sum + item.quantity.round());

  bool _isCustomerNameValid(String value) => Validators.isValidShopName(value);

  bool _isCustomerContactValid(String value) => _useEmailForContact
      ? Validators.isValidEmail(value.trim())
      : value.trim().isNotEmpty && _phoneError == null;

  bool get _customerNameInvalid =>
      _customerNameTouched &&
      !_isCustomerNameValid(_customerNameController.text);

  bool get _customerContactInvalid =>
      _customerContactTouched &&
      !_isCustomerContactValid(_customerContactController.text);

  bool get _canContinueFromDetails {
    return _isCustomerNameValid(_customerNameController.text) &&
        _isCustomerContactValid(_customerContactController.text) &&
        (_selectedSignatureId?.isNotEmpty == true);
  }

  bool get _canCreateSale => _canContinueFromDetails && _items.isNotEmpty;

  Future<void> _continueToItems() async {
    if (_customerNameController.text.trim().isEmpty) {
      setState(() => _customerNameTouched = true);
      _showSnackBar('Customer name is required.');
      return;
    }
    if (!_isCustomerNameValid(_customerNameController.text)) {
      setState(() => _customerNameTouched = true);
      _showSnackBar('Customer name must be between 3 and 40 characters.');
      return;
    }
    if (_customerContactController.text.trim().isEmpty) {
      setState(() => _customerContactTouched = true);
      _showSnackBar('Customer contact is required.');
      return;
    }
    if (!_useEmailForContact) {
      final region = _country?.countryCode ?? _deviceRegionCode;
      final valid = await PhoneService.isValid(
        _customerContactController.text.trim(),
        region,
        countryPhoneCode: _country?.phoneCode,
      );
      if (!mounted) return;
      setState(() {
        _phoneError = valid ? null : 'Enter a valid phone number.';
        _customerContactTouched = true;
      });
    }
    if (!_isCustomerContactValid(_customerContactController.text)) {
      setState(() => _customerContactTouched = true);
      _showSnackBar(
        _useEmailForContact
            ? 'Enter a valid email.'
            : 'Enter a valid phone number.',
      );
      return;
    }
    if (_selectedSignatureId == null || _selectedSignatureId!.isEmpty) {
      _showSnackBar('Select a signature.');
      return;
    }
    setState(() => _step = 1);
    unawaited(_saveDraft());
  }

  Future<bool> _submitSale() async {
    if (_submitting) return false;
    setState(() {
      _customerNameTouched = true;
      _customerContactTouched = true;
    });
    if (!_canCreateSale) {
      if (!_isCustomerNameValid(_customerNameController.text)) {
        _showSnackBar('Customer name must be between 3 and 40 characters.');
      } else if (!_isCustomerContactValid(_customerContactController.text)) {
        _showSnackBar(
          _useEmailForContact
              ? 'Enter a valid email.'
              : 'Enter a valid phone number.',
        );
      } else if (_selectedSignatureId == null ||
          _selectedSignatureId!.isEmpty) {
        _showSnackBar('Select a signature.');
      } else if (_items.isEmpty) {
        _showSnackBar('Add at least one item.');
      }
      return false;
    }

    setState(() => _submitting = true);
    try {
      final contact = await _normalizedCustomerContactForSubmit();
      if (contact == null) {
        _showSnackBar(
          _useEmailForContact
              ? 'Enter a valid email.'
              : 'Enter a valid phone number.',
        );
        setState(() {
          _customerContactTouched = true;
          _submitting = false;
        });
        return false;
      }
      final input = SaleInput(
        signatureId: _selectedSignatureId!,
        customerName: _customerNameController.text.trim(),
        customerContact: contact,
        items: _items
            .map(
              (item) => SaleItemInput(
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
              ),
            )
            .toList(),
      );

      await _api.createSale(input);
      await _clearActiveDraftAfterSubmit();
      if (!mounted) return false;
      _showSnackBar('Sale created successfully.');
      return true;
    } catch (e) {
      if (!mounted) return false;
      _showSnackBar(e is ApiException ? e.message : 'Unable to create sale.');
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  ShopProfile? _previewShop() {
    final raw = LocalCache.loadSettingsSummary();
    if (raw == null) return null;
    try {
      return SettingsSummary.fromJson(raw).shop;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openPreview() async {
    setState(() {
      _customerNameTouched = true;
      _customerContactTouched = true;
    });
    if (!_canCreateSale) {
      if (!_isCustomerNameValid(_customerNameController.text)) {
        _showSnackBar('Customer name must be between 3 and 40 characters.');
      } else if (!_isCustomerContactValid(_customerContactController.text)) {
        _showSnackBar(
          _useEmailForContact
              ? 'Enter a valid email.'
              : 'Enter a valid phone number.',
        );
      } else if (_selectedSignatureId == null ||
          _selectedSignatureId!.isEmpty) {
        _showSnackBar('Select a signature.');
      } else if (_items.isEmpty) {
        _showSnackBar('Add at least one item.');
      }
      return;
    }

    SignatureItem? signature;
    for (final item in _signatures) {
      if (item.id == _selectedSignatureId) {
        signature = item;
        break;
      }
    }
    final shop = _previewShop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalePreviewScreen(
          isCreatedSale: false,
          shop: shop,
          signature: signature,
          customerName: _customerNameController.text.trim(),
          customerContact: _customerContactController.text.trim(),
          items: _items
              .map(
                (item) => PreviewSaleItem(
                  productName: item.productName,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                ),
              )
              .toList(),
          total: _saleTotal,
          onCreate: _submitSale,
        ),
      ),
    );
  }

  Future<String?> _normalizedCustomerContactForSubmit() async {
    final raw = _customerContactController.text.trim();
    if (_useEmailForContact) {
      if (!Validators.isValidEmail(raw)) return null;
      return raw.toLowerCase();
    }
    final region = _country?.countryCode ?? _deviceRegionCode;
    return PhoneService.normalizeE164(
      raw,
      region,
      countryPhoneCode: _country?.phoneCode,
    );
  }

  void _onContactChanged(String value) {
    _saveDraftDebounced();
    if (_useEmailForContact) {
      if (_phoneError != null && mounted) {
        setState(() => _phoneError = null);
      }
      return;
    }
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 300), () async {
      final input = value.trim();
      if (input.isEmpty) {
        if (mounted) {
          setState(() => _phoneError = null);
        }
        return;
      }
      final region = _country?.countryCode ?? _deviceRegionCode;
      final valid = await PhoneService.isValid(
        input,
        region,
        countryPhoneCode: _country?.phoneCode,
      );
      if (!mounted) return;
      setState(() {
        _phoneError = valid ? null : 'Enter a valid phone number.';
      });
      if (valid) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  Future<void> _openAddItemSheet() async {
    final result = await showModalBottomSheet<_DraftSaleItem>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: const Color(0x8A000000),
      backgroundColor: Colors.transparent,
      builder: (context) => _AddItemSheet(
        api: _api,
        currencySymbol: _currencySymbol,
        formatAmount: _formatAmount,
      ),
    );

    if (result == null) return;
    setState(() {
      _items.add(result);
    });
    await _saveDraft();
  }

  Future<void> _openAddSignatureSheet() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: const Color(0x8A000000),
      backgroundColor: Colors.transparent,
      builder: (context) => _AddSignatureSheet(
        onUpload: (name, imagePath) async {
          setState(() => _uploadingSignature = true);
          try {
            final signature = await _api.uploadSignature(
              name: name,
              imagePath: imagePath,
            );
            return signature;
          } finally {
            if (mounted) {
              setState(() => _uploadingSignature = false);
            }
          }
        },
      ),
    );

    if (!mounted || result == null) return;
    if (result is _SignatureSheetError) {
      _showSnackBar(result.message);
      return;
    }
    if (result is! SignatureItem) {
      return;
    }
    final created = result;
    setState(() {
      _signatures.insert(0, created);
      _selectedSignatureId = created.id;
    });
    await LocalCache.saveSignatures(
      _signatures.map((e) => e.toJson()).toList(),
    );
    await _saveDraft();
  }

  void _changeQuantity(int index, double delta) {
    final current = _items[index];
    final nextQty = (current.quantity + delta).clamp(1, 9999).toDouble();
    setState(() {
      _items[index] = current.copyWith(quantity: nextQty);
    });
    unawaited(_saveDraft());
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
    unawaited(_saveDraft());
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final body = _step == 0
        ? _NewSaleDetailsStep(
            customerNameController: _customerNameController,
            customerContactController: _customerContactController,
            customerNameInvalid: _customerNameInvalid,
            customerContactInvalid: _customerContactInvalid,
            useEmailForContact: _useEmailForContact,
            country: _country,
            phoneError: _phoneError,
            onPickCountry: () {
              showCountryPicker(
                context: context,
                showPhoneCode: true,
                onSelect: (value) {
                  setState(() {
                    _country = value;
                    _phoneError = null;
                    _customerContactTouched = true;
                  });
                  _onContactChanged(_customerContactController.text);
                },
              );
            },
            onToggleContactType: () {
              setState(() {
                _useEmailForContact = !_useEmailForContact;
                _phoneError = null;
                _customerContactTouched = true;
              });
              _onContactChanged(_customerContactController.text);
            },
            onCustomerNameChanged: (_) {
              if (!_customerNameTouched) {
                setState(() => _customerNameTouched = true);
              } else {
                setState(() {});
              }
            },
            onCustomerContactChanged: (_) {
              if (!_customerContactTouched) {
                setState(() => _customerContactTouched = true);
              }
              _onContactChanged(_customerContactController.text);
              setState(() {});
            },
            drafts: _drafts,
            activeDraftId: _activeDraftId,
            switchingDraft: _switchingDraft,
            onCreateDraft: _createDraft,
            onSwitchDraft: _switchDraft,
            onDeleteDraft: _deleteDraft,
            signatures: _signatures,
            loadingSignatures: _loadingSignatures,
            uploadingSignature: _uploadingSignature,
            selectedSignatureId: _selectedSignatureId,
            onSelectSignature: (id) {
              setState(() => _selectedSignatureId = id);
              unawaited(_saveDraft());
            },
            onAddSignature: _openAddSignatureSheet,
            total: _saleTotal,
            hasItems: _items.isNotEmpty,
            formatAmount: _formatAmount,
            onContinue: () => unawaited(_continueToItems()),
            onClose: () async {
              await _persistDraftSilently();
              if (!mounted) return;
              Navigator.of(this.context).pop();
            },
          )
        : _NewSaleItemsStep(
            items: _items,
            drafts: _drafts,
            activeDraftId: _activeDraftId,
            switchingDraft: _switchingDraft,
            onCreateDraft: _createDraft,
            onSwitchDraft: _switchDraft,
            onDeleteDraft: _deleteDraft,
            saleTotal: _saleTotal,
            itemCount: _itemCount,
            submitting: _submitting,
            onBack: () {
              setState(() => _step = 0);
              unawaited(_saveDraft());
            },
            onAddItem: _openAddItemSheet,
            onIncrement: (index) => _changeQuantity(index, 1),
            onDecrement: (index) => _changeQuantity(index, -1),
            onDelete: _removeItem,
            onSubmit: _openPreview,
            formatAmount: _formatAmount,
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _persistDraftSilently();
        if (!mounted) return;
        Navigator.of(this.context).pop(result);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(child: body),
        ),
      ),
    );
  }
}
