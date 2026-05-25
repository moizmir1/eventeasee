class EventPost {
  final String id;
  final String customerId;
  final String title;
  final String description;
  final String location;
  final String status; // 'open', 'accepted', 'completed'

  EventPost({
    required this.id,
    required this.customerId,
    required this.title,
    required this.description,
    required this.location,
    this.status = 'open',
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'title': title,
      'description': description,
      'location': location,
      'status': status,
      'createdAt': DateTime.now(),
    };
  }
}