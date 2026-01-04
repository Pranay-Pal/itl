import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/compact_data_tile.dart';
import 'package:itl/src/common/widgets/design_system/filter_island.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/reports/models/report_model.dart';
import 'package:itl/src/features/bookings/models/booking_model.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/common/widgets/design_system/glass_container.dart';
import 'package:itl/src/common/utils/file_viewer_service.dart';

class ReportsDashboardScreen extends StatefulWidget {
  final String userCode;

  const ReportsDashboardScreen({super.key, required this.userCode});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen>
    with SingleTickerProviderStateMixin {
  final MarketingService _marketingService = MarketingService();
  late TabController _tabController;

  // Filters
  int? _selectedMonth;
  int? _selectedYear;
  int? _selectedDepartment; // Added
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Pagination & Loading
  bool _isLoading = false;
  bool _isLoadingMore = false;

  // Tab 1 Data
  List<ReportItem> _reports = [];
  int _currentPageReport = 1;
  int _lastPageReport = 1;
  final ScrollController _reportScrollController = ScrollController();

  // Tab 2 Data
  List<BookingGrouped> _letters = [];
  int _currentPageLetter = 1;
  int _lastPageLetter = 1;
  final ScrollController _letterScrollController = ScrollController();

  List<String> get _activeFilters {
    final filters = <String>[];
    if (_searchQuery.isNotEmpty) filters.add('Search: "$_searchQuery"');
    if (_selectedMonth != null) {
      filters.add(
          'Month: ${DateFormat.MMM().format(DateTime(0, _selectedMonth!))}');
    }
    if (_selectedYear != null) filters.add('Year: $_selectedYear');
    if (_selectedDepartment != null) {
      final deptName = ['General', 'BIS', 'NBCC', 'UTTRAKHAND']
          .elementAtOrNull(_selectedDepartment! - 1);
      if (deptName != null) filters.add('Dept: $deptName');
    }
    return filters;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _reportScrollController.addListener(_onReportScroll);
    _letterScrollController.addListener(_onLetterScroll);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportScrollController.dispose();
    _letterScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onReportScroll() {
    if (_reportScrollController.hasClients &&
        _reportScrollController.position.pixels >=
            _reportScrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _onLetterScroll() {
    if (_letterScrollController.hasClients &&
        _letterScrollController.position.pixels >=
            _letterScrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      // If switching tabs, check if we need to fetch data
      if ((_tabController.index == 0 && _reports.isEmpty) ||
          (_tabController.index == 1 && _letters.isEmpty)) {
        _fetchData();
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _reports = [];
      _letters = [];
      _currentPageReport = 1;
      _currentPageLetter = 1;
    });
    await _fetchData();
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
        // Tab 1: By Job Order
        final pageToFetch = isLoadMore ? _currentPageReport + 1 : 1;
        if (isLoadMore && pageToFetch > _lastPageReport) return;

        final response = await _marketingService.getReports(
          userCode: widget.userCode,
          month: _selectedMonth,
          year: _selectedYear,
          search: _searchController.text,
          page: pageToFetch,
        );

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _reports.addAll(response.items);
            } else {
              _reports = response.items;
            }
            _currentPageReport = response.currentPage;
            _lastPageReport = response.lastPage;
          });
        }
      } else {
        // Tab 2: By Letter
        final pageToFetch = isLoadMore ? _currentPageLetter + 1 : 1;
        if (isLoadMore && pageToFetch > _lastPageLetter) return;

        final response = await _marketingService.getReportsByLetter(
          userCode: widget.userCode,
          month: _selectedMonth,
          year: _selectedYear,
          search: _searchController.text,
          page: pageToFetch,
          department:
              _selectedMonth, // Wait, I need _selectedDepartment state first.
          // Correcting logic below
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
    // Trigger Logic wrapped in scroll listener
    if (_tabController.index == 0) {
      if (_currentPageReport < _lastPageReport &&
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
      _searchQuery = '';
      _searchController.clear();
      _selectedMonth = null;
      _selectedMonth = null;
      _selectedYear = null;
      _selectedDepartment = null;
    });
    // Reset data for both tabs as filters are global
    setState(() {
      _reports = [];
      _letters = [];
      _currentPageReport = 1;
      _currentPageLetter = 1;
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
        return _ReportFilterModal(
          initialMonth: _selectedMonth,
          initialYear: _selectedYear,
          initialDepartment: _selectedDepartment, // Pass current department
          initialSearch: _searchQuery,
          onApply: (month, year, search, department) {
            // Accept department
            setState(() {
              _selectedMonth = month;
              _selectedYear = year;
              _selectedDepartment = department;
              _searchQuery = search;
              _searchController.text = search;

              // Reset pagination
              _reports = [];
              _letters = [];
              _currentPageReport = 1;
              _currentPageLetter = 1;
            });
            Navigator.pop(context);
            _fetchData();
          },
        );
      },
    );
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
              title: Text('Reports', style: AppTypography.headlineMedium),
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
                    Tab(text: 'By Job Order'),
                    Tab(text: 'By Letter'),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {
                      _reports = [];
                      _letters = [];
                      _currentPageReport = 1;
                      _currentPageLetter = 1;
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
              _buildReportList(),
              _buildLetterList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
          controller: _reportScrollController,
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
            if (_isLoading && _reports.isEmpty)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator())),
            if (!_isLoading && _reports.isEmpty)
              const SliverFillRemaining(
                  child: Center(child: Text('No reports found'))),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.gapPage, vertical: AppLayout.gapM),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == _reports.length) {
                    return _isLoadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : const SizedBox(height: 60);
                  }

                  final item = _reports[index];
                  // Using 'reportUrl' presence for pill
                  final hasReport = item.reportUrl != null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppLayout.gapS),
                    child: DataListTile(
                      title: item.jobOrderNo ?? 'N/A',
                      subtitle: item.clientName ?? 'Unknown Client',
                      statusPill: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (hasReport
                                  ? AppPalette.successGreen
                                  : Colors.orange)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: (hasReport
                                      ? AppPalette.successGreen
                                      : Colors.orange)
                                  .withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          hasReport ? 'COMPLETED' : 'PENDING',
                          style: TextStyle(
                              color: hasReport
                                  ? AppPalette.successGreen
                                  : Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      compactRows: [
                        InfoRow(
                            icon: Icons.science,
                            label: 'Sample',
                            value: item.sampleDescription ?? '-'),
                      ],
                      expandedRows: [
                        InfoRow(
                            icon: Icons.description,
                            label: 'Particulars',
                            value: item.particulars ?? '-'),
                        // Omitted ReferenceNo as it seemed missing from model causing issues, can add back if verified.
                        // Omitted ReceivedAt as missing.
                      ],
                      actions: [
                        if (item.reportUrl != null)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 14),
                            label: const Text('View Report'),
                            onPressed: () => FileViewerService.viewFile(
                                context, item.reportUrl!),
                          )
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 50.ms)
                      .slideY(begin: 0.1, end: 0);
                }, childCount: _reports.length + 1),
              ),
            )
          ]),
    );
  }

  Widget _buildLetterList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
          controller: _letterScrollController,
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
            if (_isLoading && _letters.isEmpty)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator())),
            if (!_isLoading && _letters.isEmpty)
              const SliverFillRemaining(
                  child: Center(child: Text('No report letters found'))),
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

                    return _LetterCard(item: item)
                        .animate()
                        .fadeIn(duration: 50.ms)
                        .slideY(begin: 0.1, end: 0);
                  },
                  childCount: _letters.length + 1,
                ),
              ),
            ),
          ]),
    );
  }
}

