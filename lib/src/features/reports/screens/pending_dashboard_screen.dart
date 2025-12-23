import 'package:flutter/material.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/features/reports/models/pending_report_model.dart';
import 'package:itl/src/shared/screens/pdf_viewer_screen.dart';

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
  // String _mode = 'job'; // REMOVED: Mode now determined by tab index
  bool _overdue = false;
  String _search = '';
  int? _selectedMonth;
  int? _selectedYear;
  int? _selectedDepartment;
  final TextEditingController _searchController = TextEditingController();
  final int _currentYear = DateTime.now().year;

  // Data State
  List<PendingItem> _jobItems = [];
  List<PendingBooking> _referenceItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _lastPage = 1;

  final ScrollController _scrollController = ScrollController();

  // Departments (Hardcoded for now based on image)
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
        search: _search,
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

  void _toggleOverdue() {
    setState(() {
      _overdue = !_overdue;
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace:
            Container(decoration: BoxDecoration(gradient: kBlueGradient)),
        title: const Text('Pending Reports',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'By Job Order'),
            Tab(text: 'By Reference'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _fetchData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(isDark),
          _buildDepartmentChips(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(isDark, 'job'),
                _buildList(isDark, 'reference'),
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
                  onSubmitted: (val) {
                    _search = val;
                    _fetchData();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Overdue Toggle
              IconButton(
                icon: Icon(Icons.warning_amber_rounded,
                    color: _overdue ? Colors.orange : Colors.grey),
                tooltip: 'Out of Expected Date',
                onPressed: _toggleOverdue,
              ),
              const SizedBox(width: 8),
              _buildDropdown('Month', _selectedMonth,
                  List.generate(12, (i) => i + 1), (v) => _selectedMonth = v),
              const SizedBox(width: 8),
              _buildDropdown(
                  'Year',
                  _selectedYear,
                  List.generate(5, (i) => _currentYear - i),
                  (v) => _selectedYear = v),
              IconButton(
                  onPressed: () => _fetchData(),
                  icon: const Icon(Icons.filter_list, color: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
      String hint, T? value, List<T> items, Function(T?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
          onChanged: (val) {
            setState(() => onChanged(val));
          },
        ),
      ),
    );
  }

  Widget _buildDepartmentChips(bool isDark) {
    return Container(
      width: double.infinity,
      color: isDark ? Colors.grey[850] : Colors.grey[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _departments.map((dept) {
            final isSelected = _selectedDepartment == dept['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(dept['label']),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedDepartment = selected ? dept['id'] : null;
                  });
                  _fetchData();
                },
                selectedColor: Colors.amber,
                checkmarkColor: Colors.black,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildList(bool isDark, String mode) {
    // Only check loading for the current mode relative to the tab
    if (_isLoading && _currentPage == 1) {
      if ((mode == 'job' && _tabController.index == 0) ||
          (mode == 'reference' && _tabController.index == 1)) {
        return const Center(child: CircularProgressIndicator());
      }
    }

    final isEmpty = mode == 'job' ? _jobItems.isEmpty : _referenceItems.isEmpty;

    if (isEmpty) {
      return const Center(child: Text("No Pending Reports Found"));
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: (mode == 'job' ? _jobItems.length : _referenceItems.length) +
          (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index ==
            (mode == 'job' ? _jobItems.length : _referenceItems.length)) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator()));
        }

        if (mode == 'job') {
          return _buildJobCard(_jobItems[index], isDark);
        } else {
          return _buildReferenceCard(_referenceItems[index], isDark);
        }
      },
    );
  }

  Widget _buildJobCard(PendingItem item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.jobOrderNo ?? '-',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildStatusBadge(item.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.clientName ?? '-',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const Divider(height: 24),
          _buildRow('Description', item.sampleDescription),
          _buildRow('Quality', item.sampleQuality),
          _buildRow('Particulars', item.particulars),
          if (item.uploadLetterUrl != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('View Letter'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _viewPdf(item.uploadLetterUrl),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildReferenceCard(PendingBooking item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.clientName ?? '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(item.referenceNo ?? '-',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${item.pendingItemsCount} Item(s)',
                    style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (item.uploadLetterUrl != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Letter'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _viewPdf(item.uploadLetterUrl),
                  ),
                ),
              OutlinedButton(
                onPressed: () => _showDetailsDialog(item),
                child: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(PendingBooking booking) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pending Items'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: booking.pendingItems.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = booking.pendingItems[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.jobOrderNo ?? '-'),
                  subtitle:
                      Text('${item.sampleDescription}\n${item.sampleQuality}'),
                  trailing: _buildStatusBadge(item.status),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String? status) {
    if (status == null) return const SizedBox.shrink();
    Color color = Colors.grey;
    if (status.toLowerCase().contains('pending')) color = Colors.orange;
    if (status.toLowerCase().contains('received')) color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  void _viewPdf(String? path) {
    if (path == null) return;
    String url = path;
    if (!path.startsWith('http')) {
      url =
          "https://mediumslateblue-hummingbird-258203.hostingersite.com${path.startsWith('/') ? '' : '/'}$path";
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            PdfViewerScreen(url: url, title: 'Pending Report View'),
      ),
    );
  }
}
