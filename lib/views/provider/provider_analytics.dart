import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProviderAnalytics extends StatefulWidget {
  const ProviderAnalytics({super.key});

  @override
  State<ProviderAnalytics> createState() => _ProviderAnalyticsState();
}

class _ProviderAnalyticsState extends State<ProviderAnalytics> {
  final String _currentProviderId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _activeTimeframe = 'monthly'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Business Intelligence Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: _currentProviderId.isEmpty
          ? const Center(child: Text("No active session detected"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bids')
                  .where('providerId', isEqualTo: _currentProviderId)
                  .where('status', isEqualTo: 'accepted')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyAnalyticsState();
                }

                // --- DATA STORAGE & COMPUTATION PIPELINE ---
                double totalGrossRevenue = 0.0;
                double totalVerifiedCommissionPaid = 0.0;

                List<double> monthlyData = List.generate(12, (_) => 0.0);
                List<double> weeklyData = List.generate(5, (_) => 0.0); 

                DateTime rightNow = DateTime.now();

                for (var bidDoc in snapshot.data!.docs) {
                  var bidData = bidDoc.data() as Map<String, dynamic>;
                  double bidAmount = double.tryParse(bidData['amount'].toString()) ?? 0.0;
                  
                  totalGrossRevenue += bidAmount;

                  if (bidData['commissionLock'] == 'verified') {
                    totalVerifiedCommissionPaid += (bidAmount * 0.10);
                  }

                  if (bidData['createdAt'] != null) {
                    Timestamp ts = bidData['createdAt'] as Timestamp;
                    DateTime docDate = ts.toDate();
                    
                    // Populate Monthly Data (0-11 index)
                    if (docDate.month >= 1 && docDate.month <= 12) {
                      monthlyData[docDate.month - 1] += bidAmount;
                    }

                    // Populate Weekly Data for Current Month (0-4 index)
                    if (docDate.year == rightNow.year && docDate.month == rightNow.month) {
                      int calculatedWeek = ((docDate.day - 1) / 7).floor();
                      if (calculatedWeek > 4) calculatedWeek = 4;
                      weeklyData[calculatedWeek] += bidAmount;
                    }
                  }
                }

                List<double> activeDataset = _activeTimeframe == 'monthly' ? monthlyData : weeklyData;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 24),
                      
                      _buildMetricsGrid(totalGrossRevenue, totalVerifiedCommissionPaid),
                      const SizedBox(height: 28),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Financial Growth Curve", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                          _buildTimeframeSelector(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // 📈 SLICK RESPONSIVE CANVAS CARD
                      _buildPremiumChartCard(activeDataset),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _toggleChip("Yearly Trends", 'monthly'),
          _toggleChip("Weekly Split", 'detailed_month'),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, String code) {
    bool isSelected = _activeTimeframe == code;
    return GestureDetector(
      onTap: () => setState(() => _activeTimeframe = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B))),
      ),
    );
  }

  // 💎 INFRASTRUCTURE: HIGH-FIDELITY AUTOMATED PERFORMANCE CHART CARD
  Widget _buildPremiumChartCard(List<double> dataset) {
    bool isMonthly = _activeTimeframe == 'monthly';
    List<String> labels = isMonthly 
        ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        : ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5"];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Bounded Layout safely encapsulating the vector canvas painters
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: ChartVectorPainter(points: dataset),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // Bounded Horizontal Axis Row Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((l) => Expanded(
              child: Text(
                l,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(double gross, double commission) {
    return Row(
      children: [
        Expanded(child: _buildStatCard("Gross Intake", "Rs. ${gross.toStringAsFixed(0)}", const Color(0xFF6366F1), Icons.insights_rounded)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard("Platform Dues", "Rs. ${commission.toStringAsFixed(0)}", const Color(0xFF10B981), Icons.verified_user_rounded)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Business Intelligence Insights", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.5)),
        Text("Real-time responsive transactional financial growth scales.", style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEmptyAnalyticsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No confirmed contractual streams tracked yet.", style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

// 🎨 HIGH PROFILE VECTOR PAINTER ENGINE (ZERO OVERFLOW / 100% RESPONSIVE SMART BARS)
class ChartVectorPainter extends CustomPainter {
  final List<double> points;
  ChartVectorPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    double maxVal = points.fold(100.0, (max, e) => e > max ? e : max);
    if (maxVal == 0) maxVal = 100.0;

    // 1. Draw Grid Background Lines
    Paint gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    int totalGridLines = 4;
    for (int i = 0; i < totalGridLines; i++) {
      double yCoord = size.height * (i / (totalGridLines - 1));
      canvas.drawLine(Offset(0, yCoord), Offset(size.width, yCoord), gridPaint);
    }

    // 2. Compute Vectors Layout coordinates mapping array models safely
    double segmentWidth = size.width / (points.length - 1 == 0 ? 1 : points.length - 1);
    List<Offset> coordinateOffsets = [];

    for (int idx = 0; idx < points.length; idx++) {
      double xPos = idx * segmentWidth;
      // Invert Y coordinate calculation system matching native graphic matrix layouts
      double normalizedRatio = points[idx] / maxVal;
      double yPos = size.height - (normalizedRatio * (size.height - 20)); // Bounded 20px padding protection
      coordinateOffsets.add(Offset(xPos, yPos));
    }

    // 3. Render Smooth Solid Connecting Trend Curves
    Paint linePaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Path trendLinePath = Path();
    trendLinePath.moveTo(coordinateOffsets[0].dx, coordinateOffsets[0].dy);

    for (int k = 0; k < coordinateOffsets.length - 1; k++) {
      // Linear path segments parsing logic models safely
      trendLinePath.lineTo(coordinateOffsets[k + 1].dx, coordinateOffsets[k + 1].dy);
    }
    canvas.drawPath(trendLinePath, linePaint);

    // 4. Highlight Nodes with Interactive Accent Points
    Paint dotOuterRingPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    Paint dotInnerCorePaint = Paint()..color = const Color(0xFF4F46E5)..style = PaintingStyle.fill;

    for (var currentPoint in coordinateOffsets) {
      // Draw outer circle insulation rings
      canvas.drawCircle(currentPoint, 6, dotOuterRingPaint);
      canvas.drawCircle(currentPoint, 6, linePaint..style = PaintingStyle.stroke..strokeWidth = 2);
      // Draw centralized core nodes values
      canvas.drawCircle(currentPoint, 3, dotInnerCorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ChartVectorPainter oldDelegate) => oldDelegate.points != points;
}