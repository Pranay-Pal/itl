import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/glass_container.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/marketing/models/quotation_model.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/utils/currency_formatter.dart';

class QuotationListScreen extends StatefulWidget {
  const QuotationListScreen({super.key});

  @override
  State<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends State<QuotationListScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final List<Quotation> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  // Filters
  String? _searchQuery;
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchItems();
    }
  }

  Future<void> _fetchItems({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (refresh) {
      _currentPage = 1;
      _items.clear();
      _hasMore = true;
    }

    try {
      final response = await _apiService.getQuotations(
        page: _currentPage,
        search: _searchQuery,
        month: _selectedMonth,
        year: _selectedYear,
      );

      if (response != null && response['data'] != null) {
        final data = response['data'];
        List<dynamic> list = [];
        if (data is Map && data['data'] is List) {
          list = data['data'];
        }

        final newItems = list
            .map((e) => Quotation.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        setState(() {
          _items.addAll(newItems);
          _currentPage++;
          if (newItems.isEmpty || newItems.length < 10) {
            _hasMore = false;
          }
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      debugPrint('Error fetching quotations: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFilterDialog() {
    int tempMonth = _selectedMonth ?? DateTime.now().month;
    int tempYear = _selectedYear ?? DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Filter by Date'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: tempYear,
                decoration: const InputDecoration(labelText: 'Year'),
                items: List.generate(5, (i) => DateTime.now().year - i)
                    .map((y) =>
                        DropdownMenuItem(value: y, child: Text(y.toString())))
                    .toList(),
                onChanged: (v) => tempYear = v!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: tempMonth,
                decoration: const InputDecoration(labelText: 'Month'),
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(DateFormat.MMM().format(DateTime(0, m)))))
                    .toList(),
                onChanged: (v) => tempMonth = v!,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedMonth = null;
                  _selectedYear = null;
                });
                Navigator.pop(ctx);
                _fetchItems(refresh: true);
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedMonth = tempMonth;
                  _selectedYear = tempYear;
                });
                Navigator.pop(ctx);
                _fetchItems(refresh: true);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Quotations'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .scaffoldBackgroundColor
                .withValues(alpha: 0.8),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: AuroraBackground(
        child: Column(
          children: [
            SizedBox(
                height: MediaQuery.of(context).padding.top + kToolbarHeight),
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(AppLayout.gapM),
              child: GlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Client / Quotation No.',
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        setState(() {
                          _searchQuery = _searchController.text.trim();
                          if (_searchQuery!.isEmpty) _searchQuery = null;
                        });
                        _fetchItems(refresh: true);
                      },
                    ),
                  ),
                  onSubmitted: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                      if (_searchQuery!.isEmpty) _searchQuery = null;
                    });
                    _fetchItems(refresh: true);
                  },
                ),
              ),
            ),

            // List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchItems(refresh: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppLayout.gapM),
                  itemCount: _items.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _items.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final item = _items[index];
                    return _buildItemCard(item);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Quotation item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.gapM),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.quotationNo,
                    style: AppTypography.titleMedium
                        .copyWith(color: Colors.white)),
                Text(
                  item.quotationDate,
                  style: AppTypography.caption,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.clientName,
                style: AppTypography.bodyLarge
                    .copyWith(fontWeight: FontWeight.bold)),
            if (item.clientGstin.isNotEmpty)
              Text('GST: ${item.clientGstin}', style: AppTypography.bodySmall),
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount', style: TextStyle(color: Colors.grey)),
                    Text(
                      CurrencyFormatter.formatIndianCurrency(
                          double.tryParse(item.payableAmount) ?? 0),
                      style: AppTypography.titleMedium.copyWith(
                          color: AppPalette.successGreen,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (item.generatedBy != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Generated By',
                          style: TextStyle(color: Colors.grey)),
                      Text(item.generatedBy!.name,
                          style: AppTypography.bodyMedium),
                    ],
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
