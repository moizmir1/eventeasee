import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:qr_flutter/qr_flutter.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List;

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
  final _emailController = TextEditingController(); // ✅ FIXED: Missing Email Controller Added
  final _phoneController = TextEditingController();

  final Map<String, TextEditingController> _dynamicControllers = {};
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _requiredCustomFields = [];
  bool _isLoading = true;
  int _ticketsSold = 0;
  int _maxSeats = 100;
  
  String _eventTitle = '';
  double _ticketPrice = 0.0;
  String _description = '';

  String _screenshotRule = 'None';
  bool _requireName = true;
  bool _requireEmail = false; // ✅ FIXED: Tracker for Email Switch
  bool _requirePhone = false;

  String _base64Screenshot = "";
  bool _isPickingImage = false;

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

        // 🚀 BACKEND FIX: Reading all dynamic explicit toggles from Firestore
        _screenshotRule = data['screenshotRule'] ?? 'None';
        _requireName = data['requireName'] ?? true;
        _requireEmail = data['requireEmail'] ?? false; // ✅ FIXED: Now fetching requireEmail from DB
        _requirePhone = data['requirePhone'] ?? false; // ✅ FIXED: Direct mapping to avoid checkbox state overlaps

        for (var field in _requiredCustomFields) {
          String titleKey = field['title'].toString();
          _dynamicControllers[titleKey] = TextEditingController();
        }
      }
    } catch (e) {
      debugPrint("Data fetching error: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickPaymentScreenshot() async {
    final ImagePicker picker = ImagePicker();
    final XFile? selectedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25);

    if (selectedImage != null) {
      setState(() => _isPickingImage = true);
      try {
        Uint8List dynamicBytes = await selectedImage.readAsBytes();
        String encodedText = base64Encode(dynamicBytes);
        
        setState(() {
          _base64Screenshot = "data:image/jpeg;base64,$encodedText";
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image Selection Error: $e"), backgroundColor: Colors.redAccent)
        );
      } finally {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _bookTicket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete the required registration fields."), backgroundColor: Colors.orangeAccent)
      );
      return;
    }

    // 🛑 SCREENSHOT VALIDATION FIX: Strictly checks if screenshot is mandatory but missing
    if (_screenshotRule == 'Mandatory' && _base64Screenshot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment confirmation receipt screenshot is strictly required!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_ticketsSold >= _maxSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration Closed! This event is completely Sold Out."), backgroundColor: Colors.redAccent)
      );
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
        'buyerName': _requireName ? _nameController.text.trim() : 'Attendee',
        'buyerEmail': _requireEmail ? _emailController.text.trim() : '',
        'buyerPhone': _requirePhone ? _phoneController.text.trim() : 'N/A',
        'responses': userAnswers, 
        'paymentScreenshot': _base64Screenshot,
        'isScanned': false, 
        'status': _screenshotRule == 'None' ? 'verified' : 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('ticketed_events').doc(widget.eventId).update({
        'ticketsSold': FieldValue.increment(1),
      });

      if (mounted) {
        Navigator.pop(context); // Close loading spinner
        
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
                        data: uniqueTicketId, 
                        version: QrVersions.auto,
                        gapless: false,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("System Failure: $e")));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose(); // ✅ FIXED: Properly disposing email controller
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
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment : CrossAxisAlignment.start,
            children: [
              // Event Details Top Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_eventTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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

              // 🚀 FRONTEND FIX: Dynamic visibility mapped perfectly to Firestore flags
              if (_requireName) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Full Name *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => v == null || v.trim().isEmpty ? "Name field is required" : null,
                ),
                const SizedBox(height: 12),
              ],
              
              // 🚀 FRONTEND FIX: Completely missing Email field added with UI injection layout
              if (_requireEmail) ...[
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email Address *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty ? "Email field is required" : null,
                ),
                const SizedBox(height: 12),
              ],
              
              // 🚀 FRONTEND FIX: Phone conditional logic works instantly on unchecked state
              if (_requirePhone) ...[
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: "Phone Contact Number *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_android_outlined)),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().isEmpty ? "Phone field is required" : null,
                ),
                const SizedBox(height: 12),
              ],
              
              // Host Custom Queries Section
              if (_requiredCustomFields.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
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

              // ================= 🚀 FIXED: PAYMENT SCREENSHOT PICKER PANEL =================
              if (_screenshotRule == 'Optional' || _screenshotRule == 'Mandatory') ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                Text(
                  "Payment Proof Transfer Receipt Screenshot ${_screenshotRule == 'Mandatory' ? '(Required *)' : '(Optional)'}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _isPickingImage ? null : _pickPaymentScreenshot,
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _base64Screenshot.isEmpty && _screenshotRule == 'Mandatory' 
                            ? Colors.redAccent 
                            : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                    ),
                    child: _isPickingImage
                        ? const Center(child: CircularProgressIndicator())
                        : _base64Screenshot.isNotEmpty
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(13),
                                    child: Image.memory(
                                      base64Decode(_base64Screenshot.split('base64,')[1]),
                                      width: double.infinity,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black87,
                                      radius: 16,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 16),
                                        onPressed: () => setState(() => _base64Screenshot = ""),
                                      ),
                                    ),
                                  )
                                ],
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, size: 40, color: Color(0xFF4F46E5)),
                                  SizedBox(height: 6),
                                  Text("Tap to upload money transfer confirmation screenshot", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.center),
                                  Text("(EasyPaisa / JazzCash / Bank Transfer)", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                  ),
                ),
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