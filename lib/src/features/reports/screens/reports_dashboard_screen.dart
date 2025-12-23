import 'package:flutter/material.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/features/reports/models/report_model.dart';
import 'package:itl/src/features/bookings/models/booking_model.dart';
import 'package:itl/src/shared/screens/pdf_viewer_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final int _currentYear = DateTime.now().year;

  // Pagination & Loading
  bool _isLoading = false;

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

  bool _isLoadingMore = false;

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
      // If switching tabs, we might want to refresh if empty, or just show existing state
      if ((_tabController.index == 0 && _reports.isEmpty) ||
          (_tabController.index == 1 && _letters.isEmpty)) {
        _fetchData();
      }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: kBlueGradient),
        ),
        title: const Text('Reports', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'By Job Order'),
            Tab(text: 'By Letter'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _reports = [];
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
                _buildByJobOrderTab(isDark),
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
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildByJobOrderTab(bool isDark) {
    if (_isLoading && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.assignment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No reports found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _reportScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _reports.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _reports.length) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ));
        }
        final item = _reports[index];
        return _buildReportCard(item, isDark);
      },
    );
  }

  Widget _buildByLetterTab(bool isDark) {
    if (_isLoading && _letters.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_letters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
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
        final parent = _letters[index];
        return _buildLetterCard(parent, isDark);
      },
    );
  }

  Widget _buildReportCard(ReportItem item, bool isDark) {
    return GestureDetector(
      onTap: () => _showReportDetails(item),
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.clientName ?? 'Unknown Client',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (item.reportUrl != null)
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20)
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.work, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Job: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: Colors.grey)),
                  Text(item.jobOrderNo ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 8),
              if (item.sampleDescription != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.sampleDescription!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color:
                                isDark ? Colors.grey[400] : Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tap for details',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.reportUrl != null)
                    TextButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('View Report'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _viewPdf(item.reportUrl),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLetterCard(BookingGrouped parent, bool isDark) {
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parent.clientName ?? 'Unknown Client',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Ref: ',
                    style: TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.grey)),
                Expanded(
                  child: Text(
                    parent.referenceNo ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                if (parent.uploadLetterUrl != null)
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
                    onPressed: () => _viewPdf(parent.uploadLetterUrl),
                  ),
                if (parent.reportFiles.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.description,
                        size: 16, color: Colors.white),
                    label: Text('Reports (${parent.reportFiles.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _showReportsList(parent.reportFiles),
                  ),
                if (parent.items.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.list, size: 16),
                    label: Text('${parent.items.length} Items'),
                    onPressed: () => _showLetterDetails(parent),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDetails(ReportItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Client', item.clientName),
              const Divider(),
              _buildDetailItem('Job Order No', item.jobOrderNo),
              _buildDetailItem('Sample Quality', item.sampleQuality),
              _buildDetailItem('Particulars', item.particulars),
              const Divider(),
              _buildDetailItem('Sample Description', item.sampleDescription),
            ],
          ),
        ),
        actions: [
          if (item.reportUrl != null)
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('View Report'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                _viewPdf(item.reportUrl);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReportsList(List<ReportFile> files) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reports'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: files.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (context, index) {
              final file = files[index];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(file.name ?? 'Unknown Report'),
                onTap: () => _viewPdf(file.url),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLetterDetails(BookingGrouped parent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Items in this Letter'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: parent.items.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (context, index) {
              final item = parent.items[index];
              return ListTile(
                title: Text(item.jobOrderNo ?? '-'),
                subtitle: Text(item.sampleDescription ?? '-'),
                trailing: Text(item.status ?? ''),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 12)),
          const SizedBox(height: 2),
          Text(value ?? '-', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _viewPdf(String? path) {
    if (path == null) return;

    String url = path;
    if (!path.startsWith('http')) {
      if (!path.startsWith('/')) {
        url =
            "https://mediumslateblue-hummingbird-258203.hostingersite.com/$path";
      } else {
        url =
            "https://mediumslateblue-hummingbird-258203.hostingersite.com$path";
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(url: url, title: 'Report View'),
      ),
    );
  }
}
