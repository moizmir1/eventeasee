import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String eventId;
  final String providerId;
  final String providerName;

  const ChatScreen({
    super.key,
    required this.eventId,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _chatRoomId = '';
  String _warningMessage = ''; 

  @override
  void initState() {
    super.initState();
    _chatRoomId = "${widget.eventId}_${widget.providerId}";
    _markMessagesAsRead();
    _checkUserBanStatus();
  }

  // 🚀 SYNCHRONIZED CENTRAL BAN STATE AUDITOR
  void _checkUserBanStatus() async {
    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
      // 🛠️ FIXED: Changed matching parameter field string from 'isBanned' to 'isBlocked'
      if (userDoc.exists && userDoc.data()?['isBlocked'] == true) {
        _executeBanSequence();
      }
    } catch (_) {}
  }

  void _executeBanSequence() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text("Account Terminated", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text("Your profile has been permanently banned from Event Easee for multiple attempts of sharing contact data during negotiation phase."),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                // Force logout immediately to clear device cache tokens dynamically
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text("Exit Application", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  void _markMessagesAsRead() async {
    try {
      var unreadMessages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .where('senderId', isNotEqualTo: _currentUid)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadMessages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (_) {}
  }

  bool _containsPersonalInformation(String text) {
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final phoneRegex = RegExp(r'(?:\+92|92|0)?(?:3\d{2})(?:[ -]?\d{7})|(?:\b\d{7,12}\b)');

    return emailRegex.hasMatch(text) || phoneRegex.hasMatch(text);
  }

  void _sendMessage() async {
    String txt = _messageController.text.trim();
    if (txt.isEmpty) return;

    var eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
    String currentStatus = (eventDoc.data()?['status'] ?? 'open').toString().toLowerCase();

    if (currentStatus == 'open' && _containsPersonalInformation(txt)) {
      _messageController.clear();
      
      try {
        var userRef = FirebaseFirestore.instance.collection('users').doc(_currentUid);
        var userSnap = await userRef.get();
        int currentAttempts = (userSnap.data()?['leakageAttempts'] ?? 0) + 1;

        await FirebaseFirestore.instance.collection('admin_alerts').add({
          'userId': _currentUid,
          'chatRoomId': _chatRoomId,
          'eventId': widget.eventId,
          'blockedContent': txt,
          'attemptIndex': currentAttempts,
          'timestamp': Timestamp.now(),
        });

        if (currentAttempts >= 3) {
          // 🚀 SYNCHRONIZED UPDATE PIPELINE INJECTING BOTH FIELD MARKS AND ACTION REASONS
          await userRef.update({
            'isBlocked': true, // 🛠️ Changed to centralized key string parameter
            'leakageAttempts': currentAttempts,
            'banReason': 'Automated Chat Rules Breach (3 Personal Credentials Warnings Exceeded)'
          });
          _executeBanSequence();
          return;
        } else {
          await userRef.update({'leakageAttempts': currentAttempts});
          setState(() {
            _warningMessage = "Warning ($currentAttempts/3): Direct contact sharing is blocked until proposal acceptance! 3 infractions will ban your account.";
          });
          
          Future.delayed(const Duration(seconds: 6), () {
            if (mounted) setState(() => _warningMessage = '');
          });
        }
      } catch (_) {}
      return;
    }

    _messageController.clear();

    await FirebaseFirestore.instance.collection('chats').doc(_chatRoomId).set({
      'eventId': widget.eventId,
      'providerId': widget.providerId,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatRoomId)
        .collection('messages')
        .add({
      'senderId': _currentUid,
      'text': txt,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
      builder: (context, eventSnapshot) {
        if (eventSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        var eData = eventSnapshot.data?.data() as Map<String, dynamic>?;
        String eventTitle = eData?['title'] ?? 'Chat Portal';
        String currentStatus = (eData?['status'] ?? 'open').toString().toLowerCase();
        String projectStatus = eData?['projectStatus'] ?? 'ongoing';
        bool isProjectCompleted = projectStatus == 'completed';

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF), 
                  child: Icon(Icons.handshake_rounded, color: Color(0xFF6366F1), size: 18)
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eventTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(
                        isProjectCompleted 
                            ? "Contract Closed ✔" 
                            : (currentStatus == 'accepted')
                                ? "Deal Active • Processing ⏳"
                                : "Proposal Stage • Discussion 💬",
                        style: TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.bold, 
                          color: isProjectCompleted ? Colors.green : (currentStatus == 'accepted' ? Colors.orange : Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              if (_warningMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    border: Border(
                      bottom: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.report_problem_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _warningMessage,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.bold, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(_chatRoomId)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    var messages = snapshot.hasData ? snapshot.data!.docs : [];

                    if (messages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            "Secure line connected. Start text consultation...", 
                            style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, 
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var mDoc = messages[index];
                        var mData = mDoc.data() as Map<String, dynamic>;
                        bool isMe = mData['senderId'] == _currentUid;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF6366F1) : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                              ),
                            ),
                            child: Text(
                              mData['text'] ?? '',
                              style: TextStyle(color: isMe ? Colors.white : const Color(0xFF1E293B), fontSize: 14),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              if (isProjectCompleted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.amber.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_clock_rounded, color: Colors.amber.shade800, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        "Chat locked as Read-Only. Project has been completed.",
                        style: TextStyle(color: Color(0xFF78350F), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.white,
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: "Type message or details...",
                              hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                              fillColor: const Color(0xFFF1F5F9),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30), 
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: const Color(0xFF6366F1),
                          radius: 22,
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            onPressed: _sendMessage,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}