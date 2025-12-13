import 'package:flutter/material.dart';

import 'package:itl/src/features/bookings/models/booking_model.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/shared/screens/pdf_viewer_screen.dart';

class BookingDashboardScreen extends StatefulWidget {
  final String userCode; // e.g., MKT001

  const BookingDashboardScreen({super.key, required this.userCode});

  @override
  State<BookingDashboardScreen> createState() => _BookingDashboardScreenState();
}

class _BookingDashboardScreenState extends State<BookingDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MarketingService _marketingService = MarketingService();

  // Filters
  int? _selectedMonth;
  int? _selectedYear;
  final TextEditingController _searchController = TextEditingController();
  final int _currentYear = DateTime.now().year;

  // Pagination & Loading
  bool _isLoading = false;
  List<BookingParent> _bookings = [];
  List<BookingParent> _letters = []; // For "By Letter" tab

  // Pagination State
  int _currentPageBooking = 1;
  int _lastPageBooking = 1;
  int _currentPageLetter = 1;
  int _lastPageLetter = 1;
  bool _isLoadingMore = false;
  final ScrollController _bookingScrollController = ScrollController();
  final ScrollController _letterScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Scroll listeners for pagination
    _bookingScrollController.addListener(_onBookingScroll);
    _letterScrollController.addListener(_onLetterScroll);

    // Initial fetch
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bookingScrollController.dispose();
    _letterScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onBookingScroll() {
    if (_bookingScrollController.position.pixels >=
        _bookingScrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _onLetterScroll() {
    if (_letterScrollController.position.pixels >=
        _letterScrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      _fetchData();
    }
  }

  Future<void> _fetchData({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      if (_isLoading) return;
      setState(() => _isLoading = true);
    }

    try {
      if (_tabController.index == 0) {
        // Tab 1: Show Booking
        final pageToFetch = isLoadMore ? _currentPageBooking + 1 : 1;
        if (isLoadMore && pageToFetch > _lastPageBooking) return;

        final response = await _marketingService.getBookings(
          userCode: widget.userCode,
          month: _selectedMonth,
          year: _selectedYear,
          search: _searchController.text,
          page: pageToFetch,
        );

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _bookings.addAll(response.data);
            } else {
              _bookings = response.data;
            }
            _currentPageBooking = response.currentPage;
            _lastPageBooking = response.lastPage;
          });
        }
      } else {
        // Tab 2: Booking By Letter
        final pageToFetch = isLoadMore ? _currentPageLetter + 1 : 1;
        if (isLoadMore && pageToFetch > _lastPageLetter) return;

        final response = await _marketingService.getBookingsByLetter(
          userCode: widget.userCode,
          month: _selectedMonth,
          year: _selectedYear,
          search: _searchController.text,
          page: pageToFetch,
        );

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _letters.addAll(response.data);
            } else {
              _letters = response.data;
            }
            _currentPageLetter = response.currentPage;
            _lastPageLetter = response.lastPage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _loadMoreData() {
    // Check if we can load more based on current tab
    if (_tabController.index == 0) {
      if (_currentPageBooking < _lastPageBooking &&
          !_isLoadingMore &&
          !_isLoading) {
        _fetchData(isLoadMore: true);
      }
    } else {
      if (_currentPageLetter < _lastPageLetter &&
          !_isLoadingMore &&
          !_isLoading) {
        _fetchData(isLoadMore: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: kBlueGradient),
        ),
        title: const Text('Bookings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Show Booking'),
            Tab(text: 'Without Bill'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _bookings = [];
                _letters = [];
              });
              _fetchData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildShowBookingTab(isDark),
                _buildByLetterTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  ),
                  onSubmitted: (_) => _fetchData(),
                ),
              ),
              const SizedBox(width: 8),
              _buildDropdown(
                  'Month',
                  _selectedMonth,
                  List.generate(12, (index) => index + 1),
                  (val) => setState(() => _selectedMonth = val)),
              const SizedBox(width: 8),
              _buildDropdown(
                  'Year',
                  _selectedYear,
                  List.generate(5, (index) => _currentYear - index),
                  (val) => setState(() => _selectedYear = val)),
              IconButton(
                  onPressed: _fetchData,
                  icon: Icon(Icons.filter_list, color: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
      String hint, T? value, List<T> items, Function(T?) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e.toString())))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // --- Tab 1: Show Booking (Flat List of Items) ---
  // --- Tab 1: Show Booking (Styled List) ---
  Widget _buildShowBookingTab(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No bookings found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return _buildBookingItemsList(isDark, _bookingScrollController);
  }

  Widget _buildBookingItemsList(bool isDark, ScrollController controller) {
    // Flatten
    List<Map<String, dynamic>> flatItems = [];
    for (var parent in _bookings) {
      for (var item in parent.items) {
        flatItems.add({'parent': parent, 'item': item});
      }
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(12),
      itemCount: flatItems.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == flatItems.length) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ));
        }
        final data = flatItems[index];
        final BookingParent parent = data['parent'];
        final BookingItem item = data['item'];

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        parent.clientName ?? 'Unknown Client',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    _buildStatusPill(item.status ?? 'Pending'),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.receipt, 'Ref:', parent.referenceNo),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.work, 'Job:', item.jobOrderNo),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.description, 'Sample:', item.particulars),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (parent.uploadLetterPath != null)
                      TextButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('View Letter'),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _viewLetter(parent.uploadLetterPath),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label ',
          style:
              const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --- Tab 2: Booking By Letter (Grouped by Parent) ---
  // --- Tab 2: Booking By Letter (Grouped Cards) ---
  Widget _buildByLetterTab(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_letters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No letters found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _letterScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _letters.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _letters.length) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ));
        }
        try {
          final parent = _letters[index];
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Safe access
                  Text(
                    parent.clientName ?? 'Unknown Client',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.receipt_long, 'Ref:', parent.referenceNo),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Actions
                      Row(
                        children: [
                          if (parent.uploadLetterPath != null)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf,
                                  size: 16, color: Colors.white),
                              label: const Text('Letter'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              onPressed: () =>
                                  _viewLetter(parent.uploadLetterPath),
                            ),
                          const SizedBox(width: 8),
                          // Only show button if items exist, OR show 'No Items' text to be clear
                          if (parent.items.isNotEmpty)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.list, size: 16),
                              label: Text('${parent.items.length} Items'),
                              onPressed: () => _showLetterDetails(parent),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Text(
                                'No Items',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12),
                              ),
                            ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          );
        } catch (e, stack) {
          debugPrint('Error rendering item: $e\n$stack');
          return Center(
              child: Text('Error rendering item: $e',
                  style: const TextStyle(color: Colors.red)));
        }
      },
    );
  }

  Widget _buildStatusPill(String status) {
    Color color = Colors.orange;
    if (status.toLowerCase().contains('issue')) {
      color = const Color(0xFF007AFF); // Blue-ish for issue
    }
    if (status.toLowerCase().contains('cancel')) {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  void _viewLetter(String? path) async {
    if (path == null) return;

    // Construct URL logic
    String url = path;
    if (!path.startsWith('http')) {
      url =
          "https://mediumslateblue-hummingbird-258203.hostingersite.com/uploads/bookings/$path";
    }

    // Navigate to in-app PDF viewer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            PdfViewerScreen(url: url, title: 'Booking Letter'),
      ),
    );
  }

  Future<void> _showLetterDetails(BookingParent parent) async {
    // Show dialog with loading state initially
    showDialog(
      context: context,
      builder: (ctx) => _BookingDetailsDialog(
        parent: parent,
        marketingService: _marketingService,
        userCode: widget.userCode,
      ),
    );
  }
}

