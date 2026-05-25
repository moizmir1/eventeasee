import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuestListScreen extends StatelessWidget {
  final String eventId;
  final String eventName;

  const GuestListScreen({super.key, required this.eventId, required this.eventName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Guests: $eventName")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .where('eventId', isEqualTo: eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No guests registered yet."));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              bool isScanned = data['isScanned'] ?? false;

              return ListTile(
                leading: CircleAvatar(child: Text("${index + 1}")),
                title: Text(data['guestName'] ?? 'Unknown'),
                subtitle: Text("Phone: ${data['guestPhone'] ?? 'N/A'}"),
                trailing: Icon(
                  isScanned ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isScanned ? Colors.green : Colors.grey,
                ),
              );
            },
          );
        },
      ),
    );
  }
}