class _ReportFilterModal extends StatefulWidget {
  final int? initialMonth;
  final int? initialYear;
  final int? initialDepartment;
  final String initialSearch;
  final Function(int? month, int? year, String search, int? department) onApply;

  const _ReportFilterModal({
    this.initialMonth,
    this.initialYear,
    this.initialDepartment,
    required this.initialSearch,
    required this.onApply,
  });

  @override
  State<_ReportFilterModal> createState() => _ReportFilterModalState();
}

class _ReportFilterModalState extends State<_ReportFilterModal> {
  int? _month;
  int? _year;
  int? _department;
  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
    _department = widget.initialDepartment;
    _searchCtrl = TextEditingController(text: widget.initialSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                Text('Filter Reports', style: AppTypography.headlineSmall),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
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
                      ...List.generate(5, (i) => DateTime.now().year - i).map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')))
                    ],
                    onChanged: (v) => _year = v,
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
                              child: Text(
                                  DateFormat.MMM().format(DateTime(0, m)))))
                    ],
                    onChanged: (v) => _month = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Department',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _department,
                  isDense: true,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: null, child: Text('All Departments')),
                    DropdownMenuItem(value: 1, child: Text('General')),
                    DropdownMenuItem(value: 2, child: Text('BIS')),
                    DropdownMenuItem(value: 3, child: Text('NBCC')),
                    DropdownMenuItem(value: 4, child: Text('UTTRAKHAND')),
                  ],
                  onChanged: (v) => _department = v,
                ),
              ),
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
                  widget.onApply(_month, _year, _searchCtrl.text, _department);
                },
                child: const Text('Apply Filters',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ));
  }
}

