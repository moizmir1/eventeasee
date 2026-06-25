import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:flutter/services.dart'; 

class CreateTicketedEvent extends StatefulWidget {
  const CreateTicketedEvent({super.key});

  @override
  State<CreateTicketedEvent> createState() => _CreateTicketedEventState();
}

class _CreateTicketedEventState extends State<CreateTicketedEvent> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final descController = TextEditingController();
  final seatsController = TextEditingController(); 
  final customFieldController = TextEditingController(); 

  List<Map<String, dynamic>> userDefinedFields = []; 
  bool _isFieldRequired = true; 
  String _screenshotRule = 'None'; 

  // 🚀 NEW: Core Fields Toggle Switches
  bool _requireNameField = true;
  bool _requireEmailField = false;
  bool _requirePhoneField = false;

  void _addCustomField() {
    String fieldTitle = customFieldController.text.trim();
    if (fieldTitle.isEmpty) return;
    
    bool exists = userDefinedFields.any((element) => element['title'].toString().toLowerCase() == fieldTitle.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This question has already been added!")));
      return;
    }

    setState(() {
      userDefinedFields.add({
        'title': fieldTitle,
        'isRequired': _isFieldRequired,
      });
      customFieldController.clear();
      _isFieldRequired = true; 
    });
  }

  void _removeCustomField(int index) {
    setState(() => userDefinedFields.removeAt(index));
  }

  void _createEvent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || nameController.text.trim().isEmpty || seatsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event name and maximum capacity are strictly required!")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String shortId = "";
      bool isUnique = false;

      while (!isUnique) {
        shortId = "EV-${Random().nextInt(900000) + 100000}";
        var duplicateCheck = await FirebaseFirestore.instance
            .collection('ticketed_events')
            .where('shortId', isEqualTo: shortId)
            .limit(1)
            .get();
        
        if (duplicateCheck.docs.isEmpty) {
          isUnique = true;
        }
      }

      int allocatedSeats = int.tryParse(seatsController.text.trim()) ?? 50;

      await FirebaseFirestore.instance.collection('ticketed_events').add({
        'organizerId': user.uid,
        'eventName': nameController.text.trim(),
        'price': double.tryParse(priceController.text.trim()) ?? 0.0,
        'description': descController.text.trim(),
        'maxSeats': allocatedSeats,
        'ticketsSold': 0, 
        'customFields': userDefinedFields, 
        'screenshotRule': _screenshotRule, 
        'shortId': shortId,
        // 🚀 Saving Core Field Toggles to Firestore Pipeline
        'requireName': _requireNameField,
        'requireEmail': _requireEmailField,
        'requirePhone': _requirePhoneField,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context); 

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Event is Live! 🚀", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Share this short ID with buyers to register details and join lines:"),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        shortId, 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFF4F46E5)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: shortId));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event Code Copied to Clipboard!")));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                onPressed: () { 
                  Navigator.pop(context); 
                  Navigator.pop(context); 
                }, 
                child: const Text("Done")
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error launching event line: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Configure Ticketed Event", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Core Event Specs", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 10),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Event Title Name", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: priceController, decoration: const InputDecoration(labelText: "Ticket Cost (Rs.)", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: seatsController, decoration: const InputDecoration(labelText: "Total Capacity Seats", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(labelText: "Event Details Description", border: OutlineInputBorder())),
            
            const SizedBox(height: 25),
            const Text("Payment Verification Settings", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _screenshotRule,
              decoration: const InputDecoration(
                labelText: "Payment Proof Screenshot Mode",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF4F46E5)),
              ),
              items: const [
                DropdownMenuItem(value: 'None', child: Text('Not Required (Automatic Approval)')),
                DropdownMenuItem(value: 'Optional', child: Text('Optional Upload (As per Customer choice)')),
                DropdownMenuItem(value: 'Mandatory', child: Text('Mandatory (Block tickets until uploaded)')),
              ],
              onChanged: (val) {
                setState(() {
                  _screenshotRule = val ?? 'None';
                });
              },
            ),

            // ================= 🚀 NEW: SELECT REQUIRED ATTENDEE FIELDS =================
            const SizedBox(height: 25),
            const Text("Select Required Fields for Attendee", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text("Full Name", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    activeColor: const Color(0xFF4F46E5),
                    value: _requireNameField,
                    onChanged: (val) => setState(() => _requireNameField = val ?? true),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  CheckboxListTile(
                    title: const Text("Email Address", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    activeColor: const Color(0xFF4F46E5),
                    value: _requireEmailField,
                    onChanged: (val) => setState(() => _requireEmailField = val ?? false),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  CheckboxListTile(
                    title: const Text("Mobile Phone Number", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    activeColor: const Color(0xFF4F46E5),
                    value: _requirePhoneField,
                    onChanged: (val) => setState(() => _requirePhoneField = val ?? false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            const Text("Dynamic Form Builder (Extra Questions)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customFieldController,
                    decoration: const InputDecoration(hintText: "e.g., CNIC Number, T-Shirt Size", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(55, 55), backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _addCustomField,
                  child: const Icon(Icons.add),
                )
              ],
            ),
            
            Row(
              children: [
                Checkbox(
                  value: _isFieldRequired, 
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) => setState(() => _isFieldRequired = val ?? true)
                ),
                const Text("Mark this custom question as Required (*)", style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
              ],
            ),
            
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(userDefinedFields.length, (index) {
                var item = userDefinedFields[index];
                bool req = item['isRequired'] ?? true;
                return Chip(
                  backgroundColor: req ? const Color(0xFFEEF2F6) : const Color(0xFFF1F5F9),
                  label: Text(
                    "${item['title']} ${req ? '*' : '(Optional)'}", 
                    style: TextStyle(fontWeight: FontWeight.bold, color: req ? const Color(0xFF4F46E5) : const Color(0xFF64748B))
                  ),
                  deleteIcon: const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                  onDeleted: () => _removeCustomField(index),
                );
              }),
            ),
            
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _createEvent, 
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55), backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Launch Live Event Hub", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}