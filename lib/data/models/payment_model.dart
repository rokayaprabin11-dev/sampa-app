/// Models for direct guide payment.
///
/// No money moves through Sampada. The tourist transfers to the guide's own
/// wallet (or hands over cash), then submits a claim; the guide confirms or
/// rejects it. Nothing here represents a transaction the app performed — only a
/// record of one that happened elsewhere.
///
/// DRF renders DecimalField as a JSON *string*, so `amount` is parsed
/// tolerantly rather than cast — a cast is what crashed the bookings screen.
library;

/// How the tourist says they paid. Mirrors `Booking.PAYMENT_METHODS`.
enum PaymentMethod { esewa, khalti, fonepay, cash }

extension PaymentMethodX on PaymentMethod {
  String get wire => name;

  String get label => switch (this) {
        PaymentMethod.esewa => 'eSewa',
        PaymentMethod.khalti => 'Khalti',
        PaymentMethod.fonepay => 'Fonepay',
        PaymentMethod.cash => 'Cash',
      };

  /// What the identifier under this method actually is, so the payment screen
  /// can label it truthfully instead of saying "account" for everything.
  String get identifierLabel => switch (this) {
        PaymentMethod.esewa => 'eSewa ID',
        PaymentMethod.khalti => 'Khalti mobile',
        PaymentMethod.fonepay => 'Fonepay number',
        PaymentMethod.cash => 'Paid in person',
      };

  /// Cash has nothing to reference — the server exempts it from the reference
  /// requirement, and the form must agree or it will block a valid submission.
  bool get needsReference => this != PaymentMethod.cash;

  static PaymentMethod? parse(String? value) {
    for (final m in PaymentMethod.values) {
      if (m.name == value) return m;
    }
    return null;
  }
}

/// Where the tourist should send the money, for one method.
class PaymentDestination {
  final PaymentMethod method;

  /// Empty for cash: there is no account to send to, you hand it over.
  final String identifier;

  const PaymentDestination({required this.method, required this.identifier});

  static PaymentDestination? fromJson(Map<String, dynamic> json) {
    final method = PaymentMethodX.parse(json['method'] as String?);
    if (method == null) return null; // a method this build does not know about
    return PaymentDestination(
      method: method,
      identifier: '${json['identifier'] ?? ''}',
    );
  }
}

/// The guide's published payment details, as a tourist who owes them sees it.
class GuidePaymentDestinations {
  final String guideName;
  final String guidePhoto;
  final PaymentMethod? preferred;
  final String notes;
  final List<PaymentDestination> methods;

  const GuidePaymentDestinations({
    required this.guideName,
    required this.guidePhoto,
    required this.preferred,
    required this.notes,
    required this.methods,
  });

  factory GuidePaymentDestinations.fromJson(Map<String, dynamic> json) {
    final raw = (json['methods'] as List? ?? const []);
    return GuidePaymentDestinations(
      guideName: '${json['guide_name'] ?? ''}',
      guidePhoto: '${json['guide_photo'] ?? ''}',
      preferred: PaymentMethodX.parse(json['preferred_method'] as String?),
      notes: '${json['payment_notes'] ?? ''}',
      methods: raw
          .whereType<Map>()
          .map((m) => PaymentDestination.fromJson(m.cast<String, dynamic>()))
          .whereType<PaymentDestination>()
          .toList(),
    );
  }

  /// The preferred method first — it is the one the guide asked to be paid by.
  List<PaymentDestination> get ordered {
    final list = [...methods];
    list.sort((a, b) {
      if (a.method == preferred) return -1;
      if (b.method == preferred) return 1;
      return 0;
    });
    return list;
  }
}

/// The guide's own editable payment details.
class GuidePaymentInformation {
  final PaymentMethod preferred;
  final String esewaId;
  final String khaltiMobile;
  final String fonepayNumber;
  final String notes;
  final bool isActive;

  /// Computed server-side from which wallets are filled in (cash always counts).
  final List<PaymentMethod> availableMethods;

  const GuidePaymentInformation({
    required this.preferred,
    required this.esewaId,
    required this.khaltiMobile,
    required this.fonepayNumber,
    required this.notes,
    required this.isActive,
    required this.availableMethods,
  });

