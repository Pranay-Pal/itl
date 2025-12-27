import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/compact_data_tile.dart';
import 'package:itl/src/common/widgets/design_system/filter_island.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/invoices/models/invoice_model.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/common/utils/file_viewer_service.dart';

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
  String? _selectedGeneratedStatus;

  // Debounce search
  DateTime? _lastTypingTime;

  List<String> get _activeFilters {
    final filters = <String>[];
    if (_searchQuery.isNotEmpty) filters.add('Search: "$_searchQuery"');
    if (_selectedMonth != null) {
      filters.add(
          'Month: ${DateFormat.MMM().format(DateTime(0, _selectedMonth!))}');
    }
    if (_selectedYear != null) filters.add('Year: $_selectedYear');
    if (_selectedPaymentStatus != null) {
      filters.add('Status: ${_selectedPaymentStatus?.toUpperCase()}');
    }
    if (_selectedGeneratedStatus != null && _selectedGeneratedStatus != 'all') {
      filters
          .add(_selectedGeneratedStatus == '1' ? 'Generated' : 'Not Generated');
    }
    return filters;
  }

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
            _lastTypingTime = null;
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
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (_currentPage == 1) _invoices = [];
    });

    try {
      final userCode = ApiService().userCode ?? '';
      if (userCode.isEmpty) throw Exception('User code not found');

      final response = await _marketingService.getInvoices(
        userCode: userCode,
        page: 1, // Always fetch page 1 on active refresh/filter
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
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoices: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreInvoices() async {
    if (_isMoreLoading) return;
    setState(() => _isMoreLoading = true);

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
        setState(() => _isMoreLoading = false);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedMonth = null;
      _selectedYear = null;
      _selectedPaymentStatus = null;
      _selectedGeneratedStatus = null;
      _currentPage = 1;
    });
    _fetchInvoices();
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
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
            Navigator.pop(context); // Close modal
            _fetchInvoices();
          },
        );
      },
    );
  }

  Color _getStatusColor(String? status, bool canGenerate) {
    if (canGenerate) return AppPalette.successGreen;
    if (status == null) return Colors.grey;
    if (status.toLowerCase().contains('paid')) return AppPalette.successGreen;
    if (status.toLowerCase().contains('pending')) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              title: Text('Invoices', style: AppTypography.headlineMedium),
              centerTitle: true,
              floating: true,
              snap: true,
              pinned: true,
              elevation: 0,
              backgroundColor: isDark
                  ? Colors.black.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.5),
              flexibleSpace: ClipRRect(
                child: Container(color: Colors.transparent),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {
                      _currentPage = 1;
                      _invoices = [];
                    });
                    _fetchInvoices();
                  },
                ),
              ],
            ),
          ],
          body: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilterIsland(
                    onFilterTap: _openFilterModal,
                    onClearTap: _clearFilters,
                    activeFilters: _activeFilters,
                  ),
                ),
              ),
              if (_isLoading && _invoices.isEmpty)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator())),
              if (!_isLoading && _invoices.isEmpty)
                const SliverFillRemaining(
                    child: Center(child: Text('No invoices found'))),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.gapPage, vertical: AppLayout.gapM),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _invoices.length) {
                        return _isMoreLoading
                            ? const Center(child: CircularProgressIndicator())
                            : const SizedBox(height: 60);
                      }

                      final item = _invoices[index];
                      // Use canGenerate or status to determine pill color/text
                      // The API response seems to have 'canGenerate' as boolean.
                      // We also have 'invoiceLetterUrl' presence.
                      final statusLabel = item.invoiceLetterUrl != null
                          ? 'Generated'
                          : 'Pending';
                      final statusColor =
                          _getStatusColor(null, item.invoiceLetterUrl != null);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppLayout.gapS),
                        child: DataListTile(
                          title: item.invoiceNo.isNotEmpty
                              ? item.invoiceNo
                              : 'No Invoice #',
                          subtitle: item.clientName ?? 'Unknown Client',
                          statusPill: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              statusLabel.toUpperCase(),
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          compactRows: [
                            InfoRow(
                                icon: Icons.calendar_today,
                                label: 'Date',
                                value: item.letterDate != null
                                    ? DateFormat('dd MMM yyyy')
                                        .format(item.letterDate!)
                                    : '-'),
                            InfoRow(
                                icon: Icons.attach_money,
                                label: 'Amount',
                                value:
                                    '₹${item.totalAmount.toStringAsFixed(2)}'),
                          ],
                          expandedRows: [
                            if (item.referenceNo != null &&
                                item.referenceNo!.isNotEmpty)
                              InfoRow(
                                  icon: Icons.tag,
                                  label: 'Ref',
                                  value: item.referenceNo!),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(),
                            ),

                            // Booking Items List
                            ...item.bookingItems.map((subItem) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.circle,
                                          size: 6, color: Colors.grey[400]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                subItem.sampleDescription ??
                                                    'Item',
                                                style:
                                                    AppTypography.labelSmall),
                                            if (subItem.jobOrderNo != null)
                                              Text('JO: ${subItem.jobOrderNo}',
                                                  style: AppTypography.bodySmall
                                                      .copyWith(
                                                          fontSize: 10,
                                                          color: Colors.grey)),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                    '${subItem.qty} x ₹${subItem.rate}',
                                                    style: AppTypography
                                                        .bodySmall
                                                        .copyWith(
                                                            color:
                                                                Colors.grey)),
                                                Text('₹${subItem.amount}',
                                                    style: AppTypography
                                                        .labelSmall),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                          actions: [
                            if (item.invoiceLetterUrl != null)
                              OutlinedButton.icon(
                                icon:
                                    const Icon(Icons.picture_as_pdf, size: 14),
                                label: const Text('View PDF'),
                                onPressed: () => FileViewerService.viewFile(
                                    context, item.invoiceLetterUrl!),
                              ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 50.ms)
                          .slideY(begin: 0.1, end: 0);
                    },
                    childCount: _invoices.length + 1,
                  ),
                ),
              ),
            ],
          ),
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

  // Year list helper
  List<int> get _years => List.generate(5, (i) => DateTime.now().year - i);

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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
              Text('Filter Invoices', style: AppTypography.headlineSmall),
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
                child: DropdownButtonFormField<int?>(
                  initialValue: _year,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._years.map(
                        (y) => DropdownMenuItem(value: y, child: Text('$y')))
                  ],
                  onChanged: (v) => setState(() => _year = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _month,
                  decoration: InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...List.generate(12, (i) => i + 1).map((m) =>
                        DropdownMenuItem(
                            value: m,
                            child:
                                Text(DateFormat.MMM().format(DateTime(0, m)))))
                  ],
                  onChanged: (v) => setState(() => _month = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String?>(
            initialValue: _generatedStatus,
            decoration: InputDecoration(
              labelText: 'Generation Status',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: '1', child: Text('Generated')),
              DropdownMenuItem(value: '0', child: Text('Not Generated')),
            ],
            onChanged: (v) => setState(() => _generatedStatus = v),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppPalette.electricBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                widget.onApply(_month, _year, _status, _generatedStatus);
              },
              child: const Text('Apply Filters',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
