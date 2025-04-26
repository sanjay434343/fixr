class PaymentModel {
  final String id;
  final String bookingId;
  final String userId;
  final double amount;
  final double serviceCharge;
  final double travelCharge;
  final double appCharge;
  final String status;
  final String paymentMethod;
  final DateTime timestamp;
  final String transactionId;
  final Map<String, dynamic>? metadata;

  PaymentModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.amount,
    required this.serviceCharge,
    required this.travelCharge,
    required this.appCharge,
    required this.status,
    required this.paymentMethod,
    required this.timestamp,
    required this.transactionId,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'userId': userId,
      'amount': amount,
      'serviceCharge': serviceCharge,
      'travelCharge': travelCharge,
      'appCharge': appCharge,
      'status': status,
      'paymentMethod': paymentMethod,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'transactionId': transactionId,
      'metadata': metadata,
    };
  }

  factory PaymentModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentModel(
      id: id,
      bookingId: map['bookingId'] ?? '',
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      serviceCharge: (map['serviceCharge'] ?? 0).toDouble(),
      travelCharge: (map['travelCharge'] ?? 0).toDouble(),
      appCharge: (map['appCharge'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      transactionId: map['transactionId'] ?? '',
      metadata: map['metadata'],
    );
  }
}
