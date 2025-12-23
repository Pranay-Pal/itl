import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/services/pusher_service.dart';
import 'package:itl/src/features/chat/screens/chat_list_screen.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/features/auth/screens/login_page.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:itl/src/features/bookings/bookings.dart';
import 'package:itl/src/features/reports/screens/reports_dashboard_screen.dart';
import 'package:itl/src/features/reports/screens/pending_dashboard_screen.dart';
import 'package:itl/src/features/expenses/screens/expenses_screen.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/features/bookings/models/marketing_overview.dart';
import 'package:itl/src/utils/currency_formatter.dart';
import 'package:itl/src/features/invoices/screens/invoice_list_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final PusherService _pusherService = PusherService();
  late StreamSubscription<PusherEvent> _eventSubscription;
  int _totalUnreadCount = 0;
  final MarketingService _marketingService = MarketingService();
  MarketingOverview? _overview;
  String _selectedReportFilter = 'All'; // 'All', 'Bill', 'Cash'

  bool get _isUser => _apiService.userType == 'user';

  @override
  void initState() {
    super.initState();
    _initPusher();
    _fetchUnreadCount();
    if (_isUser) {
      _fetchOverview();
    }
  }

  Future<void> _fetchOverview() async {
    if (_apiService.userCode == null) return;

    try {
      final overview =
          await _marketingService.getOverview(userCode: _apiService.userCode!);
      if (mounted) setState(() => _overview = overview);
    } catch (e) {
      debugPrint('Error fetching overview: $e');
    } finally {}
  }

  Future<void> _fetchUnreadCount() async {
    if (!mounted) return;
    try {
      // Prefer dedicated unread-counts endpoint if available
      final unread = await _apiService.getUnreadCounts();
      if (!mounted) return;
      int total = 0;
      if (unread != null) {
        total = (unread['total'] is int)
            ? unread['total'] as int
            : int.tryParse(unread['total']?.toString() ?? '0') ?? 0;
      } else {
        // Fallback: compute from groups if endpoint not present
        final dynamic groupsResult = await _apiService.getChatGroups();
        if (groupsResult is List) {
          total = groupsResult.fold<int>(0, (sum, g) {
            final u = (g as Map)['unread'];
            if (u is int) return sum + u;
            if (u is String) return sum + (int.tryParse(u) ?? 0);
            if (u is double) return sum + u.round();
            return sum;
          });
        }
      }
      setState(() => _totalUnreadCount = total);
    } catch (e, s) {
      if (kDebugMode) {
        print('Error in _fetchUnreadCount: $e');
        print(s);
      }
    }
  }

  Future<void> _initPusher() async {
    await _pusherService.connectPusher();
    await _pusherService.subscribeToChannel('chat');

    _eventSubscription = _pusherService.eventStream.listen((event) {
      if (kDebugMode) {
        print(
          "Dashboard received event: ${event.eventName} with data: ${event.data}",
        );
      }
      if (event.channelName == 'chat' &&
          event.eventName == 'ChatMessageBroadcast') {
        try {
          final data = jsonDecode(event.data);
          final msg = data['message'];
          if (msg != null) {
            final currentUserId = _apiService.currentUserId;
            final msgUserId = msg['user_id'] ?? msg['user']?['id'];
            // Only increment if the message is from someone else (not mine)
            if (currentUserId != null && msgUserId != currentUserId) {
              setState(() => _totalUnreadCount = _totalUnreadCount + 1);
            }
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _pusherService.unsubscribeFromChannel('chat');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: kBlueGradient),
        ),
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        leading: Builder(
          builder: (BuildContext innerContext) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () {
                Scaffold.of(innerContext).openDrawer();
              },
            );
          },
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (BuildContext context) =>
                              const ChatListScreen(),
                        ),
                      )
                      .then((_) => _fetchUnreadCount());
                },
              ),
              if (_totalUnreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_totalUnreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(gradient: kBlueGradient),
              child: const Text(
                'ITL Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            const ListTile(leading: Icon(Icons.home), title: Text('Home')),
            if (_isUser)
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Bookings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BookingDashboardScreen(
                          userCode: _apiService.userCode ?? ''),
                    ),
                  );
                },
              ),
            if (_isUser)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Expenses'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ExpensesScreen(),
                    ),
                  );
                },
              ),
            if (_isUser)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Invoices'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const InvoiceListScreen(),
                    ),
                  );
                },
              ),
            if (_isUser)
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('Reports'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ReportsDashboardScreen(
                          userCode: _apiService.userCode ?? ''),
                    ),
                  );
                },
              ),
            if (_isUser)
              ListTile(
                leading: const Icon(Icons.pending_actions),
                title: const Text('Pending Reports'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PendingDashboardScreen(
                          userCode: _apiService.userCode ?? ''),
                    ),
                  );
                },
              ),
            const ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Logout'),
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop(); // close drawer
                final service = ApiService();
                await service.logout();
                _pusherService.disconnectPusher();
                if (!mounted) return;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildQuickExpenseCard(),
              const SizedBox(height: 20),
              const Text(
                'Dashboard Overview',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Summary Cards
              if (_isUser && _overview != null && _overview!.data != null)
                _buildDynamicOverviewCards(context, _overview!.data!)
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Bookings',
                        '124',
                        Icons.book_online,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Revenue',
                        '₹ 45L',
                        Icons.currency_rupee,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 30),

              LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate width for side-by-side items with minimal gap
                  // Available width - 8px gap
                  final double itemWidth = (constraints.maxWidth - 8) / 2;
                  // Set height relative to width (near square for max visibility)
                  final double itemHeight = itemWidth * 1.1;

                  final data = _overview?.data;
                  final billAmount = data?.totalBillBookingAmount ?? 0;
                  final letterAmount = data?.totalWithoutBillBookings ?? 0;
                  final totalAmount = data?.totalBookingAmount ?? 0;

                  final paidAmount = data?.totalPaidInvoiceAmount ?? 0;
                  final unpaidAmount = data?.totalUnpaidInvoiceAmount ?? 0;
                  final partialAmount = data?.totalPartialTaxInvoiceAmount ?? 0;

                  // Find max for bar chart normalization (avoid division by zero)
                  double maxY = [paidAmount, unpaidAmount, partialAmount]
                      .reduce((a, b) => a > b ? a : b)
                      .toDouble();
                  if (maxY == 0) maxY = 100; // Default scale if all 0
                  // Add buffer
                  maxY = maxY * 1.2;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pie Chart Section - Invoice Performance (Bar Chart moved here based on user image flow? No, user text says "pie chart we show revenue source").
                      // User image: Left is "Invoice Performance" (Bar), Right is "Revenue Source" (Pie).
                      // My previous layout: Left Pie, Right Bar.
                      // I will swap them to match the image: Left Bar (Performance), Right Pie (Revenue).

                      // Bar Chart Section (Invoice Performance)
                      Expanded(
                        child: Container(
                          height: itemHeight, // Enforce height
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Invoice Performance',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: maxY,
                                    barTouchData: BarTouchData(
                                      enabled: true,
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipColor:
                                            (BarChartGroupData group) =>
                                                Colors.blueGrey,
                                        getTooltipItem:
                                            (group, groupIndex, rod, rodIndex) {
                                          return BarTooltipItem(
                                            CurrencyFormatter
                                                .formatIndianCurrency(rod.toY),
                                            const TextStyle(
                                                color: Colors.white),
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            const titles = [
                                              'Paid',
                                              'Unpaid',
                                              'Partial'
                                            ];
                                            if (value.toInt() < titles.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                  titles[value.toInt()],
                                                  style: const TextStyle(
                                                      fontSize: 10),
                                                ),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, meta) {
                                            if (value == 0) {
                                              return const Text('');
                                            }
                                            return Text(
                                              CurrencyFormatter
                                                  .formatIndianCurrencyCompact(
                                                      value),
                                              style:
                                                  const TextStyle(fontSize: 8),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      rightTitles: AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: maxY / 4,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: Colors.grey
                                              .withValues(alpha: 0.1),
                                          strokeWidth: 1,
                                        );
                                      },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: [
                                      BarChartGroupData(x: 0, barRods: [
                                        BarChartRodData(
                                          toY: paidAmount.toDouble(),
                                          color: Colors.green,
                                          width: 12,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        )
                                      ]),
                                      BarChartGroupData(x: 1, barRods: [
                                        BarChartRodData(
                                          toY: unpaidAmount.toDouble(),
                                          color: Colors.redAccent,
                                          width: 12,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        )
                                      ]),
                                      BarChartGroupData(x: 2, barRods: [
                                        BarChartRodData(
                                          toY: partialAmount.toDouble(),
                                          color: Colors.orange,
                                          width: 12,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        )
                                      ]),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Pie Chart Section (Revenue Source)
                      Expanded(
                        child: Container(
                          height: itemHeight, // Enforce height
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          // Minimal padding inside card
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Revenue Source',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: itemWidth * 0.18,
                                        sections: [
                                          PieChartSectionData(
                                            color: const Color(0xFF5C54E5),
                                            value: billAmount.toDouble() == 0 &&
                                                    letterAmount.toDouble() == 0
                                                ? 1
                                                : billAmount.toDouble(),
                                            title: '',
                                            radius: itemWidth * 0.12,
                                            showTitle: false,
                                          ),
                                          PieChartSectionData(
                                            color: const Color(0xFF5C54E5)
                                                .withValues(alpha: 0.5),
                                            value: letterAmount.toDouble(),
                                            title: '',
                                            radius: itemWidth * 0.12,
                                            showTitle: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Total',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter
                                              .formatIndianCurrencyCompact(
                                                  totalAmount),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Compact Legend with smaller values
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildCompactIndicator(
                                          const Color(0xFF5C54E5), 'Bill'),
                                      Text(
                                        CurrencyFormatter.formatIndianCurrency(
                                            billAmount),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildCompactIndicator(
                                          const Color(0xFF5C54E5)
                                              .withValues(alpha: 0.5),
                                          'Cash/Letter'),
                                      Text(
                                        CurrencyFormatter.formatIndianCurrency(
                                            letterAmount),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildDetailedReports(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactIndicator(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicOverviewCards(BuildContext context, OverviewData data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            isDark,
            icon: Icons.calendar_today_outlined,
            label: 'BOOKING VALUE',
            value: CurrencyFormatter.formatIndianCurrency(
                data.totalBookingAmount ?? 0),
            color: Colors.blue,
            pillText: '${data.totalBookings ?? 0} Total',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCard(
            isDark,
            icon: Icons.error_outline,
            label: 'UNPAID INVOICES',
            value: CurrencyFormatter.formatIndianCurrency(
                data.totalUnpaidInvoiceAmount ?? 0),
            color: Colors.red,
            pillText: 'Action Needed',
            isActionNeeded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? pillText,
    bool isActionNeeded = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              if (pillText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActionNeeded
                        ? Colors.red.withValues(alpha: 0.1)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pillText,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActionNeeded ? Colors.red : color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedReports() {
    if (_overview?.data == null) return const SizedBox.shrink();

    final data = _overview!.data!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Detailed Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildReportChips(),
          ],
        ),
        const SizedBox(height: 16),
        _buildReportGrid(data),
      ],
    );
  }

  Widget _buildReportChips() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChip('All'),
          _buildChip('Bill'),
          _buildChip('Cash'),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _selectedReportFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReportFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildReportGrid(OverviewData data) {
    // Collect all cards based on filter
    final List<Widget> cards = [];

    // Helper to format currency
    String fmt(num? val) => CurrencyFormatter.formatIndianCurrency(val ?? 0);

    // --- ALL DATA (Strict Order) ---
    if (_selectedReportFilter == 'All') {
      // 1. Total Bookings (Purple)
      cards.add(_buildReportCard(
          'Total Bookings', data.totalBookings, fmt(data.totalBookingAmount),
          color: const Color(0xFF5C54E5),
          isTotal: true,
          countLabel: data.totalBookings?.toString()));

      // 2. Bill Bookings (Blue)
      cards.add(_buildReportCard(
          'Bill Bookings', data.billBookings, fmt(data.totalBillBookingAmount),
          color: Colors.blue));

      // 3. Without Bill Bookings (Yellow/Orange)
      cards.add(_buildReportCard('Without Bill Bookings',
          data.withoutBillBookings, fmt(data.totalWithoutBillBookings),
          color: Colors.amber[700]!));

      // 4. Due For Invoicing (Blue Grey)
      // Note: Mapping 'notGeneratedInvoices' to Due For Invoicing count based on assumption/context
      cards.add(_buildReportCard('Due For Invoicing', data.notGeneratedInvoices,
          fmt(data.totalNotGeneratedInvoicesAmount),
          color: Colors.blueGrey));

      // 5. Partial Paid Invoices (Green?) -> Image shows empty/grey or green? Let's use Green.
      cards.add(_buildReportCard('Partial Paid Invoices',
          data.partialTaxInvoices, fmt(data.totalPartialTaxInvoiceAmount),
          color: Colors.green));

      // 6. Unpaid Invoices (Red)
      cards.add(_buildReportCard('Unpaid Invoices', data.unpaidInvoices,
          fmt(data.totalUnpaidInvoiceAmount),
          color: Colors.red));

      // 7. Canceled Invoices (Red/Grey)
      cards.add(_buildReportCard(
          'Canceled Invoices',
          data.canceledGeneratedInvoices,
          fmt(data.totalcanceledGeneratedInvoicesAmount),
          color:
              Colors.grey)); // Image shows grey title, red value? Using generic

      // 8. Proforma Invoices (Orange)
      cards.add(_buildReportCard(
          'Proforma Invoices', data.generatedPIs, fmt(data.totalPIAmount),
          color: Colors.orange));

      // 9. Paid Proforma Invoices (Green)
      cards.add(_buildReportCard('Paid Proforma Invoices', data.paidPiInvoices,
          fmt(data.totalPaidPIAmount),
          color: Colors.teal));

      // 10. Invoice Transactions (Blue)
      cards.add(_buildReportCard('Invoice Transactions', data.transactions,
          fmt(data.totalTransactionsAmount),
          color: Colors.blueAccent));

      // 11. Paid Cash Letters (Green)
      cards.add(_buildReportCard('Paid Cash Letters', data.cashPaidLetters,
          fmt(data.totalCashPaidLettersAmount),
          color: Colors.green));

      // 12. Unpaid Cash Letters (Red)
      cards.add(_buildReportCard('Unpaid Cash Letters', data.cashUnpaidLetters,
          fmt(data.totalCashUnpaidAmounts),
          color: Colors.red));

      // 13. Partial Cash Letters (Gold)
      cards.add(_buildReportCard('Partial Cash Letters',
          data.cashPartialLetters, fmt(data.totalcashPartialLettersAmount),
          color: Colors.amber));

      // 14. Settled Cash Letters (Teal)
      cards.add(_buildReportCard('Settled Cash Letters',
          data.cashSettledLetters, fmt(data.totalCashSettledLettersAmount),
          color: Colors.teal.shade700));

      // 15. Clients (Orange)
      cards.add(_buildReportCard(
          'Clients', data.allClients, fmt(data.totalBookingAmount),
          color: Colors.deepOrange));
    }

    // --- BILL DATA ---
    if (_selectedReportFilter == 'Bill') {
      cards.add(_buildReportCard(
          'Bill Bookings', data.billBookings, fmt(data.totalBillBookingAmount),
          color: Colors.blue));
      cards.add(_buildReportCard('Due For Invoicing', data.notGeneratedInvoices,
          fmt(data.totalNotGeneratedInvoicesAmount),
          color: Colors.blueGrey));
      cards.add(_buildReportCard('Partial Paid Invoices',
          data.partialTaxInvoices, fmt(data.totalPartialTaxInvoiceAmount),
          color: Colors.green));
      cards.add(_buildReportCard('Unpaid Invoices', data.unpaidInvoices,
          fmt(data.totalUnpaidInvoiceAmount),
          color: Colors.red));
      cards.add(_buildReportCard(
          'Canceled Invoices',
          data.canceledGeneratedInvoices,
          fmt(data.totalcanceledGeneratedInvoicesAmount),
          color: Colors.grey));
      cards.add(_buildReportCard(
          'Proforma Invoices', data.generatedPIs, fmt(data.totalPIAmount),
          color: Colors.orange));
      cards.add(_buildReportCard('Paid Proforma Invoices', data.paidPiInvoices,
          fmt(data.totalPaidPIAmount),
          color: Colors.teal));
      cards.add(_buildReportCard('Invoice Transactions', data.transactions,
          fmt(data.totalTransactionsAmount),
          color: Colors.blueAccent));
    }

    // --- CASH DATA ---
    if (_selectedReportFilter == 'Cash') {
      cards.add(_buildReportCard('Without Bill Bookings',
          data.withoutBillBookings, fmt(data.totalWithoutBillBookings),
          color: Colors.amber[700]!));
      cards.add(_buildReportCard('Paid Cash Letters', data.cashPaidLetters,
          fmt(data.totalCashPaidLettersAmount),
          color: Colors.green));
      cards.add(_buildReportCard('Unpaid Cash Letters', data.cashUnpaidLetters,
          fmt(data.totalCashUnpaidAmounts),
          color: Colors.red));
      cards.add(_buildReportCard('Partial Cash Letters',
          data.cashPartialLetters, fmt(data.totalcashPartialLettersAmount),
          color: Colors.amber));
      cards.add(_buildReportCard('Settled Cash Letters',
          data.cashSettledLetters, fmt(data.totalCashSettledLettersAmount),
          color: Colors.teal.shade700));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce 3 columns on mobile (constraint width < 600 or so)
        // Desktop/Wide > 800 -> 5 columns? User image shows 5 in a row.
        // Let's go with:
        int crossAxisCount;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 3; // Force 3 on mobile
        }

        // Adjust aspect ratio for 3-column mobile to be compact/small
        double childAspectRatio = 1.1;
        if (crossAxisCount == 3) {
          childAspectRatio = 0.85; // Taller for 3-col? Or simpler?
          // "small" might mean just fitted. 3 col means narrow width.
          // Need height to accommodate content (Title, Count, Value).
          // Let's try 0.9 or 1.0.
          childAspectRatio = 0.95;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: childAspectRatio,
          padding: const EdgeInsets.symmetric(horizontal: 4), // Minimal padding
          children: cards,
        );
      },
    );
  }

  Widget _buildReportCard(
    String title,
    num? count,
    String value, {
    required Color color,
    bool isTotal = false,
    String? countLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
          color: isTotal ? const Color(0xFFF3F0FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isTotal
                  ? Colors.transparent
                  : Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            if (!isTotal)
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.05),
                spreadRadius: 1,
                blurRadius: 3,
              )
          ]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Small dot/icon
          Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                  color: color, // Use the passed color
                  shape: BoxShape.circle)),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10, // Smaller font
                color: Colors.grey[600],
                fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            countLabel ?? (count?.toString() ?? '0'),
            style: const TextStyle(
                fontSize: 16, // Compact count
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 9, // Smaller value
                fontWeight: FontWeight.bold,
                color: isTotal
                    ? Colors.orange
                    : color), // Total card value is orange in image
          ),
        ],
      ),
    );
  }

  Widget _buildQuickExpenseCard() {
    return GestureDetector(
      onTap: _showQuickExpenseDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // Gradient or solid color to make it stand out
          gradient:
              const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Expense',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Add a new expense instantly',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  void _showQuickExpenseDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedFilePath;
    String? selectedFileName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Quick Add Expense'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 16),

                  // File Picker UI
                  if (selectedFileName != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file,
                              size: 20, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedFileName!,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                selectedFilePath = null;
                                selectedFileName = null;
                              });
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('Camera'),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    final picker = ImagePicker();
                                    final photo = await picker.pickImage(
                                        source: ImageSource.camera);
                                    if (photo != null) {
                                      setState(() {
                                        selectedFilePath = photo.path;
                                        selectedFileName = photo.name;
                                      });
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('Gallery'),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    final picker = ImagePicker();
                                    final image = await picker.pickImage(
                                        source: ImageSource.gallery);
                                    if (image != null) {
                                      setState(() {
                                        selectedFilePath = image.path;
                                        selectedFileName = image.name;
                                      });
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.attach_file),
                                  title: const Text('File / PDF'),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    FilePickerResult? result =
                                        await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: [
                                        'jpg',
                                        'jpeg',
                                        'png',
                                        'pdf'
                                      ],
                                    );

                                    if (result != null &&
                                        result.files.single.path != null) {
                                      setState(() {
                                        selectedFilePath =
                                            result.files.single.path!;
                                        selectedFileName =
                                            result.files.single.name;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Attach Receipt'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final amount = double.tryParse(amountController.text);
                  if (amount == null) return;

                  final userCode = _apiService.userCode;
                  if (userCode == null) return;

                  final desc = descriptionController.text;
                  final file = selectedFilePath;

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);

                  messenger.showSnackBar(
                    const SnackBar(content: Text('Adding expense...')),
                  );

                  try {
                    await _marketingService.createExpense(
                      userCode: userCode,
                      amount: amount,
                      section: 'personal',
                      description: desc,
                      fromDate: DateTime.now().toString().split(' ')[0],
                      filePath: file,
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text('Expense added successfully!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}
