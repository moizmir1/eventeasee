class Bid {
  final String providerId;
  final String eventId;
  final double amount;
  final String message;
  final DateTime createdAt;

  Bid({
    required this.providerId,
    required this.eventId,
    required this.amount,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'eventId': eventId,
      'amount': amount,
      'message': message,
      'createdAt': createdAt,
    };
  }
}