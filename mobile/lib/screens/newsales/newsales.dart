import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../data/models.dart';
import '../preview/preview.dart';
import '../../services/api_client.dart';
import '../../services/bank_account.dart';
import '../../services/cache/loader.dart';
import '../../services/currency.dart';
import '../../services/cache/local.dart';
import '../../services/media.dart';
import '../../services/notice.dart';
import '../../services/phone.dart';
import '../../services/region.dart';
import '../../services/token_store.dart';
import '../../services/validators.dart';
import '../../widgets/add_signature_sheet.dart';

part 'states.dart';
part 'widgets/steps.dart';
part 'widgets/sheets.dart';
part 'widgets/cards.dart';
part 'widgets/controls.dart';

enum _ChargeType { discount, vat, serviceFee, delivery, rounding, other }

class _AdjustmentDraft {
  const _AdjustmentDraft({required this.type, required this.amount});

  final _ChargeType type;
  final double amount;
}

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key, this.routeArgs});

  final NewSaleRouteArgs? routeArgs;

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen>
    with WidgetsBindingObserver {
  final ApiClient _api = ApiClient(TokenStore());
  final PageController _stepController = PageController();

  static const String _legacyDraftKey = 'draft_new_sale';
  static const String _draftIndexKey = 'draft_new_sale_index';
  static const String _defaultDraftId = 'draft_1';
  static const String _defaultDraftLabel = 'New Sale';
  static const String _defaultOtherLabel = 'Others';
  static const double _maxAmount = 9_999_999_999.99;
  static const int _salesRefreshPerPage = 20;

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
  bool _didAutoOpenAgentPreview = false;
  bool _routeAgentDraftHydrated = false;
  bool _customerNameTouched = false;
  bool _customerContactTouched = false;
  double _discountAmount = 0;
  double _vatAmount = 0;
  double _serviceFeeAmount = 0;
  double _deliveryFeeAmount = 0;
  double _roundingAmount = 0;
  double _otherAmount = 0;
  String _otherLabel = _defaultOtherLabel;
  Country? _country;
  String? _phoneError;
  Timer? _phoneDebounce;
  Future<void>? _signaturesRequest;
  late final String _currencySymbol;
  late final String _currencyLocale;
  late final String _accountRegionCode;

  int _step = 0;
  bool _stepSwipeUnlocked = false;
  String? _selectedSignatureId;
  String? _selectedBankAccountId;
  String _activeDraftId = _defaultDraftId;
  SaleStatus _saleStatus = SaleStatus.paid;

  @override
  void initState() {
    super.initState();
    _accountRegionCode = RegionService.resolveAccountRegionCode();
    final ctx = CurrencyService.resolveContext();
    _currencyLocale = ctx.locale;
    _currencySymbol = ctx.symbol;
    WidgetsBinding.instance.addObserver(this);
    _initCountry();
    unawaited(_initializeScreen());
    _customerNameController.addListener(_onCustomerNameChanged);
    _customerContactController.addListener(_saveDraftDebounced);
  }

  String _invalidPhoneMessage() {
    return RegionService.invalidPhoneMessage(
      country: _country,
      regionCode: _accountRegionCode,
    );
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
    _stepController.dispose();
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
    if (widget.routeArgs?.openPreviewOnLoad == true && !_didAutoOpenAgentPreview) {
      _didAutoOpenAgentPreview = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _openPreview(
            autoCreate: widget.routeArgs?.autoCreateOnPreviewLoad == true,
          ),
        );
      });
    }
  }

  void _syncStepController({bool animate = false}) {
    if (!_stepController.hasClients) return;
    if ((_stepController.page?.round() ?? _stepController.initialPage) == _step) {
      return;
    }
    if (animate) {
      unawaited(
        _stepController.animateToPage(
          _step,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    _stepController.jumpToPage(_step);
  }

  void _setStep(int value, {bool animate = false, bool unlockSwipe = false}) {
    final next = value.clamp(0, 1);
    if (!mounted) return;
    setState(() {
      _step = next;
      if (unlockSwipe) {
        _stepSwipeUnlocked = true;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncStepController(animate: animate);
    });
  }

  Future<void> _persistDraftSilently() async {
    try {
      await _saveDraft();
    } catch (_) {}
  }

  String _draftDebugSummary({String? draftId}) {
    return 'draftId=${(draftId ?? _activeDraftId).trim()} '
        'kind=${_saleStatus == SaleStatus.invoice ? "invoice" : "receipt"} '
        'customer=${_customerNameController.text.trim().isEmpty ? "-" : _customerNameController.text.trim()} '
        'contact=${_customerContactController.text.trim().isEmpty ? "-" : _customerContactController.text.trim()} '
        'items=${_items.length}';
  }

  void _draftLog(String message) {
    debugPrint('NEW SALE DRAFT: $message');
  }

  void _initCountry() {
    _country = RegionService.resolveAccountCountry();
    _selectedBankAccountId = _resolveBankAccountId(_selectedBankAccountId);
  }

  bool get _creatingInvoice => _saleStatus == SaleStatus.invoice;

  String? _resolveBankAccountId(String? candidate) {
    final bankAccounts = _previewShop()?.bankAccounts ?? const <ShopBankAccount>[];
    if (candidate != null &&
        bankAccounts.any((bankAccount) => bankAccount.id == candidate)) {
      return candidate;
    }
    return bankAccounts.isNotEmpty ? bankAccounts.first.id : null;
  }

  String get _documentTitle => _creatingInvoice ? 'New Invoice' : 'New Sale';

  String get _successMessage =>
      _creatingInvoice
          ? 'Invoice created successfully.'
          : 'Sale created successfully.';

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
    try {
      final signatures = await CacheLoader.loadOrFetchSignatures(_api);
      if (!mounted) return;
      setState(() {
        _signatures
          ..clear()
          ..addAll(signatures);
        _selectedSignatureId ??= signatures.isNotEmpty
            ? signatures.first.id
            : null;
      });
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
    void applyRouteDraftId() {
      final routedDraftId = widget.routeArgs?.draftId?.trim() ?? '';
      if (routedDraftId.isEmpty) {
        return;
      }
      final existingIndex = _drafts.indexWhere((d) => d.id == routedDraftId);
      if (existingIndex < 0) {
        _drafts.add(
          const _DraftSlot(id: '', label: _defaultDraftLabel),
        );
        _drafts[_drafts.length - 1] = _DraftSlot(
          id: routedDraftId,
          label: _defaultDraftLabel,
        );
      }
      _activeDraftId = routedDraftId;
    }

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
      applyRouteDraftId();
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
      applyRouteDraftId();
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
    applyRouteDraftId();
    _activeDraftId = _pickBestActiveDraft(_activeDraftId);
    if ((widget.routeArgs?.draftId?.trim().isNotEmpty ?? false)) {
      _activeDraftId = widget.routeArgs!.draftId!.trim();
    }
    _draftLog(
      'bootstrap active=$active routed=${widget.routeArgs?.draftId ?? "-"} '
      'resolved=${_activeDraftId.isEmpty ? "-" : _activeDraftId} drafts=${_drafts.length}',
    );
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
      final discountAmount =
          (draft['discount_amount'] as num?)?.toDouble() ?? 0;
      final vatAmount =
          ((draft['vat_amount'] ?? draft['tax_amount']) as num?)?.toDouble() ??
          0;
      final serviceFeeAmount =
          (draft['service_fee_amount'] as num?)?.toDouble() ?? 0;
      final deliveryFeeAmount =
          (draft['delivery_fee_amount'] as num?)?.toDouble() ?? 0;
      final roundingAmount =
          (draft['rounding_amount'] as num?)?.toDouble() ?? 0;
      final otherAmount = (draft['other_amount'] as num?)?.toDouble() ?? 0;
      return customerName.isNotEmpty ||
          customerContact.isNotEmpty ||
          signatureId.isNotEmpty ||
          discountAmount != 0 ||
          vatAmount != 0 ||
          serviceFeeAmount != 0 ||
          deliveryFeeAmount != 0 ||
          roundingAmount != 0 ||
          otherAmount != 0;
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
    final agentDraft = _routeAgentDraftHydrated ? null : widget.routeArgs?.agentDraft;
    if (agentDraft != null) {
      _draftLog(
        'loadDraft:agentDraft routeDraftId=${widget.routeArgs?.draftId ?? "-"} '
        'target=$draftId items=${agentDraft.items.length} '
        'customer=${agentDraft.customerName?.trim().isNotEmpty == true ? agentDraft.customerName!.trim() : "-"} '
        'contact=${agentDraft.customerContact?.trim().isNotEmpty == true ? agentDraft.customerContact!.trim() : "-"}',
      );
      if (!mounted) return;
      _hydratingDraft = true;
      setState(() {
        _customerNameController.text = agentDraft.customerName ?? '';
        _customerContactController.text = agentDraft.customerContact ?? '';
        _phoneError = null;
        _discountAmount = agentDraft.discountAmount;
        _vatAmount = agentDraft.vatAmount;
        _serviceFeeAmount = agentDraft.serviceFeeAmount;
        _deliveryFeeAmount = agentDraft.deliveryFeeAmount;
        _roundingAmount = agentDraft.roundingAmount;
        _otherAmount = agentDraft.otherAmount;
        _otherLabel =
            (agentDraft.otherLabel?.trim().isNotEmpty ?? false)
                ? agentDraft.otherLabel!.trim()
                : _defaultOtherLabel;
        _selectedSignatureId = agentDraft.signatureId;
        _selectedBankAccountId = _resolveBankAccountId(agentDraft.bankAccountId);
        _saleStatus = widget.routeArgs?.startAsInvoice == true
            ? SaleStatus.invoice
            : SaleStatus.paid;
        _step = agentDraft.items.isNotEmpty ||
                (agentDraft.customerName?.trim().isNotEmpty ?? false) ||
                (agentDraft.customerContact?.trim().isNotEmpty ?? false)
            ? 1
            : 0;
        _stepSwipeUnlocked = _step == 1;
        _customerNameTouched = false;
        _customerContactTouched = false;
        _items
          ..clear()
          ..addAll(
            agentDraft.items.map(
              (item) => _DraftSaleItem(
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice ?? 0,
              ),
            ),
          );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncStepController();
      });
      _hydratingDraft = false;
      _routeAgentDraftHydrated = true;
      await _saveDraft();
      return;
    }

    final draft = LocalCache.loadDraft(_draftStorageKey(draftId));
    if (draft == null) {
      _draftLog('loadDraft:empty target=$draftId');
      if (!mounted) return;
      _hydratingDraft = true;
      setState(() {
        _customerNameController.text = '';
        _customerContactController.text = '';
        _phoneError = null;
        _discountAmount = 0;
        _vatAmount = 0;
        _serviceFeeAmount = 0;
        _deliveryFeeAmount = 0;
        _roundingAmount = 0;
        _otherAmount = 0;
        _otherLabel = _defaultOtherLabel;
        _selectedSignatureId = _signatures.isNotEmpty
            ? _signatures.first.id
            : null;
        _selectedBankAccountId = _resolveBankAccountId(null);
        _saleStatus = widget.routeArgs?.startAsInvoice == true
            ? SaleStatus.invoice
            : SaleStatus.paid;
        _step = 0;
        _stepSwipeUnlocked = false;
        _customerNameTouched = false;
        _customerContactTouched = false;
        _items.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncStepController();
      });
      _hydratingDraft = false;
      return;
    }

    _draftLog(
      'loadDraft:stored target=$draftId '
      'customer=${(draft['customer_name'] ?? '').toString().trim().isEmpty ? "-" : (draft['customer_name'] ?? '').toString().trim()} '
      'contact=${(draft['customer_contact'] ?? '').toString().trim().isEmpty ? "-" : (draft['customer_contact'] ?? '').toString().trim()} '
      'items=${(draft['items'] as List<dynamic>? ?? const <dynamic>[]).length}',
    );

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
      final countryCode = (draft['contact_country'] ?? '').toString().trim();
      if (countryCode.isNotEmpty) {
        try {
          _country = CountryParser.parseCountryCode(countryCode);
        } catch (_) {}
      }
      _phoneError = null;
      _discountAmount = (draft['discount_amount'] as num?)?.toDouble() ?? 0;
      _vatAmount =
          ((draft['vat_amount'] ?? draft['tax_amount']) as num?)?.toDouble() ??
          0;
      _serviceFeeAmount =
          (draft['service_fee_amount'] as num?)?.toDouble() ?? 0;
      _deliveryFeeAmount =
          (draft['delivery_fee_amount'] as num?)?.toDouble() ?? 0;
      _roundingAmount = (draft['rounding_amount'] as num?)?.toDouble() ?? 0;
      _otherAmount = (draft['other_amount'] as num?)?.toDouble() ?? 0;
      final otherLabel = (draft['other_label'] ?? '').toString().trim();
      _otherLabel = otherLabel.isEmpty ? _defaultOtherLabel : otherLabel;
      _selectedSignatureId = draft['signature_id']?.toString();
      _selectedBankAccountId = _resolveBankAccountId(
        draft['bank_account_id']?.toString(),
      );
      final rawStatus = (draft['status'] ?? '').toString().trim().toLowerCase();
      _saleStatus = rawStatus == 'invoice'
          ? SaleStatus.invoice
          : SaleStatus.paid;
      _step = (draft['step'] as num?)?.toInt().clamp(0, 1) ?? 0;
      _stepSwipeUnlocked = _step == 1 || parsedItems.isNotEmpty;
      _customerNameTouched = false;
      _customerContactTouched = false;
      _items
        ..clear()
        ..addAll(parsedItems);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncStepController();
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

  void _setSaleStatus(SaleStatus status) {
    if (_saleStatus == status) return;
    setState(() {
      _saleStatus = status;
      if (status == SaleStatus.invoice && _selectedBankAccountId == null) {
        _selectedBankAccountId = _resolveBankAccountId(null);
      }
    });
    unawaited(_saveDraft());
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
      'contact_country': _country?.countryCode,
      'discount_amount': _discountAmount,
      'vat_amount': _vatAmount,
      'service_fee_amount': _serviceFeeAmount,
      'delivery_fee_amount': _deliveryFeeAmount,
      'rounding_amount': _roundingAmount,
      'other_amount': _otherAmount,
      'other_label': _otherLabel,
      'signature_id': _selectedSignatureId,
      'bank_account_id': _selectedBankAccountId,
      'status': _saleStatus.name,
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
    _draftLog('save ${_draftDebugSummary()}');
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
    _draftLog('create from=${_activeDraftId.isEmpty ? "-" : _activeDraftId} to=$id');
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
      _phoneError = null;
      _discountAmount = 0;
      _vatAmount = 0;
      _serviceFeeAmount = 0;
      _deliveryFeeAmount = 0;
      _roundingAmount = 0;
      _otherAmount = 0;
      _otherLabel = _defaultOtherLabel;
      _selectedSignatureId = _signatures.isNotEmpty
          ? _signatures.first.id
          : null;
      _selectedBankAccountId = _resolveBankAccountId(null);
      _step = 0;
      _stepSwipeUnlocked = false;
      _customerNameTouched = false;
      _customerContactTouched = false;
      _items.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncStepController();
    });
    await _saveDraftIndex();
    await _saveDraft();
  }

  Future<void> _switchDraft(String draftId) async {
    if (_activeDraftId == draftId || _switchingDraft) return;
    _phoneDebounce?.cancel();
    _draftLog('switch from=${_activeDraftId.isEmpty ? "-" : _activeDraftId} to=$draftId');
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
        _phoneError = null;
        _discountAmount = 0;
        _vatAmount = 0;
        _serviceFeeAmount = 0;
        _deliveryFeeAmount = 0;
        _roundingAmount = 0;
        _otherAmount = 0;
        _otherLabel = _defaultOtherLabel;
        _selectedSignatureId = _signatures.isNotEmpty
            ? _signatures.first.id
            : null;
        _selectedBankAccountId = _resolveBankAccountId(null);
        _step = 0;
        _stepSwipeUnlocked = false;
        _customerNameTouched = false;
        _customerContactTouched = false;
        _items.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncStepController();
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
        _discountAmount = 0;
        _vatAmount = 0;
        _serviceFeeAmount = 0;
        _deliveryFeeAmount = 0;
        _roundingAmount = 0;
        _otherAmount = 0;
        _otherLabel = _defaultOtherLabel;
        _selectedSignatureId = _signatures.isNotEmpty
            ? _signatures.first.id
            : null;
        _step = 0;
        _stepSwipeUnlocked = false;
        _customerNameTouched = false;
        _customerContactTouched = false;
        _items.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncStepController();
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

  double get _saleSubtotal => _items.fold<double>(
    0,
    (sum, item) => sum + (item.quantity * item.unitPrice),
  );

  double get _saleTotal =>
      _saleSubtotal -
      _discountAmount +
      _vatAmount +
      _serviceFeeAmount +
      _deliveryFeeAmount +
      _roundingAmount +
      _otherAmount;

  bool get _pricingValid =>
      _saleTotal.isFinite && _saleTotal >= 0 && _saleTotal <= _maxAmount;

  int get _itemCount =>
      _items.fold<int>(0, (sum, item) => sum + item.quantity.round());

  bool _isCustomerNameValid(String value) => Validators.isValidShopName(value);

  bool _isCustomerContactValid(String value) {
    final input = value.trim();
    if (input.isEmpty) return false;
    final isEmail = input.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(input);
    if (isEmail) return Validators.isValidEmail(input);
    return _phoneError == null;
  }

  bool get _customerNameInvalid =>
      _customerNameTouched &&
      !_isCustomerNameValid(_customerNameController.text);

  bool get _customerContactInvalid =>
      _customerContactTouched &&
      !_isCustomerContactValid(_customerContactController.text);

  bool get _canContinueFromDetails {
    return _isCustomerNameValid(_customerNameController.text) &&
        _isCustomerContactValid(_customerContactController.text) &&
        (_creatingInvoice
            ? ((_selectedBankAccountId?.isNotEmpty == true) &&
                (_selectedSignatureId?.isNotEmpty == true))
            : (_selectedSignatureId?.isNotEmpty == true));
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
    final contactInput = _customerContactController.text.trim();
    final isEmail = contactInput.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(contactInput);
    if (!isEmail) {
      final region = _country?.countryCode ?? _accountRegionCode;
      final valid = await PhoneService.isValid(
        contactInput,
        region,
        countryPhoneCode: _country?.phoneCode,
      );
      if (!mounted) return;
      setState(() {
        _phoneError = valid ? null : _invalidPhoneMessage();
        _customerContactTouched = true;
      });
    }
    if (!_isCustomerContactValid(contactInput)) {
      setState(() => _customerContactTouched = true);
      _showSnackBar(
        isEmail
            ? 'Enter a valid email.'
            : _invalidPhoneMessage(),
      );
      return;
    }
    if (_creatingInvoice &&
        (_selectedBankAccountId == null || _selectedBankAccountId!.isEmpty)) {
      _showSnackBar('Select a bank account.');
      return;
    }
    if (_creatingInvoice &&
        (_selectedSignatureId == null || _selectedSignatureId!.isEmpty)) {
      _showSnackBar('Select a signature.');
      return;
    }
    if (!_creatingInvoice &&
        (_selectedSignatureId == null || _selectedSignatureId!.isEmpty)) {
      _showSnackBar('Select a signature.');
      return;
    }
    _setStep(1, animate: true, unlockSwipe: true);
    unawaited(_saveDraft());
  }

  Future<String?> _submitSale() async {
    if (_submitting) return null;
    setState(() {
      _customerNameTouched = true;
      _customerContactTouched = true;
    });
    if (!_canCreateSale) {
      if (!_isCustomerNameValid(_customerNameController.text)) {
        _showSnackBar('Customer name must be between 3 and 40 characters.');
      } else if (!_isCustomerContactValid(_customerContactController.text)) {
        final contactInput = _customerContactController.text.trim();
        final isEmail = contactInput.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(contactInput);
        _showSnackBar(
          isEmail
              ? 'Enter a valid email.'
              : _invalidPhoneMessage(),
        );
      } else if (_creatingInvoice &&
          (_selectedBankAccountId == null || _selectedBankAccountId!.isEmpty)) {
        _showSnackBar('Select a bank account.');
      } else if (_creatingInvoice &&
          (_selectedSignatureId == null || _selectedSignatureId!.isEmpty)) {
        _showSnackBar('Select a signature.');
      } else if (!_creatingInvoice &&
          (_selectedSignatureId == null || _selectedSignatureId!.isEmpty)) {
        _showSnackBar('Select a signature.');
      } else if (_items.isEmpty) {
        _showSnackBar('Add at least one item.');
      }
      return null;
    }
    if (!_pricingValid) {
      _showSnackBar('Grand total must be between 0 and 9,999,999,999.99.');
      return null;
    }

    setState(() => _submitting = true);
    try {
      final contact = await _normalizedCustomerContactForSubmit();
      if (contact == null) {
        final contactInput = _customerContactController.text.trim();
        final isEmail = contactInput.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(contactInput);
        _showSnackBar(
          isEmail
              ? 'Enter a valid email.'
              : _invalidPhoneMessage(),
        );
        setState(() {
          _customerContactTouched = true;
          _submitting = false;
        });
        return null;
      }
      final input = SaleInput(
        signatureId: _selectedSignatureId,
        customerName: _customerNameController.text.trim(),
        customerContact: contact,
        status: _saleStatus,
        discountAmount: _discountAmount,
        vatAmount: _vatAmount,
        serviceFeeAmount: _serviceFeeAmount,
        deliveryFeeAmount: _deliveryFeeAmount,
        roundingAmount: _roundingAmount,
        otherAmount: _otherAmount,
        otherLabel: _otherLabel,
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

      final createdSale = await _api.createSale(input);
      await _updateLocalCachesAfterSaleCreate(createdSale);
      unawaited(_refreshPostCreateCachesAfterSaleCreate(createdSale.status));
      await _clearActiveDraftAfterSubmit();
      if (!mounted) return null;
      _showSnackBar(_successMessage);
      return createdSale.id;
    } catch (e) {
      if (!mounted) return null;
      _showSnackBar(e is ApiException ? e.message : 'Unable to create sale.');
      return null;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updateLocalCachesAfterSaleCreate(Sale createdSale) async {
    final salesCache = CacheLoader.loadSalesPageCache(
      includeItems: false,
      status: createdSale.status,
    );
    if (salesCache != null) {
      try {
        final cachedSales = salesCache.sales;
        final deduped = <Sale>[
          createdSale,
          ...cachedSales.where((s) => s.id != createdSale.id),
        ];
        await CacheLoader.saveSalesPageCache(
          includeItems: false,
          status: createdSale.status,
          data: CachedSalesPage(
            sales: deduped,
            page: salesCache.page,
            hasMore: salesCache.hasMore,
          ),
        );
      } catch (_) {}
    }

    final itemsCache = CacheLoader.loadSalesPageCache(
      includeItems: true,
      status: SaleStatus.paid,
    );
    if (itemsCache != null && createdSale.isPaidReceipt) {
      try {
        final cachedSales = itemsCache.sales;
        final deduped = <Sale>[
          createdSale,
          ...cachedSales.where((s) => s.id != createdSale.id),
        ];
        await CacheLoader.saveSalesPageCache(
          includeItems: true,
          status: SaleStatus.paid,
          data: CachedSalesPage(
            sales: deduped,
            page: itemsCache.page,
            hasMore: itemsCache.hasMore,
          ),
        );
      } catch (_) {}
    }

    await CacheLoader.saveSalePreviewCache(createdSale);

    final suggested = CacheLoader.loadItemSuggestionsCache();
    final merged = <String>{...suggested};
    for (final item in createdSale.items) {
      final name = item.productName.trim();
      if (name.isNotEmpty) merged.add(name);
    }
    await CacheLoader.saveItemSuggestionsCache(merged.toList());
  }

  Future<void> _refreshPostCreateCachesAfterSaleCreate(SaleStatus status) async {
    final bgApi = ApiClient(TokenStore());
    try {
      final tasks = <Future<void>>[
        CacheLoader.fetchAndCacheSalesPage(
          bgApi,
          includeItems: false,
          page: 1,
          perPage: _salesRefreshPerPage,
          status: status,
        ).then((_) {}),
      ];
      if (status == SaleStatus.paid) {
        tasks.add(CacheLoader.fetchAndCacheHomeSummary(bgApi));
        tasks.add(
          CacheLoader.fetchAndCacheSalesPage(
            bgApi,
            includeItems: true,
            page: 1,
            perPage: _salesRefreshPerPage,
            status: SaleStatus.paid,
          ).then((_) {}),
        );
      }
      await Future.wait<void>(tasks);
    } catch (_) {
      // Ignore refresh failure; local optimistic caches are already updated.
    } finally {
      bgApi.dispose();
    }
  }

  ShopProfile? _previewShop() {
    return CacheLoader.loadSettingsSummaryCache()?.shop;
  }

  Future<void> _openPreview({bool autoCreate = false}) async {
    setState(() {
      _customerNameTouched = true;
      _customerContactTouched = true;
    });
    if (!_canCreateSale) {
      if (!_isCustomerNameValid(_customerNameController.text)) {
        _showSnackBar('Customer name must be between 3 and 40 characters.');
      } else if (!_isCustomerContactValid(_customerContactController.text)) {
        final contactInput = _customerContactController.text.trim();
        final isEmail = contactInput.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(contactInput);
        _showSnackBar(
          isEmail
              ? 'Enter a valid email.'
              : _invalidPhoneMessage(),
        );
      } else if (_creatingInvoice &&
          (_selectedBankAccountId == null || _selectedBankAccountId!.isEmpty)) {
        _showSnackBar('Select a bank account.');
      } else if (_creatingInvoice &&
          (_selectedSignatureId == null || _selectedSignatureId!.isEmpty)) {
        _showSnackBar('Select a signature.');
      } else if (!_creatingInvoice &&
          (_selectedSignatureId == null || _selectedSignatureId!.isEmpty)) {
        _showSnackBar('Select a signature.');
      } else if (_items.isEmpty) {
        _showSnackBar('Add at least one item.');
      }
      return;
    }
    if (!_pricingValid) {
      _showSnackBar('Grand total must be between 0 and 9,999,999,999.99.');
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
    final createdSaleId = await Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(
        builder: (_) => SalePreviewScreen(
          isCreatedSale: false,
          autoCreateOnLoad: autoCreate,
          status: _saleStatus,
          shop: shop,
          selectedBankAccountId: _selectedBankAccountId,
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
          subtotal: _saleSubtotal,
          discountAmount: _discountAmount,
          vatAmount: _vatAmount,
          serviceFeeAmount: _serviceFeeAmount,
          deliveryFeeAmount: _deliveryFeeAmount,
          roundingAmount: _roundingAmount,
          otherAmount: _otherAmount,
          otherLabel: _otherLabel,
          total: _saleTotal,
          onCreate: _submitSale,
        ),
      ),
    );
    if (!mounted || createdSaleId == null || createdSaleId.trim().isEmpty) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      _creatingInvoice ? AppRoutes.invoices : AppRoutes.sales,
      (_) => false,
      arguments: _creatingInvoice
          ? InvoicesRouteArgs(
              openSaleId: createdSaleId.trim(),
              refreshFirst: false,
            )
          : SalesRouteArgs(
              openSaleId: createdSaleId.trim(),
              refreshFirst: false,
            ),
    );
  }

  Future<String?> _normalizedCustomerContactForSubmit() async {
    final raw = _customerContactController.text.trim();
    if (raw.isEmpty) return null;
    final isEmail = raw.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(raw);
    
    if (isEmail) {
      if (!Validators.isValidEmail(raw)) return null;
      return raw.toLowerCase();
    }
    
    final region = _country?.countryCode ?? _accountRegionCode;
    return PhoneService.normalizeE164(
      raw,
      region,
      countryPhoneCode: _country?.phoneCode,
    );
  }

  void _onContactChanged(String value) {
    _saveDraftDebounced();
    final input = value.trim();
    final isEmail = input.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(input);
    
    if (isEmail || input.isEmpty) {
      if (_phoneError != null && mounted) {
        setState(() => _phoneError = null);
      }
      return;
    }
    
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 300), () async {
      final region = _country?.countryCode ?? _accountRegionCode;
      final valid = await PhoneService.isValid(
        input,
        region,
        countryPhoneCode: _country?.phoneCode,
      );
      if (!mounted) return;
      setState(() {
        _phoneError = valid ? null : _invalidPhoneMessage();
      });
      if (valid) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  Future<void> _openAddItemSheet({int? editIndex}) async {
    final initialItem = editIndex != null ? _items[editIndex] : null;
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
        initialItem: initialItem,
      ),
    );

    if (result == null) return;
    setState(() {
      if (editIndex != null) {
        _items[editIndex] = result;
      } else {
        _items.add(result);
      }
    });
    await _saveDraft();
  }

  Future<void> _openAddSignatureSheet() async {
    final result = await showAddSignatureSheet(
      context: context,
      onUpload: (name, imagePath) async {
        setState(() => _uploadingSignature = true);
        try {
          return await _api.uploadSignature(name: name, imagePath: imagePath);
        } finally {
          if (mounted) {
            setState(() => _uploadingSignature = false);
          }
        }
      },
    );

    if (!mounted || result == null) return;
    if (result.errorMessage != null) {
      _showSnackBar(result.errorMessage!);
      return;
    }
    if (result.signature == null) {
      return;
    }
    final created = result.signature!;
    setState(() {
      _signatures.insert(0, created);
      _selectedSignatureId = created.id;
    });
    await CacheLoader.saveSignaturesCache(_signatures);
    await _saveDraft();
  }

  Future<void> _openAddBankAccountDialog() async {
    final shop = _previewShop();
    if (shop == null) {
      _showSnackBar('Unable to load shop profile.');
      return;
    }
    if (shop.bankAccounts.length >= 2) {
      _showSnackBar('You can save at most two bank accounts.');
      return;
    }
    final usedIds = shop.bankAccounts.map((e) => e.id).toSet();
    final nextId = !usedIds.contains('1') ? '1' : '2';
    final created = await showBankAccountDialog(
      context: context,
      initial: ShopBankAccount(
        id: nextId,
        bankName: '',
        accountNumber: '',
        accountName: '',
      ),
      isNew: true,
    );
    if (created == null) return;

    final nextBankAccounts = [...shop.bankAccounts, created]
      ..sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));

    try {
      final updatedShop = await _api.updateShop(
        ShopUpdateInput(bankAccounts: nextBankAccounts),
      );
      await _updateShopCaches(updatedShop);
      if (!mounted) return;
      setState(() {
        _selectedBankAccountId = updatedShop.bankAccounts
            .firstWhere((e) => e.id == created.id, orElse: () => updatedShop.bankAccounts.first)
            .id;
      });
      await _saveDraft();
      _showSnackBar('Bank account added.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e is ApiException ? e.message : 'Unable to add bank account.');
    }
  }

  Future<void> _updateShopCaches(ShopProfile updatedShop) async {
    final settings = CacheLoader.loadSettingsSummaryCache();
    if (settings != null) {
      await CacheLoader.saveSettingsSummaryCache(
        SettingsSummary(
          shop: updatedShop,
          devices: settings.devices,
          currentDevicePushEnabled: settings.currentDevicePushEnabled,
        ),
      );
    }

    final home = CacheLoader.loadHomeSummaryCache();
    if (home != null) {
      await CacheLoader.saveHomeSummaryCache(
        HomeSummary(
          shop: updatedShop,
          analytics: home.analytics,
          recentSales: home.recentSales,
        ),
      );
    }
  }

  void _changeQuantity(int index, double delta) {
    final current = _items[index];
    final nextQty = (current.quantity + delta).clamp(1, 9999).toDouble();
    setState(() {
      _items[index] = current.copyWith(quantity: nextQty);
    });
    unawaited(_saveDraft());
  }

  void _setQuantity(int index, double value) {
    final current = _items[index];
    final nextQty = value.clamp(1, 9999).toDouble();
    setState(() {
      _items[index] = current.copyWith(quantity: nextQty);
    });
    unawaited(_saveDraft());
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
    unawaited(_saveDraft());
  }

  String _chargeLabel(_ChargeType type) {
    switch (type) {
      case _ChargeType.discount:
        return 'Discount';
      case _ChargeType.vat:
        return 'VAT';
      case _ChargeType.serviceFee:
        return 'Service Fee';
      case _ChargeType.delivery:
        return 'Delivery';
      case _ChargeType.rounding:
        return 'Rounding';
      case _ChargeType.other:
        return _otherLabel.trim().isEmpty ? _defaultOtherLabel : _otherLabel;
    }
  }

  double _chargeAmount(_ChargeType type) {
    switch (type) {
      case _ChargeType.discount:
        return _discountAmount;
      case _ChargeType.vat:
        return _vatAmount;
      case _ChargeType.serviceFee:
        return _serviceFeeAmount;
      case _ChargeType.delivery:
        return _deliveryFeeAmount;
      case _ChargeType.rounding:
        return _roundingAmount;
      case _ChargeType.other:
        return _otherAmount;
    }
  }

  void _setChargeAmount(_ChargeType type, double amount) {
    switch (type) {
      case _ChargeType.discount:
        _discountAmount = amount;
        break;
      case _ChargeType.vat:
        _vatAmount = amount;
        break;
      case _ChargeType.serviceFee:
        _serviceFeeAmount = amount;
        break;
      case _ChargeType.delivery:
        _deliveryFeeAmount = amount;
        break;
      case _ChargeType.rounding:
        _roundingAmount = amount;
        break;
      case _ChargeType.other:
        _otherAmount = amount;
        _otherLabel = _defaultOtherLabel;
        break;
    }
  }

  _ChargeType _nextSuggestedChargeType() {
    const preferredOrder = <_ChargeType>[
      _ChargeType.discount,
      _ChargeType.vat,
      _ChargeType.serviceFee,
      _ChargeType.delivery,
      _ChargeType.rounding,
      _ChargeType.other,
    ];
    for (final type in preferredOrder) {
      if (_chargeAmount(type) == 0) {
        return type;
      }
    }
    return _ChargeType.discount;
  }

  Future<void> _openAdjustmentSheet({_ChargeType? initialType}) async {
    final types = const <_ChargeType>[
      _ChargeType.discount,
      _ChargeType.vat,
      _ChargeType.serviceFee,
      _ChargeType.delivery,
      _ChargeType.rounding,
      _ChargeType.other,
    ];
    var selectedType = initialType ?? _nextSuggestedChargeType();
    final current = _chargeAmount(selectedType);
    var usePercentage = false;
    final controller = TextEditingController(
      text: current == 0
          ? ''
          : _ThousandsSeparatedNumberFormatter.formatForDisplay(
              current.toStringAsFixed(2),
              allowNegative: selectedType == _ChargeType.rounding,
            ),
    );
    String? errorText;

    void syncEditorValue() {
      final amount = _chargeAmount(selectedType);
      if (amount == 0) {
        controller.text = '';
        return;
      }
      if (usePercentage) {
        if (_saleSubtotal <= 0) {
          controller.text = '';
          return;
        }
        final percentage = (amount / _saleSubtotal) * 100;
        controller.text = _ThousandsSeparatedNumberFormatter.formatForDisplay(
          percentage.toStringAsFixed(2),
          allowNegative: selectedType == _ChargeType.rounding,
        );
        return;
      }
      controller.text = _ThousandsSeparatedNumberFormatter.formatForDisplay(
        amount.toStringAsFixed(2),
        allowNegative: selectedType == _ChargeType.rounding,
      );
    }

    final result = await showModalBottomSheet<_AdjustmentDraft?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final allowNegative = selectedType == _ChargeType.rounding;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6DFEB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add Adjustment',
                          style: TextStyle(
                            color: Color(0xFF0E1930),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: types
                        .map(
                          (type) => _SuggestionChip(
                            label: _chargeLabel(type),
                            active: selectedType == type,
                            onTap: () {
                              setLocalState(() {
                                selectedType = type;
                                syncEditorValue();
                                errorText = null;
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD7E0EB)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          usePercentage ? 'Percentage' : 'Amount',
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Use %',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: usePercentage,
                          activeThumbColor: const Color(0xFF1677E6),
                          onChanged: (value) {
                            setLocalState(() {
                              usePercentage = value;
                              syncEditorValue();
                              errorText = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InputBox(
                    controller: controller,
                    hint: usePercentage
                        ? (allowNegative ? 'e.g -5 or 8.5' : 'e.g 8.5')
                        : (allowNegative ? 'e.g -20 or 20' : 'e.g 20'),
                    compact: true,
                    isInvalid: errorText != null,
                    textAlign: usePercentage
                        ? TextAlign.right
                        : TextAlign.start,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                      signed: allowNegative && !usePercentage,
                    ),
                    inputFormatters: [
                      _ThousandsSeparatedNumberFormatter(
                        allowNegative: allowNegative,
                      ),
                    ],
                    onChanged: (_) {
                      if (errorText != null) {
                        setLocalState(() => errorText = null);
                      }
                    },
                    prefix: usePercentage
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              _currencySymbol,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                    suffix: usePercentage
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '%',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        final raw = controller.text.trim();
                        if (raw.isEmpty) {
                          setLocalState(() => errorText = 'Enter amount.');
                          return;
                        }
                        final parsed = double.tryParse(
                          _ThousandsSeparatedNumberFormatter.normalize(raw),
                        );
                        if (parsed == null || !parsed.isFinite) {
                          setLocalState(
                            () => errorText = 'Enter a valid number.',
                          );
                          return;
                        }
                        var resolvedAmount = parsed;
                        if (usePercentage) {
                          if (_saleSubtotal <= 0) {
                            setLocalState(
                              () => errorText =
                                  'Add item first before using percentage.',
                            );
                            return;
                          }
                          resolvedAmount = (_saleSubtotal * parsed) / 100;
                        }
                        if (!resolvedAmount.isFinite) {
                          setLocalState(() => errorText = 'Amount is invalid.');
                          return;
                        }
                        if (!allowNegative && resolvedAmount < 0) {
                          setLocalState(
                            () => errorText = 'This amount cannot be negative.',
                          );
                          return;
                        }
                        if (resolvedAmount.abs() > _maxAmount) {
                          setLocalState(
                            () => errorText = 'Amount is too large.',
                          );
                          return;
                        }
                        Navigator.of(context).pop(
                          _AdjustmentDraft(
                            type: selectedType,
                            amount: resolvedAmount,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1677E6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 7,
                        shadowColor: const Color(0x331677E6),
                      ),
                      child: const Text(
                        'Save Adjustment',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _setChargeAmount(result.type, result.amount);
    });
    await _saveDraft();
  }

  Future<void> _removeCharge(_ChargeType type) async {
    if (_chargeAmount(type) == 0) return;
    setState(() => _setChargeAmount(type, 0));
    await _saveDraft();
  }

  void _showSnackBar(String message) {
    AppNotice.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final body = PageView(
      controller: _stepController,
      physics: _stepSwipeUnlocked
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (value) {
        if (_step == value) return;
        setState(() => _step = value);
        unawaited(_saveDraft());
      },
      children: [
        _NewSaleDetailsStep(
          title: _documentTitle,
          saleStatus: _saleStatus,
          customerNameController: _customerNameController,
          customerContactController: _customerContactController,
          customerNameInvalid: _customerNameInvalid,
          customerContactInvalid: _customerContactInvalid,
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
          bankAccounts: _previewShop()?.bankAccounts ?? const <ShopBankAccount>[],
          selectedBankAccountId: _selectedBankAccountId,
          onSelectSignature: (id) {
            setState(() => _selectedSignatureId = id);
            unawaited(_saveDraft());
          },
          onSelectBankAccount: (id) {
            setState(() => _selectedBankAccountId = id);
            unawaited(_saveDraft());
          },
          onAddSignature: _openAddSignatureSheet,
          onAddBankAccount: _openAddBankAccountDialog,
          onStatusChanged: _setSaleStatus,
          total: _saleTotal,
          hasItems: _items.isNotEmpty,
          formatAmount: _formatAmount,
          onContinue: () => unawaited(_continueToItems()),
          onClose: () async {
            await _persistDraftSilently();
            if (!mounted) return;
            Navigator.of(this.context).pop();
          },
        ),
        _NewSaleItemsStep(
          previewLabel: _creatingInvoice ? 'Preview Invoice  →' : 'Preview Receipt  →',
          items: _items,
          drafts: _drafts,
          activeDraftId: _activeDraftId,
          switchingDraft: _switchingDraft,
          onCreateDraft: _createDraft,
          onSwitchDraft: _switchDraft,
          onDeleteDraft: _deleteDraft,
          saleSubtotal: _saleSubtotal,
          saleTotal: _saleTotal,
          discountAmount: _discountAmount,
          vatAmount: _vatAmount,
          serviceFeeAmount: _serviceFeeAmount,
          deliveryFeeAmount: _deliveryFeeAmount,
          roundingAmount: _roundingAmount,
          otherAmount: _otherAmount,
          otherLabel: _otherLabel,
          itemCount: _itemCount,
          submitting: _submitting,
          onBack: () {
            _setStep(0, animate: true);
            unawaited(_saveDraft());
          },
          onAddItem: _openAddItemSheet,
          onAddAdjustment: _openAdjustmentSheet,
          onEditAdjustment: (type) => _openAdjustmentSheet(initialType: type),
          onRemoveAdjustment: _removeCharge,
          onEdit: (index) => _openAddItemSheet(editIndex: index),
          onIncrement: (index) => _changeQuantity(index, 1),
          onDecrement: (index) => _changeQuantity(index, -1),
          onSetQuantity: _setQuantity,
          onDelete: _removeItem,
          onSubmit: _openPreview,
          formatAmount: _formatAmount,
        ),
      ],
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
