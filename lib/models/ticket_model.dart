class Ticket {
  final String ticketId;
  final String eventName;
  final String ownerName;
  final bool isScanned; // This tracks "Used / Not Used"

  Ticket({
    required this.ticketId,
    required this.eventName,
    required this.ownerName,
    this.isScanned = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventName': eventName,
      'ownerName': ownerName,
      'isScanned': isScanned,
      'timestamp': DateTime.now(),
    };
  }
}