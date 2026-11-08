import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../models/rider_model.dart';
import '../../services/api_service.dart';

class AdminRiderHistoryScreen extends StatefulWidget {
  const AdminRiderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AdminRiderHistoryScreen> createState() => _AdminRiderHistoryScreenState();
}

class _AdminRiderHistoryScreenState extends State<AdminRiderHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<OrderModel> _allHistory = [];
  List<RiderModel> _riders = [];
  bool _isLoading = true;

  // Advanced Filters
  String _searchQuery = '';
  String _selectedRiderId = 'all';
  String _selectedStatus = 'all'; // 'all', 'DELIVERED', 'CANCELLED'
  String _selectedTimeRange = 'all'; // 'all', 'today', 'yesterday', 'week', 'month', 'custom_month'
  String _selectedSort = 'newest'; // 'newest', 'oldest', 'fare_high'
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final ridersFuture = _apiService.getAdminRiders();
      final historyFuture = _apiService.getAdminRiderHistory(
        riderId: _selectedRiderId == 'all' ? null : _selectedRiderId,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );

      final results = await Future.wait([ridersFuture, historyFuture]);

      if (mounted) {
        setState(() {
          _riders = results[0] as List<RiderModel>;
          _allHistory = results[1] as List<OrderModel>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<OrderModel> get _filteredHistory {
    final now = DateTime.now();
    return _allHistory.where((order) {
      // Status
      if (_selectedStatus != 'all' && order.status != _selectedStatus) {
        return false;
      }
      // Rider
      if (_selectedRiderId != 'all') {
        final assignedId = order.assignedRiderId;
        if (assignedId != _selectedRiderId) return false;
      }
      // Time Range
      if (_selectedTimeRange == 'today') {
        final isToday = order.createdAt.year == now.year &&
            order.createdAt.month == now.month &&
            order.createdAt.day == now.day;
        if (!isToday) return false;
      } else if (_selectedTimeRange == 'yesterday') {
        final yesterday = now.subtract(const Duration(days: 1));
        final isYesterday = order.createdAt.year == yesterday.year &&
            order.createdAt.month == yesterday.month &&
            order.createdAt.day == yesterday.day;
        if (!isYesterday) return false;
      } else if (_selectedTimeRange == 'week') {
        final diff = now.difference(order.createdAt).inDays;
        if (diff > 7) return false;
      } else if (_selectedTimeRange == 'month') {
        final isThisMonth = order.createdAt.year == now.year &&
            order.createdAt.month == now.month;
        if (!isThisMonth) return false;
      } else if (_selectedTimeRange == 'custom_month') {
        final isCustomMonth = order.createdAt.year == _selectedYear &&
            order.createdAt.month == _selectedMonth;
        if (!isCustomMonth) return false;
      }
      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchNum = order.orderNumber.toLowerCase().contains(q);
        final matchCust = order.customerName.toLowerCase().contains(q);
        final matchPhone = order.customerPhone.contains(q);
        final matchRider = (order.riderName ?? '').toLowerCase().contains(q);
        final matchDrop = order.dropAddress.toLowerCase().contains(q);
        if (!matchNum && !matchCust && !matchPhone && !matchRider && !matchDrop) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        if (_selectedSort == 'fare_high') return b.fare.compareTo(a.fare);
        if (_selectedSort == 'oldest') return a.createdAt.compareTo(b.createdAt);
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  Future<void> _pickParticularMonth() async {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    final picked = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('Select Particular Month', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter all delivery orders, cash and UPI collections by month.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      value: tempMonth,
                      decoration: InputDecoration(
                        labelText: 'Month',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: List.generate(12, (i) => i + 1).map((m) {
                        return DropdownMenuItem<int>(
                          value: m,
                          child: Text(_getMonthName(m), style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDlgState(() => tempMonth = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      value: tempYear,
                      decoration: InputDecoration(
                        labelText: 'Year',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [2025, 2026, 2027].map((y) {
                        return DropdownMenuItem<int>(
                          value: y,
                          child: Text('$y', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDlgState(() => tempYear = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply Filter'),
            ),
          ],
        ),
      ),
    );

    if (picked == true) {
      setState(() {
        _selectedMonth = tempMonth;
        _selectedYear = tempYear;
        _selectedTimeRange = 'custom_month';
      });
      _fetchData();
    }
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('tel:$clean');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredHistory;
    final deliveredOnly = filtered.where((o) => o.status == 'DELIVERED').toList();
    final cancelledOnly = filtered.where((o) => o.status == 'CANCELLED').toList();
    final totalEarned = deliveredOnly.fold<int>(0, (sum, o) => sum + o.fare);
    final cashEarned = deliveredOnly
        .where((o) => o.paymentMode.toUpperCase() != 'UPI')
        .fold<int>(0, (sum, o) => sum + o.fare);
    final upiEarned = deliveredOnly
        .where((o) => o.paymentMode.toUpperCase() == 'UPI')
        .fold<int>(0, (sum, o) => sum + o.fare);
    final avgFare = deliveredOnly.isNotEmpty ? (totalEarned / deliveredOnly.length).round() : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Colors.white,
            child: Column(
              children: [
                // Summary Stats Row & Collection Breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.history_edu_rounded, size: 16, color: Color(0xFF15803D)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${filtered.length} ARCHIVED TRIPS',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Text(
                      'Total: ₹$totalEarned',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Financial Collection Breakdown Chips (Total Volume, Cash Handover, UPI Received)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('💵 Cash Handover', style: TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('₹$cashEarned', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                        ],
                      ),
                      Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
                      Column(
                        children: [
                          const Text('📱 UPI Received', style: TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('₹$upiEarned', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8))),
                        ],
                      ),
                      Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
                      Column(
                        children: [
                          Text('Delivered / Cancel', style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('${deliveredOnly.length} / ${cancelledOnly.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Search Box
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search archive by Order #, Customer, Rider, Landmark...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(height: 8),

                // Dropdown Filters Row
                Row(
                  children: [
                    // Rider Selector
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRiderId,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('All Fleet Riders')),
                              ..._riders.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRiderId = val);
                                _fetchData();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Status Selector
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Status')),
                              DropdownMenuItem(value: 'DELIVERED', child: Text('Delivered')),
                              DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStatus = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Time Range Selector with Custom Month Picker
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTimeRange,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('All Time')),
                              const DropdownMenuItem(value: 'today', child: Text('Today (Day)')),
                              const DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
                              const DropdownMenuItem(value: 'week', child: Text('This Week')),
                              const DropdownMenuItem(value: 'month', child: Text('This Month')),
                              DropdownMenuItem(
                                value: 'custom_month',
                                child: Text('📅 ${_getMonthName(_selectedMonth).substring(0, 3)} $_selectedYear'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val == 'custom_month') {
                                _pickParticularMonth();
                              } else if (val != null) {
                                setState(() => _selectedTimeRange = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // History List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
                : filtered.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _fetchData,
                        child: ListView(
                          padding: const EdgeInsets.all(32),
                          children: const [
                            SizedBox(height: 60),
                            Center(child: Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8))),
                            SizedBox(height: 16),
                            Text(
                              'No Matching Closed Trips',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Delivered and cancelled trips move automatically into this history archive.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final order = filtered[index];
                            return _buildModernHistoryCard(order);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHistoryCard(OrderModel order) {
    final isDelivered = order.status == 'DELIVERED';
    final hasRider = order.assignedRider != null && order.riderName != null;
    final isBuy = order.orderType == 'BUY_FOR_ME';

    return InkWell(
      onTap: () => _showOrderFullDetailsSheet(order),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDelivered ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDelivered ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDelivered ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              size: 12,
                              color: isDelivered ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDelivered ? 'DELIVERED' : 'CANCELLED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isDelivered ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A))),
                    ],
                  ),
                  Text(
                    '₹${order.fare}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isDelivered ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service & Category
                  Row(
                    children: [
                      Icon(
                        isBuy ? Icons.shopping_bag_outlined : Icons.inventory_2_outlined,
                        size: 13,
                        color: const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isBuy
                              ? 'Buy For Me (${(order.shopName != null && order.shopName!.isNotEmpty) ? order.shopName : order.category})'
                              : 'Pick & Deliver (${order.category})',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rider Section
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDelivered ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.two_wheeler_rounded, size: 18, color: isDelivered ? const Color(0xFF2563EB) : const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasRider ? 'Fulfilled by: ${order.riderName}' : 'No Rider Assigned',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                            ),
                            if (hasRider && order.riderPhone != null)
                              Text(order.riderPhone!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      if (hasRider && order.riderPhone != null)
                        IconButton(
                          icon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF0284C7)),
                          onPressed: () => _callPhone(order.riderPhone),
                          tooltip: 'Call Rider',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Customer & Drop Address
                  Text(
                    'Customer: ${order.customerName} (${order.customerPhone})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 4),
                  Text('Delivery Landmark: ${order.dropAddress}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  if (order.itemsList.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Items: ${order.itemsList.join(", ")}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  ],
                  const SizedBox(height: 8),

                  // Footer with Date & PIN verification status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatFullDateTime(order.completedAt ?? order.createdAt),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      if (isDelivered)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: order.isOtpBypassed ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.isOtpBypassed ? '⚠️ Emergency Bypass' : '🔒 Verified PIN',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: order.isOtpBypassed ? const Color(0xFFB45309) : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Tap to view full order details ▼', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderFullDetailsSheet(OrderModel order) {
    final isDelivered = order.status == 'DELIVERED';
    final isCancelled = order.status == 'CANCELLED';
    final isBuy = order.orderType == 'BUY_FOR_ME';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.90),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 44, height: 4.5, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                            Text(isBuy ? 'Buy For Me Order' : 'Pick & Deliver Order', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  children: [
                    // Status & Fare
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isDelivered ? '✅ DELIVERED' : '❌ CANCELLED',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isDelivered ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(order.paymentMode == 'UPI' ? '📱 UPI Payment' : '💵 Cash on Delivery', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            ],
                          ),
                          Text('₹${order.fare}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Timestamps Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF0284C7)),
                              const SizedBox(width: 8),
                              const Text('Placed: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                              Expanded(child: Text(_formatFullDateTime(order.createdAt), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
                            ],
                          ),
                          if (order.completedAt != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF15803D)),
                                const SizedBox(width: 8),
                                const Text('Delivered: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                Expanded(child: Text(_formatFullDateTime(order.completedAt!), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D)))),
                              ],
                            ),
                          ],
                          if (isCancelled && order.cancellationReason != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                const Text('Reason: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                                Expanded(child: Text(order.cancellationReason!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items Checklist Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(isBuy ? Icons.shopping_basket_rounded : Icons.inventory_2_rounded, size: 16, color: const Color(0xFF0284C7)),
                                  const SizedBox(width: 6),
                                  Text(isBuy ? 'ITEMS TO BUY & DELIVER' : 'PACKAGE ITEMS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                child: Text(order.category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              ),
                            ],
                          ),
                          if (isBuy && order.shopName != null && order.shopName!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text('Store: ${order.shopName}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0369A1)))),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          for (final it in (order.itemsList.isNotEmpty ? order.itemsList : [order.category]))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981))),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(it, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Route details
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ROUTE DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5)),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.trip_origin_rounded, size: 14, color: Color(0xFF0284C7)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isBuy ? 'Purchase Location / Shop' : 'Pickup Location', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    Text(order.pickupAddress, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                    if (order.pickupPhone != null && order.pickupPhone!.isNotEmpty)
                                      InkWell(
                                        onTap: () => _callPhone(order.pickupPhone),
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Text('📞 ${order.pickupPhone}', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFEF4444)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Delivery Landmark', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    Text(order.dropAddress, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                    if (order.dropPhone != null && order.dropPhone!.isNotEmpty)
                                      InkWell(
                                        onTap: () => _callPhone(order.dropPhone),
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Text('📞 ${order.dropPhone}', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Contacts: Customer & Rider
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CONTACTS & VERIFICATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF0284C7))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    Text(order.customerPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 20), onPressed: () => _callPhone(order.customerPhone), tooltip: 'Call Customer'),
                            ],
                          ),
                          if (order.riderName != null && order.riderName!.isNotEmpty) ...[
                            const Divider(height: 16, color: Color(0xFFF1F5F9)),
                            Row(
                              children: [
                                Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle), child: const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF15803D))),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(order.riderName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      if (order.riderPhone != null) Text(order.riderPhone!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                if (order.riderPhone != null)
                                  IconButton(icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 20), onPressed: () => _callPhone(order.riderPhone), tooltip: 'Call Rider'),
                              ],
                            ),
                          ],
                          if (order.deliveryPin != null && order.deliveryPin!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Verification PIN:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  Text(order.deliveryPin!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 1.5)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatFullDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dt.day.toString().padLeft(2, '0');
    final mon = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
    final yr = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day $mon $yr, $hour:$min $period';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
