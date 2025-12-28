import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/compact_data_tile.dart';
import 'package:itl/src/common/widgets/design_system/filter_island.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/reports/models/pending_report_model.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/common/utils/file_viewer_service.dart';

class PendingDashboardScreen extends StatefulWidget {
  final String userCode;

  const PendingDashboardScreen({super.key, required this.userCode});

  @override
  State<PendingDashboardScreen> createState() => _PendingDashboardScreenState();
}

class _PendingDashboardScreenState extends State<PendingDashboardScreen>
    with SingleTickerProviderStateMixin {
  final MarketingService _marketingService = MarketingService();
  late TabController _tabController;

  // Filter State
  bool _overdue = false;
  String _searchQuery = '';
  int? _selectedMonth;
  int? _selectedYear;
  int? _selectedDepartment;
  final TextEditingController _searchController = TextEditingController();

  // Data State
  List<PendingItem> _jobItems = [];
  List<PendingBooking> _referenceItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _lastPage = 1;

  final ScrollController _scrollController = ScrollController();

  List<String> get _activeFilters {
    final filters = <String>[];
    if (_searchQuery.isNotEmpty) filters.add('Search: "$_searchQuery"');
    if (_overdue) filters.add('OVERDUE ONLY');
    if (_selectedDepartment != null) {
      filters.add('Dept: $_selectedDepartment');
    }
    if (_selectedMonth != null) {
      filters.add(
          'Month: ${DateFormat.MMM().format(DateTime(0, _selectedMonth!))}');
    }
    if (_selectedYear != null) filters.add('Year: $_selectedYear');
    return filters;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _scrollController.addListener(_onScroll);
    _fetchData();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      _fetchData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _currentPage < _lastPage) {
        _fetchData(loadMore: true);
      }
    }
  }

  Future<void> _fetchData({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _jobItems = [];
        _referenceItems = [];
        _currentPage = 1;
      });
    }

    try {
      final currentMode = _tabController.index == 0 ? 'job' : 'reference';

      final response = await _marketingService.getPendingReports(
        userCode: widget.userCode,
        mode: currentMode,
        page: loadMore ? _currentPage + 1 : 1,
        search: _searchQuery,
        month: _selectedMonth,
        year: _selectedYear,
        overdue: _overdue,
        department: _selectedDepartment,
      );

      if (mounted) {
        setState(() {
          _currentPage = response.currentPage;
          _lastPage = response.lastPage;

          if (currentMode == 'job') {
            if (loadMore) {
              _jobItems.addAll(response.items);
            } else {
              _jobItems = response.items;
            }
          } else {
            if (loadMore) {
              _referenceItems.addAll(response.bookings);
            } else {
              _referenceItems = response.bookings;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedMonth = null;
      _selectedYear = null;
      _selectedDepartment = null;
      _overdue = false;
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
        return _PendingFilterModal(
          initialMonth: _selectedMonth,
          initialYear: _selectedYear,
          initialSearch: _searchQuery,
          initialDepartment: _selectedDepartment,
          initialOverdue: _overdue,
          onApply: (month, year, search, dept, overdue) {
            setState(() {
              _selectedMonth = month;
              _selectedYear = year;
              _searchQuery = search;
              _searchController.text = search;
              _selectedDepartment = dept;
              _overdue = overdue;
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
              title:
                  Text('Pending Reports', style: AppTypography.headlineMedium),
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
                    Tab(text: 'By Reference'),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _fetchData();
                  },
                ),
              ],
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildJobList(),
              _buildReferenceList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobList() {
    return CustomScrollView(
        key: const PageStorageKey('job_list'),
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
          if (_isLoading && _jobItems.isEmpty)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _jobItems.isEmpty)
            const SliverFillRemaining(
                child: Center(child: Text('No pending jobs found'))),
          SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.gapPage, vertical: AppLayout.gapM),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                if (index == _jobItems.length) {
                  return _isLoadingMore
                      ? const Center(child: CircularProgressIndicator())
                      : const SizedBox(height: 60);
                }

                final item = _jobItems[index];
                // No expected date in model, so simplified pill

                return Padding(
                        padding: const EdgeInsets.only(bottom: AppLayout.gapS),
                        child: DataListTile(
                          title: item.jobOrderNo ?? 'N/A',
                          subtitle: item.clientName ?? 'Unknown Client',
                          statusPill: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('PENDING',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
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
                            if (item.status != null)
                              InfoRow(
                                  icon: Icons.info_outline,
                                  label: 'Status',
                                  value: item.status!),
                          ],
                        ))
                    .animate()
                    .fadeIn(duration: 50.ms)
                    .slideY(begin: 0.1, end: 0);
              }, childCount: _jobItems.length + 1)))
        ]);
  }

  Widget _buildReferenceList() {
    return CustomScrollView(
        key: const PageStorageKey('ref_list'),
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
          if (_isLoading && _referenceItems.isEmpty)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _referenceItems.isEmpty)
            const SliverFillRemaining(
                child: Center(child: Text('No pending references found'))),
          SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.gapPage, vertical: AppLayout.gapM),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                if (index == _referenceItems.length) {
                  return _isLoadingMore
                      ? const Center(child: CircularProgressIndicator())
                      : const SizedBox(height: 60);
                }

                final item = _referenceItems[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppLayout.gapS),
                  child: DataListTile(
                    title: item.clientName ?? 'Unknown Client',
                    subtitle: item.referenceNo ?? 'No Ref',
                    statusPill: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.electricBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${item.pendingItemsCount} Items',
                          style: TextStyle(
                              color: AppPalette.electricBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    expandedRows: [
                      const Divider(),
                      ...item.pendingItems.map((subItem) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.circle,
                                    size: 6, color: Colors.grey[400]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(subItem.jobOrderNo ?? 'N/A',
                                          style: AppTypography.labelSmall),
                                      Text(subItem.sampleDescription ?? '-',
                                          style: AppTypography.bodySmall
                                              .copyWith(color: Colors.grey))
                                    ],
                                  ),
                                )
                              ])))
                    ],
                    actions: [
                      if (item.uploadLetterUrl != null)
                        TextButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 14),
                            label: const Text('Letter'),
                            onPressed: () => FileViewerService.viewFile(
                                context, item.uploadLetterUrl!)),
                    ],
                  ),
                ).animate().fadeIn(duration: 50.ms).slideY(begin: 0.1, end: 0);
              }, childCount: _referenceItems.length + 1)))
        ]);
  }
}

