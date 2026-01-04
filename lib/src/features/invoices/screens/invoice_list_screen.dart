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
import 'package:itl/src/features/bookings/models/booking_model.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/common/utils/file_viewer_service.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen>
    with SingleTickerProviderStateMixin {
  final MarketingService _marketingService = MarketingService();
  late TabController _tabController;
  final ScrollController _generatedScrollController = ScrollController();
  final ScrollController _pendingScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Data
  List<Invoice> _invoices = [];
  List<BookingGrouped> _pendingInvoices = [];

  // Loading States
  bool _isLoading = false;
  bool _isMoreLoading = false;

  // Pagination
  int _pageGenerated = 1;
  int _lastPageGenerated = 1;

  int _pagePending = 1;
  int _lastPagePending = 1;

  // Filters
  String _searchQuery = '';
  int? _selectedMonth;
  int? _selectedYear;
  String? _selectedPaymentStatus; // For Generated only
  int? _selectedDepartment;

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
    if (_selectedDepartment != null) {
      final depts = {1: 'General', 2: 'BIS', 3: 'NBCC', 4: 'Uttarakhand'};
      filters.add('Dept: ${depts[_selectedDepartment] ?? 'Unknown'}');
    }
    if (_tabController.index == 0 && _selectedPaymentStatus != null) {
      filters.add('Status: ${_selectedPaymentStatus?.toUpperCase()}');
    }
    return filters;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _generatedScrollController.addListener(_scrollListener);
    _pendingScrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _generatedScrollController.dispose();
    _pendingScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      // Re-fetch if list is empty or filters might apply differently
      // Ideally we keep data but refreshing is safer
      if ((_tabController.index == 0 && _invoices.isEmpty) ||
          (_tabController.index == 1 && _pendingInvoices.isEmpty)) {
        _fetchData();
      }
      setState(() {}); // Rebuild to update filters display
    }
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
            _resetPagination();
            _lastTypingTime = null;
          });
          _fetchData();
        }
      }
    });
  }

  void _resetPagination() {
    _pageGenerated = 1;
    _pagePending = 1;
    _invoices = [];
    _pendingInvoices = [];
  }

  void _scrollListener() {
    final controller = _tabController.index == 0
        ? _generatedScrollController
        : _pendingScrollController;
    final lastPage =
        _tabController.index == 0 ? _lastPageGenerated : _lastPagePending;
    final currentPage =
        _tabController.index == 0 ? _pageGenerated : _pagePending;

    if (controller.position.pixels >=
            controller.position.maxScrollExtent - 200 &&
        !_isMoreLoading &&
        currentPage < lastPage) {
      _loadMoreData();
    }
  }

  Future<void> _fetchData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final userCode = ApiService().userCode ?? '';
      if (userCode.isEmpty) throw Exception('User code not found');

      if (_tabController.index == 0) {
        // Fetch Generated Invoices
        final response = await _marketingService.getInvoices(
          userCode: userCode,
          page: 1,
          search: _searchQuery,
          month: _selectedMonth,
          year: _selectedYear,
          paymentStatus: _selectedPaymentStatus,
          department: _selectedDepartment,
          // generated_status implicit by endpoint choice logic?
          // User asked for separation. invoices/list IS generated.
          // And bookings/generate-invoice IS pending.
        );
        if (mounted) {
          setState(() {
            _invoices = response.invoices;
            _pageGenerated = response.currentPage;
            _lastPageGenerated = response.lastPage;
          });
        }
      } else {
        // Fetch Pending Invoices
        final response = await _marketingService.getPendingInvoices(
          userCode: userCode,
          page: 1,
          search: _searchQuery,
          month: _selectedMonth,
          year: _selectedYear,
          department: _selectedDepartment,
        );
        if (mounted) {
          setState(() {
            _pendingInvoices = response.bookings;
            _pagePending = response.currentPage;
            _lastPagePending = response.lastPage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreData() async {
    if (_isMoreLoading) return;
    setState(() => _isMoreLoading = true);

    try {
      final userCode = ApiService().userCode ?? '';
      if (_tabController.index == 0) {
        final nextPage = _pageGenerated + 1;
        final response = await _marketingService.getInvoices(
          userCode: userCode,
          page: nextPage,
          search: _searchQuery,
          month: _selectedMonth,
          year: _selectedYear,
          paymentStatus: _selectedPaymentStatus,
          department: _selectedDepartment,
        );
        if (mounted) {
          setState(() {
            _invoices.addAll(response.invoices);
            _pageGenerated = response.currentPage;
            _lastPageGenerated = response.lastPage;
          });
        }
      } else {
        final nextPage = _pagePending + 1;
        final response = await _marketingService.getPendingInvoices(
          userCode: userCode,
          page: nextPage,
          search: _searchQuery,
          month: _selectedMonth,
          year: _selectedYear,
          department: _selectedDepartment,
        );
        if (mounted) {
          setState(() {
            _pendingInvoices.addAll(response.bookings);
            _pagePending = response.currentPage;
            _lastPagePending = response.lastPage;
          });
        }
      }
    } catch (e) {
      // Handle error silent or snackbar
    } finally {
      if (mounted) setState(() => _isMoreLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    // Reset current tab data
    if (_tabController.index == 0) {
      setState(() {
        _invoices = [];
        _pageGenerated = 1;
      });
    } else {
      setState(() {
        _pendingInvoices = [];
        _pagePending = 1;
      });
    }
    await _fetchData();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedMonth = null;
      _selectedYear = null;
      _selectedPaymentStatus = null;
      _selectedDepartment = null;
      _resetPagination();
    });
    _fetchData();
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
          initialDepartment: _selectedDepartment,
          showStatus: _tabController.index == 0,
          onApply: (month, year, status, dept) {
            setState(() {
              _selectedMonth = month;
              _selectedYear = year;
              _selectedPaymentStatus = status;
              _selectedDepartment = dept;
              _resetPagination();
            });
            Navigator.pop(context); // Close modal
            _fetchData();
          },
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'paid':
        return AppPalette.successGreen;
      case 'unpaid':
        return AppPalette.dangerRed;
      case 'pending':
        return AppPalette.warningOrange; // or Colors.orange
      case 'partial':
        return Colors.amber;
      case 'settle':
        return AppPalette.electricBlue;
      case 'cancel':
        return Colors.grey;
      default:
        return Colors.grey;
    }
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: TabBar(
                  controller: _tabController,
                  labelStyle: AppTypography.labelLarge,
                  unselectedLabelStyle: AppTypography.bodyMedium,
                  indicatorColor: AppPalette.electricBlue,
                  labelColor: AppPalette.electricBlue,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Generated'),
                    Tab(text: 'Pending'),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _onRefresh,
                ),
              ],
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildGeneratedList(),
              _buildPendingList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratedList() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _generatedScrollController,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildFilterSliver(),
          if (_isLoading && _invoices.isEmpty)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _invoices.isEmpty)
            const SliverFillRemaining(
                child: Center(child: Text('No generated invoices found'))),
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
                  // Prioritize paymentStatus from API, fallback to logic based on URL
                  final statusRaw = item.paymentStatus;
                  final hasPdf = item.invoiceLetterUrl != null;

                  String statusLabel;
                  Color statusColor;

                  if (statusRaw != null) {
                    statusLabel = statusRaw;
                    statusColor = _getStatusColor(statusRaw);
                  } else {
                    statusLabel = hasPdf ? 'Generated' : 'Pending';
                    statusColor =
                        hasPdf ? AppPalette.successGreen : Colors.orange;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppLayout.gapS),
                    child: DataListTile(
                      title: item.invoiceNo.isNotEmpty
                          ? item.invoiceNo
                          : 'Reference #${item.referenceNo ?? "N/A"}',
                      subtitle: item.clientName ?? 'Unknown Client',
                      statusPill: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
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
                            value: '₹${item.totalAmount.toStringAsFixed(2)}'),
                      ],
                      expandedRows: [
                        if (item.referenceNo != null &&
                            item.referenceNo!.isNotEmpty)
                          InfoRow(
                              icon: Icons.tag,
                              label: 'Ref',
                              value: item.referenceNo!),
                      ],
                      actions: [
                        if (item.invoiceLetterUrl != null)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 14),
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
    );
  }

  Widget _buildPendingList() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _pendingScrollController,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildFilterSliver(),
          if (_isLoading && _pendingInvoices.isEmpty)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _pendingInvoices.isEmpty)
            const SliverFillRemaining(
                child: Center(child: Text('No pending invoices found'))),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppLayout.gapPage, vertical: AppLayout.gapM),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _pendingInvoices.length) {
                    return _isMoreLoading
                        ? const Center(child: CircularProgressIndicator())
                        : const SizedBox(height: 60);
                  }

                  final item = _pendingInvoices[index];
                  // These are bookings waiting for generation.
                  // Mirrors 'generateInvoiceListApi'.

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppLayout.gapS),
                    child: DataListTile(
                      title: item.referenceNo ?? 'No Ref',
                      subtitle: item.clientName ?? 'Unknown Client',
                      statusPill: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PENDING',
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      compactRows: [
                        InfoRow(
                            icon: Icons.calendar_today,
                            label: 'Job Date',
                            value: item.jobOrderDate ?? '-'),
                        InfoRow(
                            icon: Icons.list_alt,
                            label: 'Items',
                            value: '${item.itemsCount ?? 0}'),
                      ],
                      expandedRows: [
                        // Show items if needed
                        ...item.items.map((subItem) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                  '${subItem.jobOrderNo}: ${subItem.sampleDescription} (₹${subItem.amount})',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: Colors.grey)),
                            ))
                      ],
                      actions: [
                        // "Generate" button placeholder
                        // User mentioned endpoint: GET .../generate-invoice returns list.
                        // Existing UI uses 'superadmin.bookingInvoiceStatuses.generateInvoice'.
                        // I will add a disabled button or active one if I had logic.
                        OutlinedButton.icon(
                          icon: const Icon(Icons.receipt_long, size: 14),
                          label: const Text('Generate'),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Invoice generation not implemented on mobile yet.')));
                          },
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 50.ms)
                      .slideY(begin: 0.1, end: 0);
                },
                childCount: _pendingInvoices.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FilterIsland(
          onFilterTap: _openFilterModal,
          onClearTap: _clearFilters,
          activeFilters: _activeFilters,
        ),
      ),
    );
  }
}

