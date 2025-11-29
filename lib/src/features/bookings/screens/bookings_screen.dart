import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/services/download_util.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late TabController _tabController;

  bool _isLoading = false;
  String? _error;

  // Data maps
  Map<String, dynamic>? _bookings;
  Map<String, dynamic>? _withoutBillBookings;
  Map<String, dynamic>? _invoices;
  Map<String, dynamic>? _invoiceTxns;
  Map<String, dynamic>? _cashTxns;

  // Filter state
  String? _bookingPaymentOption;
  String? _bookingInvoiceStatus;
  String? _invoiceStatus;
  String? _invoiceType;
  int? _filterYear;
  int? _filterMonth;
  int? _withPayment;
  int? _transactionStatus;

  bool get _isUser => _apiService.userType == 'user';

  bool get _hasActiveFilters {
    return _filterYear != null ||
        _filterMonth != null ||
        _bookingPaymentOption != null ||
        _bookingInvoiceStatus != null ||
        _invoiceStatus != null ||
        _invoiceType != null ||
        _withPayment != null ||
        _transactionStatus != null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    if (_isUser) {
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _apiService.fetchBookings(
          paymentOption: _bookingPaymentOption,
          invoiceStatus: _bookingInvoiceStatus,
          year: _filterYear,
          month: _filterMonth,
        ),
        _apiService.fetchWithoutBillBookings(
          withPayment: _withPayment,
          transactionStatus: _transactionStatus,
          year: _filterYear,
          month: _filterMonth,
        ),
        _apiService.fetchInvoices(
          status: _invoiceStatus,
          type: _invoiceType,
          year: _filterYear,
          month: _filterMonth,
        ),
        _apiService.fetchInvoiceTransactions(
          year: _filterYear,
          month: _filterMonth,
        ),
        _apiService.fetchCashTransactions(
          transactionStatus: _transactionStatus,
          year: _filterYear,
          month: _filterMonth,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _bookings = results[0];
        _withoutBillBookings = results[1];
        _invoices = results[2];
        _invoiceTxns = results[3];
        _cashTxns = results[4];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showFilterDialog() {
    final currentYear = DateTime.now().year;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Options'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Year Filter
                const Text('Year',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  value: _filterYear,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Years')),
                    for (int year = currentYear;
                        year >= currentYear - 5;
                        year--)
                      DropdownMenuItem(
                          value: year, child: Text(year.toString())),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => _filterYear = value),
                ),
                const SizedBox(height: 16),

                // Month Filter
                const Text('Month',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  value: _filterMonth,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Months')),
                    DropdownMenuItem(value: 1, child: Text('January')),
                    DropdownMenuItem(value: 2, child: Text('February')),
                    DropdownMenuItem(value: 3, child: Text('March')),
                    DropdownMenuItem(value: 4, child: Text('April')),
                    DropdownMenuItem(value: 5, child: Text('May')),
                    DropdownMenuItem(value: 6, child: Text('June')),
                    DropdownMenuItem(value: 7, child: Text('July')),
                    DropdownMenuItem(value: 8, child: Text('August')),
                    DropdownMenuItem(value: 9, child: Text('September')),
                    DropdownMenuItem(value: 10, child: Text('October')),
                    DropdownMenuItem(value: 11, child: Text('November')),
                    DropdownMenuItem(value: 12, child: Text('December')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => _filterMonth = value),
                ),
                const SizedBox(height: 16),

                // Bookings Filters
                if (_tabController.index == 0) ...[
                  const Text('Payment Option',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _bookingPaymentOption,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                          value: 'with_bill', child: Text('With Bill')),
                      DropdownMenuItem(
                          value: 'without_bill', child: Text('Without Bill')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _bookingPaymentOption = value),
                  ),
                  const SizedBox(height: 16),
                  const Text('Invoice Status',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _bookingInvoiceStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                          value: 'not_generated', child: Text('Not Generated')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _bookingInvoiceStatus = value),
                  ),
                ],

                // Without Bill Filters
                if (_tabController.index == 1) ...[
                  const Text('With Payment',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: _withPayment,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                          value: 1, child: Text('With Cash Payment')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _withPayment = value),
                  ),
                  const SizedBox(height: 16),
                  const Text('Transaction Status',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: _transactionStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: 0, child: Text('Pending')),
                      DropdownMenuItem(value: 1, child: Text('Approved')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _transactionStatus = value),
                  ),
                ],

                // Invoice Filters
                if (_tabController.index == 2) ...[
                  const Text('Status',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _invoiceStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _invoiceStatus = value),
                  ),
                  const SizedBox(height: 16),
                  const Text('Type',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _invoiceType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                          value: 'tax_invoice', child: Text('Tax Invoice')),
                      DropdownMenuItem(
                          value: 'proforma_invoice',
                          child: Text('Proforma Invoice')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _invoiceType = value),
                  ),
                ],

                // Transaction Status Filter for Cash Txns
                if (_tabController.index == 4) ...[
                  const Text('Transaction Status',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: _transactionStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: 0, child: Text('Pending')),
                      DropdownMenuItem(value: 1, child: Text('Approved')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _transactionStatus = value),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _filterYear = null;
                  _filterMonth = null;
                  _bookingPaymentOption = null;
                  _bookingInvoiceStatus = null;
                  _invoiceStatus = null;
                  _invoiceType = null;
                  _withPayment = null;
                  _transactionStatus = null;
                });
                Navigator.pop(context);
                _loadAll();
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {});
                _loadAll();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<dynamic> _extractPagedList(Map<String, dynamic>? payload) {
    if (payload == null) return const [];
    final data = payload['data'];
    if (data is Map<String, dynamic> && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    return const [];
  }

  List<dynamic> _extractWithoutBillBookings(Map<String, dynamic>? payload) {
    if (payload == null) {
      debugPrint('❌ Without Bill: payload is null');
      return const [];
    }

    debugPrint('✅ Without Bill payload: ${jsonEncode(payload)}');

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final bookings = data['bookings'];
      debugPrint('📦 Bookings object: ${jsonEncode(bookings)}');

      if (bookings is Map<String, dynamic> && bookings['data'] is List) {
        final bookingsList = bookings['data'] as List<dynamic>;
        debugPrint('📋 Extracted ${bookingsList.length} without-bill bookings');
        return bookingsList;
      }
    }
    debugPrint('⚠️ No bookings data found in response structure');
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUser) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: kBlueGradient),
          ),
          title: const Text(
            'Bookings',
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'This feature is only available for marketing person users.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: kBlueGradient),
        ),
        title: const Text(
          'Bookings',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.blue.shade700,
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: 'All Bookings'),
                Tab(text: 'Without Bill'),
                Tab(text: 'Invoices'),
                Tab(text: 'Invoice Txns'),
                Tab(text: 'Cash Txns'),
              ],
            ),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: _showFilterDialog,
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadAll,
          )
        ],
      ),
      backgroundColor: kBackground,
      body: Column(
        children: [
          if (_hasActiveFilters) _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = <Widget>[];

    if (_filterYear != null) {
      chips.add(_filterChip('Year: $_filterYear', () {
        setState(() => _filterYear = null);
        _loadAll();
      }));
    }

    if (_filterMonth != null) {
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      chips.add(_filterChip('Month: ${months[_filterMonth!]}', () {
        setState(() => _filterMonth = null);
        _loadAll();
      }));
    }

    if (_bookingPaymentOption != null) {
      chips.add(_filterChip(
          'Payment: ${_bookingPaymentOption!.replaceAll('_', ' ')}', () {
        setState(() => _bookingPaymentOption = null);
        _loadAll();
      }));
    }

    if (_bookingInvoiceStatus != null) {
      chips.add(_filterChip(
          'Invoice: ${_bookingInvoiceStatus!.replaceAll('_', ' ')}', () {
        setState(() => _bookingInvoiceStatus = null);
        _loadAll();
      }));
    }

    if (_invoiceStatus != null) {
      chips.add(_filterChip('Status: $_invoiceStatus', () {
        setState(() => _invoiceStatus = null);
        _loadAll();
      }));
    }

    if (_invoiceType != null) {
      chips.add(_filterChip('Type: ${_invoiceType!.replaceAll('_', ' ')}', () {
        setState(() => _invoiceType = null);
        _loadAll();
      }));
    }

    if (_withPayment != null) {
      chips.add(_filterChip('With Cash Payment', () {
        setState(() => _withPayment = null);
        _loadAll();
      }));
    }

    if (_transactionStatus != null) {
      chips.add(_filterChip(
          'Status: ${_transactionStatus == 1 ? 'Approved' : 'Pending'}', () {
        setState(() => _transactionStatus = null);
        _loadAll();
      }));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _bookings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Error loading data',
                style: TextStyle(fontSize: 18, color: Colors.red.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildBookingsTab(),
        _buildWithoutBillTab(),
        _buildInvoicesTab(),
        _buildInvoiceTransactionsTab(),
        _buildCashTransactionsTab(),
      ],
    );
  }

  Widget _buildBookingsTab() {
    final items = _extractPagedList(_bookings);
    if (items.isEmpty) {
      return _buildEmptyState('No bookings found.', Icons.assignment_outlined);
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final booking =
              Map<String, dynamic>.from((items[index] as Map?) ?? {});
          return _BookingCard(booking: booking);
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildWithoutBillTab() {
    final items = _extractWithoutBillBookings(_withoutBillBookings);
    if (items.isEmpty) {
      return _buildEmptyState(
          'No without-bill bookings.', Icons.receipt_long_outlined);
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final booking =
              Map<String, dynamic>.from((items[index] as Map?) ?? {});
          return _BookingCard(booking: booking, isWithoutBill: true);
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildInvoicesTab() {
    final items = _extractPagedList(_invoices);
    if (items.isEmpty) {
      return _buildEmptyState('No invoices found.', Icons.description_outlined);
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final invoice =
              Map<String, dynamic>.from((items[index] as Map?) ?? {});
          return _InvoiceCard(invoice: invoice);
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildInvoiceTransactionsTab() {
    final items = _extractPagedList(_invoiceTxns);
    if (items.isEmpty) {
      return _buildEmptyState(
          'No invoice transactions.', Icons.payment_outlined);
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final tx = Map<String, dynamic>.from((items[index] as Map?) ?? {});
          return _TransactionCard(transaction: tx, type: 'invoice');
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildCashTransactionsTab() {
    final items = _extractPagedList(_cashTxns);
    if (items.isEmpty) {
      return _buildEmptyState(
          'No cash transactions.', Icons.account_balance_wallet_outlined);
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final tx = Map<String, dynamic>.from((items[index] as Map?) ?? {});
          return _TransactionCard(transaction: tx, type: 'cash');
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to format dates
String _formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '-';
  try {
    // Try parsing ISO format first (e.g., "2025-11-25T00:00:00.000000Z")
    final dt = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy').format(dt);
  } catch (e) {
    try {
      // Try parsing DD-MM-YYYY format (e.g., "08-11-2025")
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          final dt = DateTime(year, month, day);
          return DateFormat('dd MMM yyyy').format(dt);
        }
      }
    } catch (_) {}
    // Return original string if all parsing fails
    return dateStr;
  }
}

// Helper function to format currency
String _formatCurrency(dynamic value) {
  if (value == null) return '₹0.00';
  final numValue = num.tryParse(value.toString()) ?? 0;
  final formatter = NumberFormat('#,##,##0.00', 'en_IN');
  return '₹${formatter.format(numValue)}';
}

// Booking Card Widget
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isWithoutBill;

  const _BookingCard({required this.booking, this.isWithoutBill = false});

  @override
  Widget build(BuildContext context) {
    final id = booking['id']?.toString() ?? '';
    final refNo = booking['reference_no']?.toString() ?? '';
    final clientName = booking['client_name']?.toString() ?? '';
    final clientAddress = booking['client_address']?.toString() ?? '';
    final nameOfWork = booking['name_of_work']?.toString() ?? '';
    final contactNo = booking['contact_no']?.toString() ?? '';
    final jobOrderDate = booking['job_order_date']?.toString() ?? '';

    // Calculate total from items
    num totalAmount = 0;
    final items = booking['items'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        if (item is Map) {
          final amount = num.tryParse((item['amount'] ?? '0').toString()) ?? 0;
          totalAmount += amount;
        }
      }
    }

    final hasInvoice = booking['generated_invoice'] != null;
    final statusColor = isWithoutBill
        ? Colors.orange.shade700
        : (hasInvoice ? Colors.green.shade700 : Colors.blue.shade700);
    final statusLabel =
        isWithoutBill ? 'WITHOUT BILL' : (hasInvoice ? 'INVOICED' : 'PENDING');

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showBookingDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assignment_outlined,
                        color: Colors.blue.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          refNo.isNotEmpty ? refNo : 'Booking #$id',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nameOfWork,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Client Info
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Client',
                value: clientName,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: clientAddress,
              ),

              if (contactNo.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Contact',
                  value: contactNo,
                ),
              ],

              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // Bottom Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Job Order Date',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(jobOrderDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (totalAmount > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(totalAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingDetailsSheet(booking: booking),
    );
  }
}

// Invoice Card Widget
class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final invoiceNo = invoice['invoice_no']?.toString() ?? '';
    final issueTo = invoice['issue_to']?.toString() ?? '';
    final nameOfWork = invoice['name_of_work']?.toString() ?? '';
    final type = invoice['type']?.toString() ?? '';
    final totalAmount =
        invoice['total_amount'] ?? invoice['total_job_order_amount'];
    final invoiceDate = invoice['invoice_date']?.toString() ?? '';
    final status = invoice['status']?.toString() ?? '0';

    final isPaid = status == '1' || status.toLowerCase() == 'paid';
    final statusColor = isPaid ? Colors.green.shade700 : Colors.orange.shade700;
    final statusLabel = isPaid ? 'PAID' : 'UNPAID';

    final typeLabel = type.toUpperCase().replaceAll('_', ' ');
    final invoicePath = invoice['invoice_path']?.toString();

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showInvoiceDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.description_outlined,
                        color: Colors.purple.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoiceNo.isNotEmpty ? invoiceNo : 'Invoice',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (typeLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Details
              _InfoRow(
                icon: Icons.work_outline,
                label: 'Work',
                value: nameOfWork,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.business_outlined,
                label: 'Issue To',
                value: issueTo,
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // Bottom Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice Date',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(invoiceDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(totalAmount),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (invoicePath != null && invoicePath.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => downloadFile(invoicePath),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download Invoice'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InvoiceDetailsSheet(invoice: invoice),
    );
  }
}

// Transaction Card Widget
class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String type; // 'invoice' or 'cash'

  const _TransactionCard({required this.transaction, required this.type});

  @override
  Widget build(BuildContext context) {
    final id = transaction['id']?.toString() ?? '';
    final reference = transaction['reference']?.toString() ?? '';
    final amount = transaction['amount'];
    final status = transaction['status']?.toString() ??
        transaction['transaction_status']?.toString() ??
        '0';
    final date = transaction['date']?.toString() ??
        transaction['transaction_date']?.toString() ??
        transaction['created_at']?.toString() ??
        '';
    final paymentMode = transaction['payment_mode']?.toString() ?? '';
    final remarks = transaction['remarks']?.toString() ?? '';

    final isApproved = status == '1' || status.toLowerCase() == 'approved';
    final statusColor =
        isApproved ? Colors.green.shade700 : Colors.orange.shade700;
    final statusLabel = isApproved ? 'APPROVED' : 'PENDING';

    final iconData = type == 'cash'
        ? Icons.account_balance_wallet_outlined
        : Icons.payment_outlined;
    final iconColor = type == 'cash' ? Colors.green : Colors.blue;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColor.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reference.isNotEmpty ? reference : 'Transaction #$id',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (paymentMode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          paymentMode.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            if (remarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                remarks,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Bottom Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Date',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(amount),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Info Row Widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Booking Details Bottom Sheet
class _BookingDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingDetailsSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    final uploadLetterPath = booking['upload_letter_path']?.toString();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Booking Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 20),

              // Details
              _DetailItem(
                  label: 'Booking ID', value: booking['id']?.toString()),
              _DetailItem(
                  label: 'Reference No',
                  value: booking['reference_no']?.toString()),
              _DetailItem(
                  label: 'Marketing ID',
                  value: booking['marketing_id']?.toString()),
              _DetailItem(
                  label: 'Client Name',
                  value: booking['client_name']?.toString()),
              _DetailItem(
                  label: 'Client Address',
                  value: booking['client_address']?.toString()),
              _DetailItem(
                  label: 'Name of Work',
                  value: booking['name_of_work']?.toString()),
              _DetailItem(
                  label: 'Contact No',
                  value: booking['contact_no']?.toString()),
              _DetailItem(
                  label: 'Contact Email',
                  value: booking['contact_email']?.toString()),
              _DetailItem(
                  label: 'Report Issue To',
                  value: booking['report_issue_to']?.toString()),
              _DetailItem(
                  label: 'Job Order Date',
                  value: _formatDate(booking['job_order_date']?.toString())),
              _DetailItem(
                  label: 'Letter Date',
                  value: _formatDate(booking['letter_date']?.toString())),
              _DetailItem(
                  label: 'Payment Option',
                  value: booking['payment_option']?.toString().toUpperCase()),

              if (uploadLetterPath != null && uploadLetterPath.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => downloadFile(uploadLetterPath),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download Letter'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Invoice Details Bottom Sheet
class _InvoiceDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> invoice;

  const _InvoiceDetailsSheet({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final invoicePath = invoice['invoice_path']?.toString();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Invoice Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade900,
                ),
              ),
              const SizedBox(height: 20),

              // Details
              _DetailItem(
                  label: 'Invoice ID', value: invoice['id']?.toString()),
              _DetailItem(
                  label: 'Invoice No',
                  value: invoice['invoice_no']?.toString()),
              _DetailItem(
                  label: 'Issue To', value: invoice['issue_to']?.toString()),
              _DetailItem(
                  label: 'Name of Work',
                  value: invoice['name_of_work']?.toString()),
              _DetailItem(
                  label: 'Type',
                  value: invoice['type']
                      ?.toString()
                      .toUpperCase()
                      .replaceAll('_', ' ')),
              _DetailItem(
                  label: 'Letter Date',
                  value: _formatDate(invoice['letter_date']?.toString())),
              _DetailItem(
                  label: 'Invoice Date',
                  value: _formatDate(invoice['invoice_date']?.toString())),
              _DetailItem(
                  label: 'Address', value: invoice['address']?.toString()),
              _DetailItem(
                  label: 'Client GSTIN',
                  value: invoice['client_gstin']?.toString()),
              _DetailItem(
                  label: 'SAC Code', value: invoice['sac_code']?.toString()),
              _DetailItem(
                  label: 'Total Job Order Amount',
                  value: _formatCurrency(invoice['total_job_order_amount'])),
              _DetailItem(
                  label: 'CGST', value: '${invoice['cgst_percent'] ?? '0'}%'),
              _DetailItem(
                  label: 'SGST', value: '${invoice['sgst_percent'] ?? '0'}%'),
              _DetailItem(
                  label: 'IGST', value: '${invoice['igst_percent'] ?? '0'}%'),
              _DetailItem(
                  label: 'GST Amount',
                  value: _formatCurrency(invoice['gst_amount'])),
              _DetailItem(
                  label: 'Discount',
                  value: '${invoice['discount_percent'] ?? '0'}%'),
              _DetailItem(
                  label: 'Total Amount',
                  value: _formatCurrency(invoice['total_amount'] ??
                      invoice['total_job_order_amount'])),
              _DetailItem(
                  label: 'Status',
                  value: (invoice['status']?.toString() == '1' ||
                          invoice['status']?.toString().toLowerCase() == 'paid')
                      ? 'PAID'
                      : 'UNPAID'),

              if (invoicePath != null && invoicePath.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => downloadFile(invoicePath),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download Invoice'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Detail Item Widget
class _DetailItem extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailItem({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty || value == '-') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value!,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
