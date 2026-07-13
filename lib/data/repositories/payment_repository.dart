import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_constants.dart';
import 'package:sampada/data/models/payment_model.dart';

/// The transport for direct guide payment. Every method here is one call to the
/// backend and one decode — no state, no caching. Deciding *whether* a payment
/// may be submitted or confirmed is the server's job (it holds the booking row
/// lock); this layer only reports what it said.
class PaymentRepository {
  final ApiClient _api;

  PaymentRepository({required ApiClient apiClient}) : _api = apiClient;

  // ── Guide payment information ─────────────────────────────────────────────

  /// Where to pay this guide. 404 means they have not published details yet,
  /// which is an ordinary state and not an error — the caller distinguishes it
  /// by the message, so it is left as a thrown exception on purpose.
  Future<GuidePaymentDestinations> destinationsFor(int guideId) async {
    final data = await _api.get(ApiEndpoints.guidePaymentInformation(guideId));
    return GuidePaymentDestinations.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<GuidePaymentInformation> myPaymentInformation() async {
    final data = await _api.get(ApiEndpoints.myPaymentInformation);
    return GuidePaymentInformation.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<GuidePaymentInformation> saveMyPaymentInformation(
      GuidePaymentInformation info) async {
    // PUT, not PATCH: the form always sends the whole set, and a partial write
    // here would leave a wallet the guide cleared still on file.
    final data = await _api.put(ApiEndpoints.myPaymentInformation, data: info.toJson());
    return GuidePaymentInformation.fromJson((data as Map).cast<String, dynamic>());
  }

  // ── The payment lifecycle ─────────────────────────────────────────────────

  /// The tourist's claim that they paid. Does not mark anything paid — the
  /// booking moves to `submitted` and waits for the guide.
  Future<PaymentConfirmation> submit({
    required int bookingId,
    required PaymentMethod method,
    String reference = '',
    String screenshotUrl = '',
    String notes = '',
  }) async {
    final data = await _api.post(ApiEndpoints.paymentSubmit, data: {
      'booking': bookingId,
      'payment_method': method.wire,
      'transaction_reference': reference.trim(),
      'screenshot_url': screenshotUrl.trim(),
      'notes': notes.trim(),
    });
    return PaymentConfirmation.fromJson((data as Map).cast<String, dynamic>());
  }

  /// The guide agrees the money arrived. The only thing that pays a booking.
  Future<PaymentConfirmation> confirm(int paymentId, {String comment = ''}) async {
    final data = await _api.post(ApiEndpoints.paymentConfirm(paymentId),
        data: {'comment': comment.trim()});
    return PaymentConfirmation.fromJson((data as Map).cast<String, dynamic>());
  }

  /// The guide disputes the claim. The reason is mandatory server-side: it is
  /// all the tourist has to go on when they resubmit.
  Future<PaymentConfirmation> reject(int paymentId, String reason) async {
    final data = await _api.post(ApiEndpoints.paymentReject(paymentId),
        data: {'reason': reason.trim()});
    return PaymentConfirmation.fromJson((data as Map).cast<String, dynamic>());
  }

  // ── Reading ───────────────────────────────────────────────────────────────

  /// Role-aware server-side: a tourist gets what they submitted, a guide gets
  /// what they received, and someone who is both gets both.
  Future<List<PaymentConfirmation>> history({PaymentStatus? status}) async {
    final data = await _api.get(
      ApiEndpoints.paymentHistory,
      queryParameters: {if (status != null) 'status': status.wire},
    );
    final results = data is Map ? (data['results'] as List? ?? const []) : (data as List);
    return results
        .whereType<Map>()
        .map((m) => PaymentConfirmation.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<PaymentConfirmation> detail(int paymentId) async {
    final data = await _api.get(ApiEndpoints.paymentDetail(paymentId));
    return PaymentConfirmation.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Absolute URL of the server-rendered receipt, for `url_launcher`. The PDF
  /// itself is authenticated, so it is fetched through the client rather than
  /// handed to the browser as a bare link.
  String receiptUrl(int paymentId) =>
      '${ApiEndpoints.baseUrl}${ApiEndpoints.paymentReceiptPdf(paymentId)}';

  /// Downloads the receipt bytes with the session's Authorization header
  /// attached — the endpoint refuses anonymous requests, so opening the URL in a
  /// browser would 401.
  Future<List<int>> receiptPdf(int paymentId) =>
      _api.getBytes(ApiEndpoints.paymentReceiptPdf(paymentId));
}