class _PendingFilterModal extends StatefulWidget {
  final int? initialMonth;
  final int? initialYear;
  final String initialSearch;
  final int? initialDepartment;
  final bool initialOverdue;
  final Function(int? m, int? y, String s, int? d, bool o) onApply;

  const _PendingFilterModal({
    this.initialMonth,
    this.initialYear,
    required this.initialSearch,
    this.initialDepartment,
    required this.initialOverdue,
    required this.onApply,
  });

  @override
  State<_PendingFilterModal> createState() => _PendingFilterModalState();
}

class _PendingFilterModalState extends State<_PendingFilterModal> {
  int? _month;
  int? _year;
  int? _dept;
  late bool _overdue;
  late TextEditingController _searchCtrl;

  final List<Map<String, dynamic>> _departments = [
    {'id': null, 'label': 'All'},
    {'id': 1, 'label': 'BIS'},
    {'id': 2, 'label': 'GENERAL'},
    {'id': 3, 'label': 'NBCC'},
    {'id': 4, 'label': 'UTTARAKHAND'},
  ];

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
    _dept = widget.initialDepartment;
    _overdue = widget.initialOverdue;
    _searchCtrl = TextEditingController(text: widget.initialSearch);
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
                Text('Filter Pending', style: AppTypography.headlineSmall),
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

            // Overdue Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Overdue Only'),
              value: _overdue,
              activeThumbColor: Colors.red,
              onChanged: (v) => setState(() => _overdue = v),
            ),

            const SizedBox(height: 8),
            const Text('Department',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _departments
                    .map((d) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(d['label']),
                            selected: _dept == d['id'],
                            onSelected: (v) =>
                                setState(() => _dept = v ? d['id'] : null),
                          ),
                        ))
                    .toList(),
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
                  widget.onApply(
                      _month, _year, _searchCtrl.text, _dept, _overdue);
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
