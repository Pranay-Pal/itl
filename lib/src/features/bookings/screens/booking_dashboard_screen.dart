import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/compact_data_tile.dart';
import 'package:itl/src/common/widgets/design_system/filter_island.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/bookings/models/booking_model.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/common/utils/file_viewer_service.dart';

class BookingDashboardScreen extends StatefulWidget {
  final String userCode;

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
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();
  final int _currentYear = DateTime.now().year;

  // Pagination & Loading
  bool _isLoading = false;
  List<BookingItemFlat> _bookings = [];
  List<BookingGrouped> _letters = []; // For "By Letter" tab

  // Pagination State
  int _currentPageBooking = 1;
  int _lastPageBooking = 1;
  int _currentPageLetter = 1;
  int _lastPageLetter = 1;
  bool _isLoadingMore = false;
  final ScrollController _bookingScrollController = ScrollController();
  final ScrollController _letterScrollController = ScrollController();

  List<String> get _activeFilters {
    final filters = <String>[];
    if (_searchTerm.isNotEmpty) filters.add('Search: $_searchTerm');
    if (_selectedMonth != null) {
      filters.add(
          'Month: ${DateFormat.MMM().format(DateTime(0, _selectedMonth!))}');
    }
    if (_selectedYear != null) filters.add('Year: $_selectedYear');
    return filters;
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

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
        // Tab 1: Show Booking (Flat List)
        final pageToFetch = isLoadMore ? _currentPageBooking + 1 : 1;
        if (isLoadMore && pageToFetch > _lastPageBooking) return;

        final response = await _marketingService.getBookings(
          userCode: widget.userCode,
          month: _selectedMonth,
          year: _selectedYear,
          search: _searchTerm,
          page: pageToFetch,
        );

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _bookings.addAll(response.items);
            } else {
              _bookings = response.items;
            }
            _currentPageBooking = response.currentPage;
            _lastPageBooking = response.lastPage;
          });
        }
      } else {
        // Tab 2: Booking By Letter (Grouped)
        final pageToFetch = isLoadMore ? _currentPageLetter + 1 : 1;
        if (isLoadMore && pageToFetch > _lastPageLetter) return;

        final response = await _marketingService.getBookingsByLetter(
          userCode: widget.userCode,
          month: _selectedMonth,
          year: _selectedYear,
          search: _searchTerm,
          page: pageToFetch,
        );

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _letters.addAll(response.bookings);
            } else {
              _letters = response.bookings;
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

  void _clearFilters() {
    setState(() {
      _searchTerm = '';
      _searchController.clear();
      _selectedMonth = null;
      _selectedYear = null;
    });
    _fetchData();
  }

  void _openFilterDialog() {
    final tempSearch = TextEditingController(text: _searchTerm);
    int? tempMonth = _selectedMonth;
    int? tempYear = _selectedYear;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          title: const Text('Filter Bookings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tempSearch,
                decoration: InputDecoration(
                  labelText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: tempMonth,
                      decoration: InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...List.generate(12, (i) => i + 1).map((m) =>
                            DropdownMenuItem(
                                value: m,
                                child: Text(
                                    DateFormat.MMM().format(DateTime(0, m)))))
                      ],
                      onChanged: (v) => tempMonth = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: tempYear,
                      decoration: InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...List.generate(5, (i) => _currentYear - i).map((y) =>
                            DropdownMenuItem(
                                value: y, child: Text(y.toString())))
                      ],
                      onChanged: (v) => tempYear = v,
                    ),
                  ),
                ],
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
                  _searchTerm = tempSearch.text;
                  _searchController.text = tempSearch.text;
                  _selectedMonth = tempMonth;
                  _selectedYear = tempYear;
                });
                Navigator.pop(ctx);
                _fetchData();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase().contains('pending')) {
      return Colors.orange;
    }
    if (status.toLowerCase().contains('received')) {
      return Colors.blue;
    }
    if (status.toLowerCase().contains('completed') ||
        status.toLowerCase().contains('report')) {
      return AppPalette.successGreen;
    }
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
              title: Text('Bookings', style: AppTypography.headlineMedium),
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
                    Tab(text: 'All Bookings'),
                    Tab(text: 'By Letter'),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
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
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildBookingsTab(),
              _buildLettersTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsTab() {
    return CustomScrollView(
      controller: _bookingScrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilterIsland(
              onFilterTap: _openFilterDialog,
              onClearTap: _clearFilters,
              activeFilters: _activeFilters,
            ),
          ),
        ),
        if (_isLoading && _bookings.isEmpty)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator())),
        if (!_isLoading && _bookings.isEmpty)
          const SliverFillRemaining(
              child: Center(child: Text('No bookings found'))),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.gapPage, vertical: AppLayout.gapM),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == _bookings.length) {
                  return _isLoadingMore
                      ? const Center(child: CircularProgressIndicator())
                      : const SizedBox(height: 60);
                }

                final item = _bookings[index];
                final status = item.statusDetail ?? item.status ?? 'Unknown';

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppLayout.gapS),
                  child: DataListTile(
                    title: item.jobOrderNo ?? 'N/A',
                    subtitle: item.clientName ?? 'Unknown Client',
                    statusPill: _buildStatusPill(status),
                    compactRows: [
                      InfoRow(
                          icon: Icons.calendar_today,
                          label: 'Received',
                          value: item.receivedAt ?? '-'),
                      InfoRow(
                          icon: Icons.qr_code,
                          label: 'Ref',
                          value: item.referenceNo ?? '-'),
                    ],
                    expandedRows: [
                      InfoRow(
                          icon: Icons.science,
                          label: 'Sample',
                          value: item.sampleQuality ?? '-'),
                      InfoRow(
                          icon: Icons.description,
                          label: 'Particulars',
                          value: item.particulars ?? '-'),
                      InfoRow(
                          icon: Icons.date_range,
                          label: 'Expected',
                          value: item.labExpectedDate ?? '-'),
                    ],
                    actions: [
                      if (item.letterUrl != null)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 14),
                          label: const Text('View Letter'),
                          onPressed: () => FileViewerService.viewFile(
                              context, item.letterUrl!),
                        ),
                    ],
                  ),
                ).animate().fadeIn(duration: 50.ms).slideY(begin: 0.1, end: 0);
              },
              childCount: _bookings.length + 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLettersTab() {
    return CustomScrollView(
      controller: _letterScrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilterIsland(
              onFilterTap: _openFilterDialog,
              onClearTap: _clearFilters,
              activeFilters: _activeFilters,
            ),
          ),
        ),
        if (_isLoading && _letters.isEmpty)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator())),
        if (!_isLoading && _letters.isEmpty)
          const SliverFillRemaining(
              child: Center(child: Text('No letters found'))),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.gapPage, vertical: AppLayout.gapM),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == _letters.length) {
                  return _isLoadingMore
                      ? const Center(child: CircularProgressIndicator())
                      : const SizedBox(height: 60);
                }

                final item = _letters[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppLayout.gapS),
                  child: DataListTile(
                    title: item.clientName ?? 'Unknown Client',
                    subtitle: item.referenceNo ?? 'No Reference',
                    statusPill: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.electricBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.itemsCount} Items',
                        style: AppTypography.labelSmall.copyWith(
                            color: AppPalette.electricBlue,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    compactRows: [
                      if (item.referenceNo != null)
                        InfoRow(
                            icon: Icons.tag,
                            label: 'Ref',
                            value: item.referenceNo!),
                    ],
                    expandedRows: [
                      const Divider(),
                      ...item.items.map((subItem) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 6, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(subItem.jobOrderNo ?? '-',
                                          style: AppTypography.labelSmall),
                                      Text(
                                          '${subItem.sampleQuality} • ${subItem.status}',
                                          style: AppTypography.bodySmall
                                              .copyWith(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    actions: [
                      if (item.uploadLetterUrl != null)
                        TextButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 14),
                          label: const Text('Letter'),
                          onPressed: () => FileViewerService.viewFile(
                              context, item.uploadLetterUrl!),
                        ),
                      if (item.invoiceUrl != null)
                        TextButton.icon(
                          icon: const Icon(Icons.receipt_long, size: 14),
                          label: const Text('Invoice'),
                          onPressed: () => FileViewerService.viewFile(
                              context, item.invoiceUrl!),
                        ),
                    ],
                  ),
                ).animate().fadeIn(duration: 50.ms).slideY(begin: 0.1, end: 0);
              },
              childCount: _letters.length + 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
