import 'package:flutter/foundation.dart';
import 'package:sampada/core/network/network_exceptions.dart';
import 'package:sampada/data/models/payment_model.dart';
import 'package:sampada/data/repositories/payment_repository.dart';

/// The tourist's side of paying a guide.
///
/// Holds three things the payment screens need and nothing else: where to pay a
/// given guide, the tourist's own payment history, and the in-flight state of a
/// submission. It deliberately does not cache "is this booking paid" — the
/// booking itself carries `payment_status`, and a second copy here would be the
/// one that goes stale.
class PaymentProvider with ChangeNotifier {
  final PaymentRepository _repo;

  PaymentProvider({required PaymentRepository repository}) : _repo = repository;

  String? _userId;

  /// Called by the auth proxy on every auth change. A payment history is one of
  /// the more private things in the app; it must never survive a user switch.
  void updateUserId(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    _history = [];
    _destinations = null;
    _destinationsGuideId = null;
    _error = null;
    notifyListeners();
  }

  // ── Where to pay ──────────────────────────────────────────────────────────

  GuidePaymentDestinations? _destinations;
  int? _destinationsGuideId;
  bool _loadingDestinations = false;

  /// Set when the guide has published nothing to pay to. Not an error the user
  /// caused, and the screen says so rather than showing a failure.
  String? _destinationsError;

  GuidePaymentDestinations? get destinations => _destinations;
  bool get loadingDestinations => _loadingDestinations;
  String? get destinationsError => _destinationsError;

  Future<void> loadDestinations(int guideId) async {
    _loadingDestinations = true;
    _destinationsError = null;
    if (_destinationsGuideId != guideId) {
      _destinations = null; // never show one guide's wallet on another's screen
      _destinationsGuideId = guideId;
    }
    notifyListeners();
    try {
      _destinations = await _repo.destinationsFor(guideId);
    } catch (e) {
      _destinations = null;
      _destinationsError = _message(e);
    } finally {
      _loadingDestinations = false;
      notifyListeners();
    }
  }

  // ── Submitting a claim ────────────────────────────────────────────────────

  bool _submitting = false;
  String? _error;

  bool get submitting => _submitting;
  String? get error => _error;

  /// Returns the created claim, or null with [error] set. The booking is now
  /// `submitted`, not paid — the guide has to confirm before anything is
  /// settled, and the UI must not tell the tourist otherwise.
  Future<PaymentConfirmation?> submit({
    required int bookingId,
    required PaymentMethod method,
    String reference = '',
    String screenshotUrl = '',
    String notes = '',
  }) async {
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final confirmation = await _repo.submit(
        bookingId: bookingId,
        method: method,
        reference: reference,
        screenshotUrl: screenshotUrl,
        notes: notes,
      );
      _history = [confirmation, ..._history];
      return confirmation;
    } catch (e) {
      _error = _message(e);
      return null;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ── History ───────────────────────────────────────────────────────────────

  List<PaymentConfirmation> _history = [];
  bool _loadingHistory = false;
  String? _historyError;

  List<PaymentConfirmation> get history => _history;
  bool get loadingHistory => _loadingHistory;

  /// Non-null when the last fetch failed. Without it the screen cannot tell a
  /// network failure apart from "you have never paid anyone".
  String? get historyError => _historyError;

  Future<void> loadHistory({PaymentStatus? status}) async {
    _loadingHistory = true;
    _historyError = null;
    notifyListeners();
    try {
      _history = await _repo.history(status: status);
    } catch (e) {
      _historyError = _message(e);
    } finally {
      _loadingHistory = false;
      notifyListeners();
    }
  }

  /// The claims raised against one booking, newest first — the payment screen
  /// shows the last rejection so the tourist knows what to fix.
  List<PaymentConfirmation> forBooking(int bookingId) =>
      _history.where((p) => p.bookingId == bookingId).toList()
        ..sort((a, b) => (b.submittedAt ?? DateTime(0))
            .compareTo(a.submittedAt ?? DateTime(0)));

  Future<PaymentConfirmation?> detail(int paymentId) async {
    try {
      return await _repo.detail(paymentId);
    } catch (e) {
      _error = _message(e);
      notifyListeners();
      return null;
    }
  }

  Future<List<int>?> receiptPdf(int paymentId) async {
    try {
      return await _repo.receiptPdf(paymentId);
    } catch (e) {
      _error = _message(e);
      notifyListeners();
      return null;
    }
  }

  /// The server writes sentences the user can act on ("You have already
  /// submitted that transaction reference…"); its `toString()` wraps them in
  /// class name and status code. Show the sentence.
  String _message(Object e) =>
      e is ServerException ? e.message : e.toString();
}