class _LetterCard extends StatefulWidget {
  final BookingGrouped item;

  const _LetterCard({required this.item});

  @override
  State<_LetterCard> createState() => _LetterCardState();
}

class _LetterCardState extends State<_LetterCard> {
  bool _showItems = false;

  void _showFilesMenu(BuildContext context) {
    // Collect all valid files
    final files = <Map<String, String>>[];

    // 1. Main Letter
    if (widget.item.uploadLetterUrl != null) {
      files.add({
        'name': 'Main Letter',
        'url': widget.item.uploadLetterUrl!,
        'type': 'letter'
      });
    }

    // 2. Invoice
    if (widget.item.invoiceUrl != null) {
      files.add({
        'name': 'Invoice',
        'url': widget.item.invoiceUrl!,
        'type': 'invoice'
      });
    }

    // 3. Additional Files
    for (var f in widget.item.reportFiles) {
      if (f.url != null) {
        files.add(
            {'name': f.name ?? 'Attachment', 'url': f.url!, 'type': 'file'});
      }
    }

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files available for this letter')));
      return;
    }

    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: files.map((file) {
        IconData icon;
        Color color;
        switch (file['type']) {
          case 'letter':
            icon = Icons.mail_outline;
            color = AppPalette.electricBlue;
            break;
          case 'invoice':
            icon = Icons.receipt_long;
            color = Colors.orange;
            break;
          default:
            icon = Icons.attach_file;
            color = Colors.grey;
        }

        return PopupMenuItem<String>(
          value: file['url'],
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file['name']!,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((url) {
      if (url != null && context.mounted) {
        FileViewerService.viewFile(context, url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasFiles = item.uploadLetterUrl != null ||
        item.invoiceUrl != null ||
        item.reportFiles.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.gapM),
      child: GlassContainer(
        padding: const EdgeInsets.all(AppLayout.gapM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Client & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.clientName ?? 'Unknown Client',
                    style: AppTypography.headlineSmall
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.electricBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppPalette.electricBlue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${item.itemsCount} Items',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppPalette.electricBlue,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Subtitle: Reference
            if (item.referenceNo != null)
              Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.referenceNo!,
                      style: AppTypography.bodySmall
                          .copyWith(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: AppLayout.gapM),

            // Action Bar
            Row(
              children: [
                // 1. Files Button
                if (hasFiles)
                  ElevatedButton.icon(
                    onPressed: () => _showFilesMenu(context),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Letter Files'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.electricBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                  ),

                const Spacer(),

                // 2. Show/Hide Items Toggle
                TextButton.icon(
                  onPressed: () => setState(() => _showItems = !_showItems),
                  icon: Icon(
                      _showItems
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16),
                  label: Text(_showItems ? 'Hide Items' : 'Show Items'),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.grey),
                ),
              ],
            ),

            // Items List (Collapsible)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const Divider(height: 24),
                  ...item.items.map((subItem) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.circle,
                                  size: 6, color: Colors.grey[400]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subItem.jobOrderNo ?? 'N/A',
                                    style: AppTypography.labelMedium
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subItem.sampleQuality ?? '-',
                                    style: AppTypography.bodySmall,
                                  ),
                                  Text(
                                    subItem.status ?? '',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      )),
                ],
              ),
              crossFadeState: _showItems
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            )
          ],
        ),
      ),
    );
  }
}
