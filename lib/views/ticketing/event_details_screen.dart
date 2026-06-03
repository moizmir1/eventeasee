import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:qr_flutter/qr_flutter.dart'; // Ensure 'flutter pub add qr_flutter' is run in terminal

class EventDetailsScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic>? eventData;

  const EventDetailsScreen({
    super.key, 
    required this.eventId, 
    this.eventData,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Dynamic input controller mappings
  final Map<String, TextEditingController> _dynamicControllers = {};
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _requiredCustomFields = [];
  bool _isLoading = true;
  int _ticketsSold = 0;
  int _maxSeats = 100;
  
  String _eventTitle = '';
  double _ticketPrice = 0.0;
  String _description = '';

  @override
  void initState() {
    super.initState();
    _fetchLatestEventSpecs();
  }

  void _fetchLatestEventSpecs() async {
    try {
      var freshSnap = await FirebaseFirestore.instance.collection('ticketed_events').doc(widget.eventId).get();
      if (freshSnap.exists) {
        var data = freshSnap.data() as Map<String, dynamic>;
        
        List<dynamic> fields = data['customFields'] ?? [];
        _requiredCustomFields = fields.map((e) => Map<String, dynamic>.from(e)).toList();
        
        _ticketsSold = data['ticketsSold'] ?? 0;
        _maxSeats = data['maxSeats'] ?? 100;
        
        _eventTitle = data['eventName'] ?? widget.eventData?['eventName'] ?? 'Ticketed Event';
        _ticketPrice = double.tryParse(data['price'].toString()) ?? 0.0;
        _description = data['description'] ?? widget.eventData?['description'] ?? '';

        for (var field in _requiredCustomFields) {
          String titleKey = field['title'].toString();
          _dynamicControllers[titleKey] = TextEditingController();
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _bookTicket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please complete the required registration questions.")));
      return;
    }

    if (_ticketsSold >= _maxSeats) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Closed! This event is completely Sold Out."), backgroundColor: Colors.redAccent));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      Map<String, String> userAnswers = {};
      _dynamicControllers.forEach((key, controller) {
        userAnswers[key] = controller.text.trim();
      });

      String uniqueTicketId = "TK-${Random().nextInt(900000) + 100000}";

      await FirebaseFirestore.instance.collection('tickets').doc(uniqueTicketId).set({
        'ticketId': uniqueTicketId,
        'eventId': widget.eventId,
        'buyerId': user.uid,
        'buyerName': _nameController.text.trim(),
        'buyerPhone': _phoneController.text.trim(),
        'responses': userAnswers, 
        'isScanned': false, 
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('ticketed_events').doc(widget.eventId).update({
        'ticketsSold': FieldValue.increment(1),
      });

      if (mounted) {
        Navigator.pop(context); // Close registration spinner safely
        
        // 🚨 LIVE RENDER POPUP DIALOG FOR REALTIME GENERATED QR CODES
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Column(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 45),
                SizedBox(height: 8),
                Text("Pass Generated! 🎉", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Scan this custom pass code matrix at the entrance checkpoint terminal line.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // QR IMAGE CANVAS BOX VIEWBOUNDS TERMINAL
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: QrImageView(
                        data: uniqueTicketId, // Encodes runtime TK key perfectly
                        version: QrVersions.auto,
                        gapless: false,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  Text(
                    "Ticket ID: $uniqueTicketId", 
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), letterSpacing: 0.5)
                  ),
                ],
              ),
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(dCtx);
                    Navigator.pop(context);
                  },
                  child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Transaction system failure: $e")));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dynamicControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    bool isSoldOut = _ticketsSold >= _maxSeats;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_eventTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_eventTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w100, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Text(_description, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4)),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Pass Cost", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text(_ticketPrice > 0 ? "Rs. $_ticketPrice" : "FREE ENTRY", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF6366F1))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSoldOut ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20)
                          ),
                          child: Text(
                            isSoldOut ? "SOLD OUT" : "Availability: ${_maxSeats - _ticketsSold} / $_maxSeats Seats Left",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isSoldOut ? Colors.red : const Color(0xFF2563EB)),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 25),
              const Text("Attendee Registration Form", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v == null || v.trim().isEmpty ? "Name parameter required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Phone Contact Number *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_android_outlined)),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.trim().isEmpty ? "Contact vector required" : null,
              ),
              
              if (_requiredCustomFields.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text("Additional Host Queries (${_requiredCustomFields.length})", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _requiredCustomFields.length,
                  itemBuilder: (context, idx) {
                    var fieldData = _requiredCustomFields[idx];
                    String queryTitle = fieldData['title'].toString();
                    bool isMandatory = fieldData['isRequired'] ?? true; 
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextFormField(
                        controller: _dynamicControllers[queryTitle],
                        decoration: InputDecoration(
                          labelText: isMandatory ? "$queryTitle *" : "$queryTitle (Optional)",
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(Icons.help_outline_rounded, color: isMandatory ? const Color(0xFF6366F1) : Colors.grey),
                        ),
                        validator: (v) {
                          if (isMandatory && (v == null || v.trim().isEmpty)) {
                            return "This field is required";
                          }
                          return null; 
                        },
                      ),
                    );
                  }
                )
              ],

              const SizedBox(height: 35),
              ElevatedButton(
                onPressed: isSoldOut ? null : _bookTicket,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(55),
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                ),
                child: Text(isSoldOut ? "REGISTRATION CLOSED (SOLD OUT)" : "Generate Entrance QR Pass", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}