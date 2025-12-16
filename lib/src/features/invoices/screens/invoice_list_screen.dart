import 'package:flutter/material.dart';
import 'package:itl/src/features/invoices/models/invoice_model.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final MarketingService _marketingService = MarketingService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Invoice> _invoices = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  int _currentPage = 1;
  int _lastPage = 1;

  // Filters
  String _searchQuery = '';
  int? _selectedMonth;
  int? _selectedYear;
  String? _selectedPaymentStatus;
  String?
      _selectedGeneratedStatus; // 'all', '1' (Generated), '0' (Not Generated)

  // Debounce search
  DateTime? _lastTypingTime;

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    const duration = Duration(milliseconds: 500);
    if (_lastTypingTime != null) {
      // Cancel previous timer logic if implemented with Timer, but checking timestamps is easier for simple debounce
    }
    setState(() {
      _lastTypingTime = DateTime.now();
    });

    Future.delayed(duration, () {
      if (_lastTypingTime != null &&
          DateTime.now().difference(_lastTypingTime!) >= duration) {
        if (_searchQuery != _searchController.text) {
          setState(() {
            _searchQuery = _searchController.text;
            _currentPage = 1;
          });
          _fetchInvoices();
        }
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isMoreLoading &&
        _currentPage < _lastPage) {
      _loadMoreInvoices();
    }
  }

  Future<void> _fetchInvoices() async {
    setState(() {
      _isLoading = true;
      _invoices = []; // Reset list on new fetch/filter
    });

    try {
      final userCode = ApiService().userCode ?? '';
      if (userCode.isEmpty) {
        throw Exception('User code not found');
      }

      final response = await _marketingService.getInvoices(
        userCode: userCode,
        page: 1,
        search: _searchQuery,
        month: _selectedMonth,
        year: _selectedYear,
        paymentStatus: _selectedPaymentStatus,
        generatedStatus:
            _selectedGeneratedStatus == 'all' ? null : _selectedGeneratedStatus,
      );

      if (mounted) {
        setState(() {
          _invoices = response.invoices;
          _currentPage = response.currentPage;
          _lastPage = response.lastPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoices: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreInvoices() async {
    setState(() {
      _isMoreLoading = true;
    });

    try {
      final userCode = ApiService().userCode ?? '';
      final nextPage = _currentPage + 1;

      final response = await _marketingService.getInvoices(
        userCode: userCode,
        page: nextPage,
        search: _searchQuery,
        month: _selectedMonth,
        year: _selectedYear,
        paymentStatus: _selectedPaymentStatus,
        generatedStatus:
            _selectedGeneratedStatus == 'all' ? null : _selectedGeneratedStatus,
      );

      if (mounted) {
        setState(() {
          _invoices.addAll(response.invoices);
          _currentPage = response.currentPage;
          _lastPage = response.lastPage;
          _isMoreLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMoreLoading = false;
        });
      }
    }
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _InvoiceFilterModal(
          initialMonth: _selectedMonth,
          initialYear: _selectedYear,
          initialStatus: _selectedPaymentStatus,
          initialGeneratedStatus: _selectedGeneratedStatus,
          onApply: (month, year, status, generatedStatus) {
            setState(() {
              _selectedMonth = month;
              _selectedYear = year;
              _selectedPaymentStatus = status;
              _selectedGeneratedStatus = generatedStatus;
              _currentPage = 1;
            });
            _fetchInvoices();
          },
        );
      },
    );
  }

  void _showItemsModal(Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Items for ${invoice.invoiceNo}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: invoice.bookingItems.isEmpty
                      ? const Center(child: Text('No items found'))
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.all(16),
                          itemCount: invoice.bookingItems.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 24),
                          itemBuilder: (context, index) {
                            final item = invoice.bookingItems[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.sampleDescription ?? 'No Description',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                if (item.jobOrderNo != null)
                                  Text('Job Order: ${item.jobOrderNo}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Qty: ${item.qty}',
                                        style: const TextStyle(fontSize: 13)),
                                    Text('Rate: ₹${item.rate}',
                                        style: const TextStyle(fontSize: 13)),
                                    Text(
                                      '₹${item.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch invoice URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Invoices',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterModal,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Invoice No or Reference...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // Expanded List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                    ? const Center(child: Text('No invoices found'))
                    : RefreshIndicator(
                        onRefresh: _fetchInvoices,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              _invoices.length + (_isMoreLoading ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == _invoices.length) {
                              return const Center(
                                  child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ));
                            }
                            return _buildInvoiceCard(_invoices[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    // Format date: e.g. 12 Dec 2025
    final dateStr = invoice.letterDate != null
        ? DateFormat('dd MMM yyyy').format(invoice.letterDate!)
        : 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Invoice No & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    invoice.invoiceNo,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Client info
            Text(
              invoice.clientName ?? 'Unknown Client',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            if (invoice.referenceNo != null && invoice.referenceNo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ref: ${invoice.referenceNo}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),

            // View Items Button (Small Text Button)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => _showItemsModal(invoice),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View ${invoice.bookingItems.length} Items',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios,
                        size: 10, color: Colors.blue),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),

            // Footer: Amount & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL AMOUNT',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${invoice.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                // Action Button
                if (invoice.invoiceLetterUrl != null)
                  ElevatedButton.icon(
                    onPressed: () => _openPdf(invoice.invoiceLetterUrl!),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('View PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50], // Light red for PDF
                      foregroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Processing',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceFilterModal extends StatefulWidget {
  final int? initialMonth;
  final int? initialYear;
  final String? initialStatus;
  final String? initialGeneratedStatus;
  final Function(int? month, int? year, String? status, String? generatedStatus)
      onApply;

  const _InvoiceFilterModal({
    this.initialMonth,
    this.initialYear,
    this.initialStatus,
    this.initialGeneratedStatus,
    required this.onApply,
  });

  @override
  State<_InvoiceFilterModal> createState() => _InvoiceFilterModalState();
}

class _InvoiceFilterModalState extends State<_InvoiceFilterModal> {
  int? _month;
  int? _year;
  String? _status;
  String? _generatedStatus;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
    _status = widget.initialStatus;
    _generatedStatus = widget.initialGeneratedStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filter Invoices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),

          // Year & Month Row
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _year,
                      isDense: true,
                      isExpanded: true,
                      items: List.generate(5, (index) {
                        final y = DateTime.now().year - index;
                        return DropdownMenuItem(
                            value: y, child: Text(y.toString()));
                      }),
                      onChanged: (v) => setState(() => _year = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _month,
                      isDense: true,
                      isExpanded: true,
                      items: List.generate(13, (index) {
                        if (index == 0) {
                          return const DropdownMenuItem(
                              value: null, child: Text('All'));
                        }
                        return DropdownMenuItem(
                          value: index,
                          child: Text(
                              DateFormat('MMMM').format(DateTime(2022, index))),
                        );
                      }),
                      onChanged: (v) => setState(() => _month = v),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Payment Status',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _status,
                isDense: true,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: '0', child: Text('Unpaid')),
                  DropdownMenuItem(value: '1', child: Text('Partially Paid')),
                  DropdownMenuItem(value: '2', child: Text('Paid')),
                  DropdownMenuItem(value: '3', child: Text('Processed')),
                  DropdownMenuItem(value: '4', child: Text('Dropped')),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Generated Status
          // Generated Status
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Generated Status',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _generatedStatus,
                isDense: true,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Default')),
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: '1', child: Text('Generated')),
                  DropdownMenuItem(value: '0', child: Text('Not Generated')),
                ],
                onChanged: (v) => setState(() => _generatedStatus = v),
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                widget.onApply(_month, _year, _status, _generatedStatus);
                Navigator.pop(context);
              },
              child: const Text('Apply Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
