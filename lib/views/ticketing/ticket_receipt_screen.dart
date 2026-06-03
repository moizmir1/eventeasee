import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Universal html conditional import configuration safety rules
import 'dart:typed_data';

class TicketReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> eventData; 
  final Map<String, dynamic> ticketData; 

  const TicketReceiptScreen({
    super.key,
    required this.eventData,
    required this.ticketData,
  });

  @override
  State<TicketReceiptScreen> createState() => _TicketReceiptScreenState();
}

class _TicketReceiptScreenState extends State<TicketReceiptScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  void _downloadTicketAsImage() async {
    try {
      String ticketDocId = widget.ticketData['ticketId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = "Ticket_$ticketDocId.png";

      if (kIsWeb) {
        final Uint8List? imageBytes = await _screenshotController.capture();
        if (imageBytes != null) {
        //   final blob = html.Blob([imageBytes]);
        //   final url = html.Url.createObjectUrlFromBlob(blob);
        //   final anchor = html.AnchorElement(href: url)
        //     ..setAttribute("download", fileName)
        //     ..click();
        //   html.Url.revokeObjectUrl(url);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: Color(0xFF10B981),
                content: Text("Ticket Pass downloaded via Browser Downloads!"),
              ),
            );
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        await _screenshotController.captureAndSave(
          directory.path,
          fileName: fileName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF10B981),
              content: Text("Ticket Pass downloaded safely to Documents!"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download Error: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String gName = widget.ticketData['guestName'] ?? 'Guest';
    String gPhone = widget.ticketData['guestPhone'] ?? 'N/A';
    String eName = widget.ticketData['eventName'] ?? (widget.eventData['eventName'] ?? 'Welcome Event');
    String shortId = widget.eventData['shortId'] ?? 'EV-MAIN';
    String ticketIdForQR = widget.ticketData['ticketId'] ?? 'NO-ID';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: AppBar(
        title: const Text("Digital Gate Pass", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440), 
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- THE CAPTURED CARD INTERFACE CONTAINER ---
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Badge Line
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "OFFICIAL ATTENDEE PASS",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Color(0xFF6366F1)),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "ID: $shortId",
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                        ),

                        // Big Bold Event Title
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            eName,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.8),
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5, height: 1),
                        ),

                        // Balanced Metadata Grid
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 5, child: _buildDetailColumn("ATTENDEE NAME", gName)),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 5, child: _buildDetailColumn("GUEST PHONE", gPhone)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 5, child: _buildDetailColumn("DATE & TIMINGS", widget.eventData['eventDate'] ?? 'Date Pending')),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 5, child: _buildDetailColumn("LOCATION/VENUE", widget.eventData['eventLocation'] ?? 'Venue Premises')),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // --- FIX: PREMIUM CUSTOM DASHED LINE NOTCH SEPARATOR ---
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Container(width: 10, height: 20, decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)))),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Flex(
                                    direction: Axis.horizontal,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      (constraints.constrainWidth() / 10).floor(),
                                      (_) => SizedBox(width: 6, height: 1.5, child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey[300]))),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(width: 10, height: 20, decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)))),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // QR Engine Core Centered Section
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                            ),
                            child: QrImageView(
                              data: ticketIdForQR,
                              version: QrVersions.auto,
                              size: 140.0,
                              gapless: false,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            "Scan at entrance gate for instant validation",
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600, letterSpacing: 0.2),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Premium Sticky Action Submit Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.download_for_offline_rounded, size: 20),
                  label: const Text("Download Digital Ticket", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _downloadTicketAsImage,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Text(
          value, 
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155), height: 1.25), 
          maxLines: 2, 
          overflow: TextOverflow.ellipsis
        ),
      ],
    );
  }
}