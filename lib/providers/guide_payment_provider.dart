import 'package:flutter/foundation.dart';
import 'package:sampada/core/network/network_exceptions.dart';
import 'package:sampada/data/models/payment_model.dart';
import 'package:sampada/data/repositories/payment_repository.dart';

/// The guide's side of getting paid: publish where the money should go, then
/// confirm or dispute the claims tourists raise.
///
/// Confirming is the act that marks a booking paid and issues its receipt, so
/// nothing here optimistically flips local state before the server agrees — an
/// on-screen "paid" that the backend never recorded is the one lie this module
/// exists to prevent.
class GuidePaymentProvider with ChangeNotifier {
  final PaymentRepository _repo;

  GuidePaymentProvider({required PaymentRepository repository}) : _repo = repository;

  String? _userId;

  void updateUserId(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    _information = null;
    _received = [];
    _error = null;
    notifyListeners();
  }

  // ── Payment information ───────────────────────────────────────────────────

  GuidePaymentInformation? _information;
  bool _loadingInformation = false;
  String? _error;

  GuidePaymentInformation? get information => _information;
  bool get loadingInformation => _loadingInformation;
  String? get error => _error;

  /// True when this guide has nowhere for a tourist to send money. Drives the
  /// prompt on the guide profile: an unpublished wallet means every tourist has
  /// to ask in chat, which is exactly what this module replaced.
  bool get needsSetup => !(_information?.hasWallet ?? false);

  Future<void> loadInformation() async {
    _loadingInformation = true;
    _error = null;
    notifyListeners();
    try {
      _information = await _repo.myPaymentInformation();
    } on ServerException catch (e) {
      // 404 = the logged-in user is not a guide. Ordinary, not a failure.
      if (e.statusCode != 404) _error = e.message;
      _information = null;
    } catch (e) {
      _error = _message(e);
    } finally {
      _loadingInformation = false;
      notifyListeners();
    }
  }

  /// Returns null on success, else the server's message (it explains exactly
  /// which rule failed — "add at least one account", "you chose Khalti but left
  /// it blank" — so it is shown rather than replaced).
  Future<String?> saveInformation(GuidePaymentInformation info) async {
    _error = null;
    notifyListeners();
    try {
      _information = await _repo.saveMyPaymentInformation(info);
      notifyListeners();
      return null;
    } catch (e) {
      _error = _message(e);
      notifyListeners();
      return _error;
    }
  }

  // ── Claims raised against this guide ──────────────────────────────────────

  List<PaymentConfirmation> _received = [];
  bool _loadingReceived = false;
  String? _receivedError;

  List<PaymentConfirmation> get received => _received;
  bool get loadingReceived => _loadingReceived;
  String? get receivedError => _receivedError;

  /// Claims still waiting on this guide. The badge on the guide profile counts
  /// these: a tourist who has paid is blocked from nothing, but they are owed
  /// an answer.
  List<PaymentConfirmation> get pending =>
      _received.where((p) => p.isPending).toList();

  Future<void> loadReceived({PaymentStatus? status}) async {
    _loadingReceived = true;
    _receivedError = null;
    notifyListeners();
    try {
      _received = await _repo.history(status: status);
    } catch (e) {
      _receivedError = _message(e);
    } finally {
      _loadingReceived = false;
      notifyListeners();
    }
  }

  Future<PaymentConfirmation?> detail(int paymentId) async {
    try {
      return await _repo.detail(paymentId);
    } catch (e) {
      _error = _message(e);
      notifyListeners();
      return null;
    }
  }

  /// The guide agrees the money arrived. Returns null on success, else an error.
  Future<String?> confirm(int paymentId, {String comment = ''}) async {
    try {
      final updated = await _repo.confirm(paymentId, comment: comment);
      _replace(updated);
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  /// The guide disputes the claim. [reason] is required by the server; the
  /// tourist can then resubmit against it.
  Future<String?> reject(int paymentId, String reason) async {
    try {
      final updated = await _repo.reject(paymentId, reason);
      _replace(updated);
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  void _replace(PaymentConfirmation updated) {
    final i = _received.indexWhere((p) => p.id == updated.id);
    if (i >= 0) {
      _received[i] = updated;
    } else {
      _received = [updated, ..._received];
    }
    notifyListeners();
  }

  String _message(Object e) => e is ServerException ? e.message : e.toString();
}