class _BookingDetailsDialog extends StatefulWidget {
  final BookingParent parent;
  final MarketingService marketingService;
  final String userCode;

  const _BookingDetailsDialog({
    required this.parent,
    required this.marketingService,
    required this.userCode,
  });

  @override
  State<_BookingDetailsDialog> createState() => _BookingDetailsDialogState();
}

class _BookingDetailsDialogState extends State<_BookingDetailsDialog> {
  bool _isLoading = true;
  List<BookingItem> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      // Fetch bookings filtered by reference no and 'WITHOUT_BILL' (or 'BILL' if needed, but this is for filtered view)
      // We use the general 'getBookings' which returns items, unlike the 'By Letter' endpoint.
      // We search by Reference No to find the specific booking.
      final response = await widget.marketingService.getBookings(
        userCode: widget.userCode,
        search: widget.parent.referenceNo,
        paymentOption: widget.parent.paymentOption, // e.g. 'WITHOUT_BILL'
      );

      // Find the matching booking in the results
      // Safety check: specific ID matching if possible, otherwise first result
      final match = response.data.firstWhere(
        (b) => b.id == widget.parent.id,
        orElse: () =>
            response.data.isNotEmpty ? response.data.first : widget.parent,
      );

      if (mounted) {
        setState(() {
          _items = match.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Booking Items for ${widget.parent.clientName}'),
      content: SizedBox(
        width: double.maxFinite, // Ensure dialog takes available width
        child: _buildContent(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 100,
        child: Center(
            child: Text('Error: $_error',
                style: const TextStyle(color: Colors.red))),
      );
    }

    if (_items.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('No items found for this specific booking.')),
      );
    }

    // Determine if we should use horizontal scrolling
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        // Add vertical scroll for long lists
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Job Order No')),
            DataColumn(label: Text('Particulars')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Amount')),
          ],
          rows: _items.map((item) {
            return DataRow(cells: [
              DataCell(Text(item.jobOrderNo ?? '-')),
              DataCell(
                Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    item.particulars ?? '-',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
              DataCell(_buildStatusPill(item.status ?? '-')),
              DataCell(Text(item.amount ?? '-')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color color = Colors.orange;
    if (status.toLowerCase().contains('issue')) {
      color = const Color(0xFF007AFF);
    }
    if (status.toLowerCase().contains('cancel')) {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
