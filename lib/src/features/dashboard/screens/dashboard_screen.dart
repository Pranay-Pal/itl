import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:itl/src/common/animations/scale_button.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/glass_container.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/services/pusher_service.dart';
import 'package:itl/src/features/chat/screens/chat_list_screen.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/services/notification_service.dart';

import 'package:itl/src/features/profile/screens/profile_screen.dart';
import 'package:itl/src/features/auth/screens/login_page.dart';
import 'package:itl/src/features/bookings/bookings.dart';
import 'package:itl/src/features/reports/screens/reports_dashboard_screen.dart';
import 'package:itl/src/features/meter/screens/meter_dashboard_screen.dart';
import 'package:itl/src/features/reports/screens/pending_dashboard_screen.dart';
import 'package:itl/src/features/expenses/screens/expenses_screen.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/features/bookings/models/marketing_overview.dart';
import 'package:itl/src/services/meter_service.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/utils/currency_formatter.dart';
import 'package:itl/src/features/invoices/screens/invoice_list_screen.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final PusherService _pusherService = PusherService();
  final MarketingService _marketingService = MarketingService();

  StreamSubscription<PusherEvent>? _eventSubscription;
  int _totalUnreadCount = 0;
  MarketingOverview? _overview;

  bool get _isUser => _apiService.userType == 'user';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Ensure ApiService is initialized (token/userType loaded)
    await _apiService.ensureInitialized();

    // Process any pending notification tap (Deep Linking)
    NotificationService().processInitialMessage();

    // Check if user is valid
    if (mounted) {
      setState(() {}); // Rebuild to update _isUser
      _initPusher();
      _fetchUnreadCount();
      if (_isUser) {
        _fetchOverview();
        _fetchMonthlyStats();
      }
    }
  }

  Future<void> _fetchOverview() async {
    if (_apiService.userCode == null) return;
    try {
      // Revert to fetching All-Time overview without monthly filters
      final overview =
          await _marketingService.getOverview(userCode: _apiService.userCode!);
      if (mounted) setState(() => _overview = overview);
    } catch (e) {
      debugPrint('Error fetching overview: $e');
    }
  }

  Future<void> _fetchUnreadCount() async {
    if (!mounted) return;
    try {
      final unread = await _apiService.getUnreadCounts();
      if (!mounted) return;
      int total = 0;
      if (unread != null) {
        total = (unread['total'] is int)
            ? unread['total'] as int
            : int.tryParse(unread['total']?.toString() ?? '0') ?? 0;
      }
      setState(() => _totalUnreadCount = total);
    } catch (_) {}
  }

  Future<void> _initPusher() async {
    await _pusherService.connectPusher();
    await _pusherService.subscribeToChannel('chat');
    _eventSubscription = _pusherService.eventStream.listen((event) {
      if (event.channelName == 'chat' &&
          event.eventName == 'ChatMessageBroadcast') {
        try {
          final data = jsonDecode(event.data);
          final msg = data['message'];
          if (msg != null) {
            final currentUserId = _apiService.currentUserId;
            final msgUserId = msg['user_id'] ?? msg['user']?['id'];
            if (currentUserId != null && msgUserId != currentUserId) {
              setState(() => _totalUnreadCount++);
            }
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _pusherService.unsubscribeFromChannel('chat'); // Ensure unsubscribe
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _overview?.data;

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow body to scroll behind app bar
      drawer: _buildDrawer(context),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: _initializeApp,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent:
                    AlwaysScrollableScrollPhysics()), // Ensure scroll even if content is short
            slivers: [
              // Floating Sliver App Bar
              SliverAppBar(
                floating: true,
                snap: true,
                title: const Text('Dashboard'), // TextStyle handled by Theme
                backgroundColor:
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
                elevation: 0,
                centerTitle: false,
                actions: [
                  Stack(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.person_outline),
                          onPressed: () {
                            if (_isUser && _apiService.userCode != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                      userCode: _apiService.userCode!),
                                ),
                              );
                            }
                          }),
                    ],
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        onPressed: () {
                          Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ChatListScreen()))
                              .then((_) => _fetchUnreadCount());
                        },
                      ),
                      if (_totalUnreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: AppPalette.dangerRed,
                                shape: BoxShape.circle),
                            child: Text(
                              '$_totalUnreadCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Main Content
              SliverPadding(
                padding: const EdgeInsets.all(AppLayout.gapL),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Expense (Replaces old card)
                      if (_isUser) ...[
                        // Monthly Summary Card
                        _buildMonthlySummaryCard(),

                        // Quick Expense
                        // Quick Expense
                        _buildQuickAction(
                          title: 'Quick Expense',
                          subtitle: 'Add a new expense receipt',
                          icon: Icons.add,
                          color: AppPalette.neonCyan,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ExpensesScreen())),
                        ),
                        const SizedBox(height: AppLayout.gapM), // Spacing
                        // Quick Meter Reading
                        // Quick Meter Reading
                        _buildQuickAction(
                          title: 'Quick Meter Reading',
                          subtitle: 'Log a new meter entry',
                          icon: Icons.speed,
                          color: Colors.orangeAccent,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const MeterDashboardScreen())),
                        ),
                      ],

                      const SizedBox(height: AppLayout.gapSection),

                      Text('Overview', style: AppTypography.headlineMedium)
                          .animate()
                          .fadeIn(),

                      const SizedBox(height: AppLayout.gapM),

                      // Bento Grid
                      StaggeredGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppLayout.gapM,
                        crossAxisSpacing: AppLayout.gapM,
                        children: [
                          // 1. Bookings (Nav)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 1,
                            mainAxisCellCount: 1,
                            child: _buildBentoCard(
                              title: 'Bookings',
                              value: data?.totalBookings?.toString() ?? '0',
                              subtitle: CurrencyFormatter.formatIndianCurrency(
                                  data?.totalBookingAmount ?? 0),
                              icon: Icons.calendar_today,
                              color: AppPalette.electricBlue,
                              delay: 100,
                              onTap: () {
                                if (_isUser) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              BookingDashboardScreen(
                                                  userCode:
                                                      _apiService.userCode ??
                                                          '')));
                                }
                              },
                            ),
                          ),

                          // 2. Unpaid / Invoices (Nav)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 1,
                            mainAxisCellCount: 1,
                            child: _buildBentoCard(
                              title: 'Invoices',
                              value:
                                  CurrencyFormatter.formatIndianCurrencyCompact(
                                      data?.totalUnpaidInvoiceAmount ?? 0),
                              subtitle: 'Unpaid Amount',
                              icon: Icons.description_outlined,
                              color: AppPalette.dangerRed,
                              isAlert:
                                  (data?.totalUnpaidInvoiceAmount ?? 0) > 0,
                              delay: 150,
                              onTap: () {
                                if (_isUser) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const InvoiceListScreen()));
                                }
                              },
                            ),
                          ),

                          // 3. Reports (Nav)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 1,
                            mainAxisCellCount: 1,
                            child: _buildBentoCard(
                              title: 'Reports',
                              value: 'View',
                              subtitle: 'Completed',
                              icon: Icons.analytics_outlined,
                              color: AppPalette.successGreen,
                              delay: 200,
                              onTap: () {
                                if (_isUser) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              ReportsDashboardScreen(
                                                  userCode:
                                                      _apiService.userCode ??
                                                          '')));
                                }
                              },
                            ),
                          ),

                          // 3.5 Meter Readings (Nav)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 1,
                            mainAxisCellCount: 1,
                            child: _buildBentoCard(
                              title: 'Meter',
                              value: 'Readings',
                              subtitle: 'Track Usage',
                              icon: Icons.speed,
                              color: Colors.orangeAccent,
                              delay: 250,
                              onTap: () {
                                if (_isUser) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const MeterDashboardScreen()));
                                }
                              },
                            ),
                          ),

                          // 4. Pending Reports (Nav)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 1,
                            mainAxisCellCount: 1,
                            child: _buildBentoCard(
                              title: 'Pending',
                              value: 'Check',
                              subtitle: 'Status',
                              icon: Icons.pending_actions_outlined,
                              color: AppPalette.warningOrange,
                              delay: 250,
                              onTap: () {
                                if (_isUser) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              PendingDashboardScreen(
                                                  userCode:
                                                      _apiService.userCode ??
                                                          '')));
                                }
                              },
                            ),
                          ),

                          // 5. Expenses (Nav)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 1,
                            mainAxisCellCount: 1,
                            child: _buildBentoCard(
                              title: 'Expenses',
                              value: 'Manage',
                              subtitle: 'Records',
                              icon: Icons.receipt_long_outlined,
                              color: Colors.purpleAccent,
                              delay: 300,
                              onTap: () {
                                if (_isUser) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ExpensesScreen()));
                                }
                              },
                            ),
                          ),

                          // 6. Profile / Settings (Nav) - Placeholder for now or connect to Profile
                          StaggeredGridTile.count(
                            crossAxisCellCount: 1,
                            mainAxisCellCount: 1,
                            child: _buildBentoCard(
                              title: 'Profile',
                              value: 'Settings',
                              subtitle: 'Account',
                              icon: Icons.person_outline,
                              color: Colors.blueGrey,
                              delay: 350,
                              onTap: () {
                                if (_apiService.userCode != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProfileScreen(
                                          userCode: _apiService.userCode!),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('User code not found')));
                                }
                              },
                            ),
                          ),

                          // 7. Invoice Performance (Wide Chart)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 2,
                            mainAxisCellCount: 1.5, // Taller
                            child: _buildChartCard(
                              title: 'Invoice Performance',
                              child: _buildBarChart(data),
                              delay: 400,
                            ),
                          ),

                          // 8. Revenue Source (Wide Pie)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 2,
                            mainAxisCellCount: 1.5,
                            child: _buildChartCard(
                              title: 'Revenue Source',
                              child: _buildPieChart(data),
                              delay: 450,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 100), // Bottom padding
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Data Fetching for Monthly Summary ---
  Map<String, double>? _monthlyStats;
  bool _loadingMonthlyStats = false;
  int _summaryMonth = DateTime.now().month;
  int _summaryYear = DateTime.now().year;

  Future<void> _fetchMonthlyStats() async {
    if (_apiService.userCode == null) return;
    if (!mounted) return;

    setState(() => _loadingMonthlyStats = true);

    final month = _summaryMonth;
    final year = _summaryYear;
    final userCode = _apiService.userCode!;

    double totalBookings = 0;
    double totalMeter = 0;
    double totalExpenses = 0;

    try {
      // 1. Fetch Bookings (Selected Month) via Overview Endpoint
      // This is more efficient than fetching the list and summing client-side
      final overviewResp = await _marketingService.getOverview(
        userCode: userCode,
        month: month,
        year: year,
      );

      if (overviewResp.data != null) {
        // totalBookingAmount returns the value of bookings
        if (overviewResp.data!.totalBookingAmount != null) {
          totalBookings = overviewResp.data!.totalBookingAmount!.toDouble();
        }
      }

      // 2. Fetch Meter Readings (Selected Month)
      final meterService = MeterService();
      final meterResp = await meterService.getReadings(
        month: month,
        year: year,
        perPage: 100,
      );
      if (meterResp.success && meterResp.data.readings.isNotEmpty) {
        for (var r in meterResp.data.readings) {
          if (r.totalReading != null) totalMeter += r.totalReading!;
        }
      }

      // 3. Fetch Expenses (Selected Month)
      final expenseResp = await _marketingService.getExpenses(
        userCode: userCode,
        month: month,
        year: year,
        perPage: 1,
      );

      if (expenseResp.totals != null) {
        totalExpenses = expenseResp.totals!.totalAmount;
      }
    } catch (e) {
      debugPrint('Error fetching monthly stats: $e');
    }

    if (mounted) {
      setState(() {
        _monthlyStats = {
          'bookings': totalBookings,
          'meter': totalMeter,
          'expenses': totalExpenses,
        };
        _loadingMonthlyStats = false;
      });
    }
  }

  void _showMonthYearPicker() {
    int tempMonth = _summaryMonth;
    int tempYear = _summaryYear;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          title: const Text('Select Month & Year'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: tempYear,
                decoration: InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: List.generate(5, (i) => DateTime.now().year - i)
                    .map((y) =>
                        DropdownMenuItem(value: y, child: Text(y.toString())))
                    .toList(),
                onChanged: (v) => tempYear = v!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: tempMonth,
                decoration: InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(DateFormat.MMM().format(DateTime(0, m)))))
                    .toList(),
                onChanged: (v) => tempMonth = v!,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _summaryMonth = tempMonth;
                  _summaryYear = tempYear;
                });
                Navigator.pop(ctx);
                _fetchMonthlyStats();
                // Do not refetch overview; it remains All-Time
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  // --- Components ---

  Widget _buildMonthlySummaryCard() {
    // Show loading state differently or keep old data while loading
    // but visually might want to show spinner if hard reload

    final stats =
        _monthlyStats ?? {'bookings': 0.0, 'meter': 0.0, 'expenses': 0.0};
    final dateDisplayed = DateTime(_summaryYear, _summaryMonth);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.gapM),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.electricBlue, Colors.purple.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppPalette.electricBlue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _loadingMonthlyStats
                            ? 'Updating...'
                            : 'Activity Summary',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(DateFormat('MMMM yyyy').format(dateDisplayed),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                ScaleButton(
                  onTap: _showMonthYearPicker,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.calendar_month, color: Colors.white),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
            if (_loadingMonthlyStats && _monthlyStats == null)
              const Center(
                  child: CircularProgressIndicator(color: Colors.white))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                      'Bookings',
                      CurrencyFormatter.formatIndianCurrencyCompact(
                          stats['bookings']!)),
                  _buildSummaryItem(
                      'Meter (Km)', stats['meter']!.toStringAsFixed(1)),
                  _buildSummaryItem(
                      'Exp',
                      CurrencyFormatter.formatIndianCurrencyCompact(
                          stats['expenses']!)),
                ],
              )
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isAlert = false,
    required int delay,
    VoidCallback? onTap,
  }) {
    return ScaleButton(
      onTap: onTap,
      child: GlassContainer(
        isNeon: isAlert, // Glow if alert
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Icon(icon, color: color, size: 28),
              if (onTap != null)
                Icon(Icons.arrow_forward,
                    size: 16, color: color.withValues(alpha: 0.5)),
            ]),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTypography.displaySmall
                        .copyWith(color: color, fontSize: 24)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTypography.labelSmall.copyWith(
                        color: isAlert ? AppPalette.dangerRed : null,
                        fontWeight:
                            isAlert ? FontWeight.bold : FontWeight.normal)),
                const SizedBox(height: 2),
                Text(title,
                    style:
                        AppTypography.bodySmall.copyWith(color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildChartCard(
      {required String title, required Widget child, required int delay}) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headlineSmall),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildBarChart(OverviewData? data) {
    if (data == null) return const Center(child: CircularProgressIndicator());
    final paid = data.totalPaidInvoiceAmount?.toDouble() ?? 0;
    final unpaid = data.totalUnpaidInvoiceAmount?.toDouble() ?? 0;
    final partial = data.totalPartialTaxInvoiceAmount?.toDouble() ?? 0;

    // Safety check for empty data
    if (paid == 0 && unpaid == 0 && partial == 0) {
      return Center(
          child: Text("No invoice data", style: AppTypography.bodySmall));
    }

    double maxY = [paid, unpaid, partial].reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 100;
    maxY *= 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                switch (val.toInt()) {
                  case 0:
                    return Text('Paid', style: AppTypography.labelSmall);
                  case 1:
                    return Text('Unpaid', style: AppTypography.labelSmall);
                  case 2:
                    return Text('Partial', style: AppTypography.labelSmall);
                }
                return const Text('');
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeGroup(0, paid, AppPalette.successGreen),
          _makeGroup(1, unpaid, AppPalette.dangerRed),
          _makeGroup(2, partial, AppPalette.warningOrange),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroup(int x, double y, Color color) {
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: BorderRadius.circular(4)),
    ]);
  }

  Widget _buildPieChart(OverviewData? data) {
    if (data == null) return const Center(child: CircularProgressIndicator());
    final bill = data.totalBillBookingAmount?.toDouble() ?? 0;
    final letter = data.totalWithoutBillBookings?.toDouble() ?? 0;

    if (bill == 0 && letter == 0) {
      return Center(
          child: Text("No revenue data", style: AppTypography.bodySmall));
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 30, // Donut
              sections: [
                PieChartSectionData(
                  color: AppPalette.electricBlue,
                  value: bill == 0 && letter == 0 ? 1 : bill,
                  showTitle: false,
                  radius: 40,
                ),
                PieChartSectionData(
                  color: AppPalette.neonCyan.withValues(alpha: 0.5),
                  value: letter,
                  showTitle: false,
                  radius: 35,
                ),
              ],
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendItem(AppPalette.electricBlue, 'Bill', bill),
            const SizedBox(height: 8),
            _legendItem(
                AppPalette.neonCyan.withValues(alpha: 0.5), 'Cash', letter),
          ],
        )
      ],
    );
  }

  Widget _buildQuickAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ScaleButton(
      onTap: onTap,
      child: GlassContainer(
        isNeon: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border:
                    Border.all(color: color.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.headlineSmall
                          .copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          AppTypography.bodySmall.copyWith(color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.3), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, double amount) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.bodySmall),
            Text(CurrencyFormatter.formatIndianCurrencyCompact(amount),
                style: AppTypography.labelSmall
                    .copyWith(fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: GlassContainer(
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.zero,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Center(
                child: Text('ITL Menu', style: AppTypography.displaySmall),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_rounded),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            if (_isUser) ...[
              _drawerItem(
                  context,
                  'Bookings',
                  Icons.calendar_today_rounded,
                  () => BookingDashboardScreen(
                      userCode: _apiService.userCode ?? '')),
              _drawerItem(context, 'Expenses', Icons.receipt_long_rounded,
                  () => const ExpensesScreen()),
              _drawerItem(context, 'Invoices', Icons.description_rounded,
                  () => const InvoiceListScreen()),
              _drawerItem(
                  context,
                  'Reports',
                  Icons.analytics_rounded,
                  () => ReportsDashboardScreen(
                      userCode: _apiService.userCode ?? '')),
              _drawerItem(
                  context,
                  'Pending',
                  Icons.pending_actions_rounded,
                  () => PendingDashboardScreen(
                      userCode: _apiService.userCode ?? '')),
              _drawerItem(context, 'Meter Readings', Icons.speed_rounded,
                  () => const MeterDashboardScreen()),
            ] else if (_apiService.userType == 'admin') ...[
              _drawerItem(context, 'Expenses', Icons.receipt_long_rounded,
                  () => const ExpensesScreen()),
            ],
            const Spacer(),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: AppPalette.dangerRed),
              title: const Text('Logout',
                  style: TextStyle(color: AppPalette.dangerRed)),
              onTap: () async {
                final nav = Navigator.of(context);
                nav.pop();
                await _apiService.logout();
                _pusherService.disconnectPusher();
                nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (r) => false);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, String title, IconData icon,
      Widget Function() screen) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen()));
      },
    );
  }
}
