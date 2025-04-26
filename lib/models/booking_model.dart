class BookingModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String servicePersonId;
  final String serviceId;
  final String serviceName;
  final int serviceDate; // Changed to int to store milliseconds timestamp
  final String status;
  final double serviceCharge;
  final double travelCharge;
  final double totalAmount;
  final String doorNumber;
  final String address;
  final String landmark;
  final String timeSlot;
  final DateTime bookingDate;
  final String transactionId;
  final double? amount; // Added amount as double?

  BookingModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.servicePersonId,
    required this.serviceId,
    required this.serviceName,
    required this.serviceDate,
    required this.status,
    required this.serviceCharge,
    required this.travelCharge,
    required this.totalAmount,
    required this.doorNumber,
    required this.address,
    required this.landmark,
    required this.timeSlot,
    required this.bookingDate,
    required this.transactionId,
    this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'servicePersonId': servicePersonId,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'serviceDate': serviceDate,
      'status': status,
      'serviceCharge': serviceCharge,
      'travelCharge': travelCharge,
      'totalAmount': totalAmount,
      'doorNumber': doorNumber,
      'address': address,
      'landmark': landmark,
      'timeSlot': timeSlot,
      'bookingDate': bookingDate.millisecondsSinceEpoch,
      'transactionId': transactionId,
      'amount': amount,
    };
  }

  String get formattedDate {
    final date = DateTime.fromMillisecondsSinceEpoch(serviceDate);
    return "${date.day}/${date.month}/${date.year}";
  }

  static BookingModel fromJson(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      servicePersonId: map['servicePersonId'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? '',
      serviceDate: map['serviceDate'] ?? 0,
      status: map['status'] ?? '',
      serviceCharge: (map['amount'] ?? 0.0).toDouble(), // Use amount for serviceCharge
      travelCharge: (map['travelCharge'] ?? 0.0).toDouble(),
      totalAmount: (map['amount'] ?? 0.0).toDouble(), // Use amount for totalAmount
      doorNumber: map['doorNumber'] ?? '',
      address: map['address'] ?? '',
      landmark: map['landmark'] ?? '',
      timeSlot: map['timeSlot'] ?? '',
      bookingDate: DateTime.fromMillisecondsSinceEpoch(map['bookingDate'] ?? 0),
      transactionId: map['transactionId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(), // Set amount directly
    );
  }
}