  /// A guide who has never set this up gets the same empty shape from the
  /// server, so the settings form has nothing to special-case on first visit.
  factory GuidePaymentInformation.fromJson(Map<String, dynamic> json) {
    return GuidePaymentInformation(
      preferred: PaymentMethodX.parse(json['preferred_method'] as String?) ??
          PaymentMethod.esewa,
      esewaId: '${json['esewa_id'] ?? ''}',
      khaltiMobile: '${json['khalti_mobile'] ?? ''}',
      fonepayNumber: '${json['fonepay_number'] ?? ''}',
      notes: '${json['payment_notes'] ?? ''}',
      isActive: json['is_active'] as bool? ?? true,
      availableMethods: (json['available_methods'] as List? ?? const [])
          .map((m) => PaymentMethodX.parse('$m'))
          .whereType<PaymentMethod>()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'preferred_method': preferred.wire,
        'esewa_id': esewaId.trim(),
        'khalti_mobile': khaltiMobile.trim(),
        'fonepay_number': fonepayNumber.trim(),
        'payment_notes': notes.trim(),
        'is_active': isActive,
      };

  /// Mirrors the server rule: cash needs no account, so it never counts as
  /// "published details". Used to keep the guide from saving an empty form and
  /// to warn them that tourists have nowhere to pay.
  bool get hasWallet =>
      esewaId.trim().isNotEmpty ||
      khaltiMobile.trim().isNotEmpty ||
      fonepayNumber.trim().isNotEmpty;
}

enum PaymentStatus { pending, confirmed, rejected }

extension PaymentStatusX on PaymentStatus {
  String get wire => name;

  static PaymentStatus parse(String? value) => switch (value) {
        'confirmed' => PaymentStatus.confirmed,
        'rejected' => PaymentStatus.rejected,
        _ => PaymentStatus.pending,
      };
}

/// One claim that a booking was paid. A booking can hold several: a rejected
/// claim is resubmittable, and the history of the dispute is the point.
class PaymentConfirmation {
  final int id;
  final int bookingId;
  final String bookingRef;
  final String bookingDate;
  final String packageLabel;
  final String touristName;
  final String guideName;
  final PaymentMethod? method;
  final String reference;
  final String screenshotUrl;
  final String notes;
  final double? amount;
  final PaymentStatus status;

  /// The guide's reason when they rejected — the only thing the tourist has to
  /// act on, so it is never dropped.
  final String guideComment;
  final DateTime? submittedAt;
  final DateTime? resolvedAt;

  /// Issued by the guide's confirmation, never before it.
  final String receiptNo;

  const PaymentConfirmation({
    required this.id,
    required this.bookingId,
    required this.bookingRef,
    required this.bookingDate,
    required this.packageLabel,
    required this.touristName,
    required this.guideName,
    required this.method,
    required this.reference,
    required this.screenshotUrl,
    required this.notes,
    required this.amount,
    required this.status,
    required this.guideComment,
    required this.submittedAt,
    required this.resolvedAt,
    required this.receiptNo,
  });

  factory PaymentConfirmation.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    DateTime? asDate(dynamic v) =>
        v == null ? null : DateTime.tryParse('$v')?.toLocal();

    return PaymentConfirmation(
      id: json['id'] as int? ?? 0,
      bookingId: json['booking'] as int? ?? 0,
      bookingRef: '${json['booking_ref'] ?? ''}',
      bookingDate: '${json['booking_date'] ?? ''}',
      packageLabel: '${json['package_label'] ?? ''}',
      touristName: '${json['tourist_name'] ?? ''}',
      guideName: '${json['guide_name'] ?? ''}',
      method: PaymentMethodX.parse(json['payment_method'] as String?),
      reference: '${json['transaction_reference'] ?? ''}',
      screenshotUrl: '${json['screenshot_url'] ?? ''}',
      notes: '${json['notes'] ?? ''}',
      amount: asDouble(json['amount']),
      status: PaymentStatusX.parse(json['status'] as String?),
      guideComment: '${json['guide_comment'] ?? ''}',
      submittedAt: asDate(json['submitted_at']),
      resolvedAt: asDate(json['resolved_at']),
      receiptNo: '${json['receipt_no'] ?? ''}',
    );
  }

  bool get isPending => status == PaymentStatus.pending;
  bool get isConfirmed => status == PaymentStatus.confirmed;
  bool get isRejected => status == PaymentStatus.rejected;
}