class _InvoiceFilterModal extends StatefulWidget {
  final int? initialMonth;
  final int? initialYear;
  final String? initialStatus;
  final int? initialDepartment;
  final bool showStatus;
  final Function(int? month, int? year, String? status, int? dept) onApply;

  const _InvoiceFilterModal({
    this.initialMonth,
    this.initialYear,
    this.initialStatus,
    this.initialDepartment,
    this.showStatus = true,
    required this.onApply,
  });

  @override
  State<_InvoiceFilterModal> createState() => _InvoiceFilterModalState();
}

class _InvoiceFilterModalState extends State<_InvoiceFilterModal> {
  int? _month;
  int? _year;
  String? _status;
  int? _department;

  // Year list helper
  List<int> get _years => List.generate(5, (i) => DateTime.now().year - i);

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
    _status = widget.initialStatus;
    _department = widget.initialDepartment;
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

          // Department Dropdown
          DropdownButtonFormField<int?>(
            initialValue: _department,
            decoration: InputDecoration(
              labelText: 'Department',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 1, child: Text('General')),
              DropdownMenuItem(value: 2, child: Text('BIS')),
              DropdownMenuItem(value: 3, child: Text('NBCC')),
              DropdownMenuItem(value: 4, child: Text('UTTRAKHAND')),
            ],
            onChanged: (v) => setState(() => _department = v),
          ),
          const SizedBox(height: 16),

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

          if (widget.showStatus)
            DropdownButtonFormField<String?>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: 'Payment Status',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                DropdownMenuItem(value: 'cancel', child: Text('Cancel')),
                DropdownMenuItem(value: 'partial', child: Text('Partial')),
                DropdownMenuItem(value: 'settle', child: Text('Settle')),
              ],
              onChanged: (v) => setState(() => _status = v),
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
                widget.onApply(_month, _year, _status, _department);
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
