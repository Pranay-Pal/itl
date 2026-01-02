import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/profile/models/marketing_profile_model.dart';
import 'package:itl/src/services/marketing_service.dart';

class PersonalLedgerScreen extends StatefulWidget {
  final String userCode;

  const PersonalLedgerScreen({super.key, required this.userCode});

  @override
  State<PersonalLedgerScreen> createState() => _PersonalLedgerScreenState();
}

class _PersonalLedgerScreenState extends State<PersonalLedgerScreen> {
  final MarketingService _marketingService = MarketingService();
  bool _isLoading = true;
  MarketingProfileData? _data;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response =
          await _marketingService.getProfile(userCode: widget.userCode);
      if (mounted) {
        setState(() {
          _data = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Personal Ledger', style: AppTypography.headlineMedium),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? const Center(child: Text('No data found'))
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final stats = _data!.stats;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppLayout.gapPage),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Summary Card
          _buildSummaryCard(stats, currencyFormat),
          const SizedBox(height: 24),

          // Group 1: Bookings & Bills
          Text('Bookings', style: AppTypography.headlineSmall),
          const SizedBox(height: 12),
          _buildGrid([
            _StatItem('Total Bookings', stats.totalBookings.toString(),
                Icons.book, Colors.blue),
            _StatItem('Total Value',
                currencyFormat.format(stats.totalBookingAmount), Icons.attach_money, Colors.blue),
            _StatItem('Without Bill', stats.withoutBillBookings.toString(),
                Icons.money_off, Colors.orange),
            _StatItem('W/O Bill Value',
                currencyFormat.format(stats.totalWithoutBillBookings), Icons.warning, Colors.orange),
          ]),
          const SizedBox(height: 24),

          // Group 2: Invoices
          Text('Invoices', style: AppTypography.headlineSmall),
          const SizedBox(height: 12),
          _buildGrid([
            _StatItem('Not Generated', stats.notGeneratedInvoices.toString(),
                Icons.pending_actions, Colors.red),
            _StatItem('Pending Value',
                currencyFormat.format(stats.totalNotGeneratedInvoicesAmount), Icons.access_time, Colors.red),
            _StatItem('Partial Tax', stats.partialTaxInvoices.toString(),
                Icons.pie_chart, Colors.purple),
            _StatItem('Unpaid', stats.unpaidInvoices.toString(),
                Icons.error_outline, Colors.red),
          ]),
          const SizedBox(height: 24),

          // Group 3: Cash & Transactions
          Text('Cash & Transactions', style: AppTypography.headlineSmall),
          const SizedBox(height: 12),
          _buildGrid([
            _StatItem('Transactions', stats.transactions.toString(),
                Icons.swap_horiz, Colors.green),
            _StatItem('Trans. Value',
                currencyFormat.format(stats.totalTransactionsAmount), Icons.account_balance_wallet, Colors.green),
            _StatItem('Due Amount',
                currencyFormat.format(stats.totalDueAmount), Icons.payments, Colors.deepOrange),
            _StatItem('Settled',
                currencyFormat.format(stats.totalSettledAmount), Icons.check_circle, Colors.teal),
          ]),
           const SizedBox(height: 24),

          // Recent Transactions
          Text('Recent Transactions', style: AppTypography.headlineSmall),
          const SizedBox(height: 12),
          ..._data!.recentTransactions.map((t) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppPalette.electricBlue.withValues(alpha: 0.1),
                    child: Icon(Icons.receipt, color: AppPalette.electricBlue),
                  ),
                  title: Text(t.invoiceNo ?? 'Unknown Invoice'),
                  subtitle: Text(t.transactionDate ?? ''),
                  trailing: Text(
                    currencyFormat.format(t.amountReceived),
                    style: AppTypography.labelLarge.copyWith(color: AppPalette.successGreen),
                  ),
                ),
              )),
        ],
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildSummaryCard(MarketingStats stats, NumberFormat format) {
    return Container(
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
                  Text('Total Booking Value',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(format.format(stats.totalBookingAmount),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.analytics, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniParam('Clients', stats.allClients.toString()),
              _buildMiniParam('Personal Exp', format.format(stats.totalPersonalExpensesAmount)),
              _buildMiniParam('TDS', format.format(stats.tdsAmount)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniParam(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGrid(List<_StatItem> items) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: items.map((item) => _buildStatCard(item)).toList(),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.icon, color: item.color, size: 20),
             // could add a mini sparkline here
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.value,
                  style: AppTypography.labelLarge.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(item.label,
                  style: AppTypography.bodySmall.copyWith(color: Colors.grey),
                   maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          )
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}
