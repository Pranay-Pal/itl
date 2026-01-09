import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/common/animations/scale_button.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/compact_data_tile.dart';

import 'package:itl/src/common/widgets/design_system/glass_container.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/base_url.dart' as config;
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/expenses/models/expense_model.dart';
import 'package:itl/src/features/expenses/models/checked_in_expense_model.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/services/download_util.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/shared/screens/pdf_viewer_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final MarketingService _marketingService = MarketingService();
  final ApiService _apiService = ApiService();

  List<ExpenseItem> _items = [];
  List<CheckedInExpense> _checkedInItems = [];
  String _viewMode = 'personal'; // 'personal' or 'checked_in'
  ExpenseTotals? _totals;
  bool _loading = false;
  int _page = 1;
  int _lastPage = 1;

  // Filters
  int? _selectedMonth;
  int? _selectedYear;
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    // Default to 'checked_in' if userCode is null (likely Admin)
    if (_apiService.userCode == null) {
      _viewMode = 'checked_in';
    }
    _loadExpenses(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _activeFilters {
    final List<String> filters = [];
    if (_searchTerm.isNotEmpty) filters.add('Search: "$_searchTerm"');
    if (_selectedMonth != null) {
      filters.add(DateFormat.MMMM().format(DateTime(0, _selectedMonth!)));
    }
    if (_selectedYear != null) filters.add('Year: $_selectedYear');
    return filters;
  }

  Future<void> _loadExpenses({bool reset = false}) async {
    if (_loading) return;

    final userCode = _apiService.userCode;
    // Only block if trying to view Personal expenses without a userCode
    if (userCode == null && _viewMode == 'personal') {
      // Ideally this state shouldn't be reachable if we default correctly,
      // but strictly guarding it is good.
      // We won't show a snackbar on init if validly in checked_in mode
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        if (_viewMode == 'personal') {
          _items = [];
        } else {
          _checkedInItems = [];
        }
      }
    });

    try {
      if (_viewMode == 'personal') {
        final response = await _marketingService.getExpenses(
          userCode: userCode!,
          page: _page,
          month: _selectedMonth,
          year: _selectedYear,
          search: _searchTerm,
        );

        if (mounted) {
          setState(() {
            if (reset) {
              _items = response.items;
              _totals = response.totals;
            } else {
              _items.addAll(response.items);
              if (response.totals != null) _totals = response.totals;
            }
            _lastPage = response.lastPage;
            _page = response.currentPage;
          });
        }
      } else {
        // Checked-In Logic
        final response = await _marketingService.getCheckedInExpenses(
          page: _page,
          perPage: 15, // Default from API
          search: _searchTerm,
          month: _selectedMonth,
          year: _selectedYear,
          mine: true, // As per requirements
        );

        if (mounted) {
          setState(() {
            if (reset) {
              _checkedInItems = response.items;
            } else {
              _checkedInItems.addAll(response.items);
            }
            _lastPage = response.lastPage;
            _page = response.currentPage;
            // No totals object for checked-in
          });
        }
      }
    } catch (e) {
      _showSnack('Failed to load data: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _loadMore() {
    if (_page < _lastPage) {
      setState(() {
        _page = _page + 1;
      });
      _loadExpenses(reset: false);
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchTerm = '';
      _selectedMonth = null;
      _selectedYear = null;
    });
    _loadExpenses(reset: true);
  }

  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        int? tempMonth = _selectedMonth;
        int? tempYear = _selectedYear;
        // Local controller for the dialog to avoid interference if cancelled
        final tempSearch = TextEditingController(text: _searchTerm);

        return AlertDialog(
          title: Text('Filter Expenses', style: AppTypography.headlineMedium),
          backgroundColor: Theme.of(context).cardColor,
          surfaceTintColor: Colors.transparent,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tempSearch,
                decoration: InputDecoration(
                  labelText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...List.generate(5, (i) => DateTime.now().year - i).map(
                            (y) => DropdownMenuItem(
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
                _loadExpenses(reset: true);
              },
              child: const Text('Apply Filters'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        _showSnack('Deleting...');
        await _marketingService.deleteExpense(id);
        _showSnack('Expense deleted');
        _loadExpenses(reset: true);
      } catch (e) {
        _showSnack('Error deleting: $e');
      }
    }
  }

  void _openCreateExpenseDialog({ExpenseItem? item}) {
    final isEdit = item != null;
    final formKey = GlobalKey<FormState>();
    final amountController =
        TextEditingController(text: item?.amount.toString());
    final descriptionController =
        TextEditingController(text: item?.description);
    DateTime? selectedDate = item?.expenseDate != null
        ? DateTime.tryParse(item!.expenseDate!)
        : DateTime.now();
    String? filePath;
    String? fileName = item?.receiptFilename;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // For glass effect
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickFile() async {
            // Reusing prior logic, simplified for brevity in this block
            showModalBottomSheet(
              context: context,
              backgroundColor: Theme.of(context).cardColor,
              builder: (bsContext) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Camera'),
                      onTap: () async {
                        Navigator.pop(bsContext);
                        final picker = ImagePicker();
                        final photo =
                            await picker.pickImage(source: ImageSource.camera);
                        if (photo != null) {
                          setSheetState(() {
                            filePath = photo.path;
                            fileName = photo.name;
                          });
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Gallery'),
                      onTap: () async {
                        Navigator.pop(bsContext);
                        final picker = ImagePicker();
                        final image =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setSheetState(() {
                            filePath = image.path;
                            fileName = image.name;
                          });
                        }
                      },
                    ),
                    ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: const Text('File / PDF'),
                        onTap: () async {
                          Navigator.pop(bsContext);
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                          );
                          if (result != null) {
                            final file = result.files.single;
                            if (file.path != null) {
                              setSheetState(() {
                                filePath = file.path;
                                fileName = file.name;
                              });
                            }
                          }
                        }),
                  ],
                ),
              ),
            );
          }

          Future<void> pickDate() async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (date != null) {
              setSheetState(() => selectedDate = date);
            }
          }

          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            if (selectedDate == null) {
              _showSnack('Please select a date');
              return;
            }

            final amount = double.tryParse(amountController.text);
            if (amount == null) {
              _showSnack('Invalid amount');
              return;
            }

            final userCode = _apiService.userCode;
            // userCode required for Create, but ID required for Update
            if (!isEdit && userCode == null) return;

            try {
              Navigator.pop(context); // Close dialog first
              _showSnack(
                  isEdit ? 'Updating expense...' : 'Creating expense...');

              if (isEdit) {
                await _marketingService.updateExpense(
                  id: item.id,
                  amount: amount,
                  section: 'personal',
                  fromDate: DateFormat('yyyy-MM-dd').format(selectedDate!),
                  toDate: DateFormat('yyyy-MM-dd').format(selectedDate!),
                  description: descriptionController.text,
                  filePath: filePath,
                );
                _showSnack('Expense updated!');
              } else {
                await _marketingService.createExpense(
                  userCode: userCode!,
                  amount: amount,
                  section: 'personal',
                  fromDate: DateFormat('yyyy-MM-dd').format(selectedDate!),
                  description: descriptionController.text,
                  filePath: filePath,
                );
                _showSnack('Expense created!');
              }
              _loadExpenses(reset: true);
            } catch (e) {
              _showSnack('Error: $e');
            }
          }

          return Container(
            margin: EdgeInsets.only(
                top: 40, bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white, // Fallback / Base
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: GlassContainer(
              // Using GlassContainer as a wrapper for style
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(isEdit ? 'Edit Expense' : 'New Expense',
                            style: AppTypography.headlineMedium),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: amountController,
                          decoration: InputDecoration(
                            labelText: 'Amount *',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.currency_rupee),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        // Category field removed as per request, defaults to 'personal' in logic/backend
                        InkWell(
                          onTap: pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon:
                                  const Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              selectedDate != null
                                  ? DateFormat('dd MMM yyyy')
                                      .format(selectedDate!)
                                  : 'Select Date',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.description_outlined),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: Theme.of(context).dividerColor),
                          ),
                          leading: const Icon(Icons.attach_file),
                          title: Text(fileName ?? 'Attach Receipt (Optional)'),
                          trailing: fileName != null
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                          onTap: pickFile,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.electricBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                                isEdit ? 'Update Expense' : 'Submit Expense'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _viewReceipt(String url, String title) {
    // Handle relative URLs (common in Checked-In expenses)
    String fullUrl = url;
    if (!url.startsWith('http')) {
      if (!url.startsWith('/')) {
        fullUrl = '${config.baseUrl}/$url';
      } else {
        fullUrl = '${config.baseUrl}$url';
      }
    }

    final ext = fullUrl.split('.').last.split('?').first.toLowerCase();
    if (ext == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: fullUrl,
            title: title,
          ),
        ),
      );
    } else {
      downloadAndOpen(fullUrl);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: () async => _loadExpenses(reset: true),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent:
                    AlwaysScrollableScrollPhysics()), // Ensure scroll even if content is short
            slivers: [
              // Floating Glass App Bar
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: true,
                backgroundColor: isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.5),
                elevation: 0,
                centerTitle: true,
                title: Text('Expenses', style: AppTypography.headlineMedium),
                flexibleSpace: ClipRRect(
                  child: Container(
                    color: Colors.transparent, // Handled by aurora bg mostly
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _loadExpenses(reset: true),
                  ),
                ],
              ),

              // Filter Island with Toggle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Column(
                    children: [
                      // View Mode Toggles
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppLayout.gapPage),
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Personal'),
                              selected: _viewMode == 'personal',
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _viewMode = 'personal';
                                    _items.clear();
                                  });
                                  _loadExpenses(reset: true);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Checked-In'),
                              selected: _viewMode == 'checked_in',
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _viewMode = 'checked_in';
                                    _checkedInItems.clear();
                                  });
                                  _loadExpenses(reset: true);
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            Container(
                              height: 24,
                              width: 1,
                              color: Theme.of(context).dividerColor,
                            ),
                            const SizedBox(width: 16),
                            // Existing filters button
                            ActionChip(
                              avatar: const Icon(Icons.filter_list, size: 16),
                              label: const Text('Filters'),
                              onPressed: _openFilterDialog,
                            ),
                            if (_activeFilters.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              ActionChip(
                                avatar: const Icon(Icons.close, size: 16),
                                label: const Text('Clear'),
                                onPressed: _clearFilters,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Active Filters Display
                      if (_activeFilters.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppLayout.gapPage, 8, AppLayout.gapPage, 0),
                          child: SizedBox(
                            height: 30,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _activeFilters.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _activeFilters[index],
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Summary Card (if loaded and personal mode)
              if (_viewMode == 'personal' &&
                  _totals != null &&
                  _items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.gapPage, vertical: 8),
                    child: GlassContainer(
                      isNeon: isDark,
                      padding: const EdgeInsets.all(AppLayout.gapL),
                      child: IntrinsicHeight(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSummaryItem('Total', _totals!.totalAmount,
                                AppPalette.electricBlue),
                            VerticalDivider(
                                color: Theme.of(context).dividerColor),
                            _buildSummaryItem('Approved',
                                _totals!.approvedAmount, Colors.green),
                            VerticalDivider(
                                color: Theme.of(context).dividerColor),
                            _buildSummaryItem('Pending', _totals!.pendingAmount,
                                Colors.orange),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Loading State
              if (_loading &&
                  (_viewMode == 'personal' ? _items : _checkedInItems).isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),

              // Empty State
              if (!_loading &&
                  (_viewMode == 'personal' ? _items : _checkedInItems).isEmpty)
                SliverFillRemaining(
                  child: Center(
                      child: Text(_viewMode == 'personal'
                          ? 'No expenses found'
                          : 'No checked-in expenses found')),
                ),

              // Expense List
              if ((_viewMode == 'personal' ? _items : _checkedInItems)
                  .isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.gapPage,
                    vertical: AppLayout.gapM,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final currentList =
                            _viewMode == 'personal' ? _items : _checkedInItems;
                        // Load more logic
                        if (index == currentList.length) {
                          if (_page < _lastPage) {
                            _loadMore();
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          } else {
                            return const SizedBox(height: 60); // Spacer for FAB
                          }
                        }

                        if (_viewMode == 'personal') {
                          final item = _items[index];
                          final isApproved =
                              item.status.toLowerCase() == 'approved';

                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppLayout.gapS),
                            child: DataListTile(
                              // Use title and status pill, use rows for data
                              title: _currencyFormat.format(item.amount),
                              statusPill: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(item.status)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _getStatusColor(item.status)),
                                ),
                                child: Text(
                                  item.statusLabel,
                                  style: TextStyle(
                                      color: _getStatusColor(item.status),
                                      fontSize: 12),
                                ),
                              ),

                              // Compact Key-Value Data
                              compactRows: [
                                InfoRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Date',
                                  value: item.expenseDate ?? '-',
                                ),
                                InfoRow(
                                  icon: Icons.category_outlined,
                                  label: 'Category',
                                  value: item.section.isNotEmpty
                                      ? item.section
                                      : 'General',
                                ),
                              ],

                              // Expandable Details
                              expandedRows: [
                                const Text('Description',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                Text(
                                  item.description ?? 'No description',
                                  style: AppTypography.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                if (isApproved &&
                                    item.approvedAmount != item.amount)
                                  Text(
                                    'Approved Amount: ${_currencyFormat.format(item.approvedAmount)}',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                if (item.dueAmount > 0)
                                  Text(
                                    'Due Amount: ${_currencyFormat.format(item.dueAmount)}',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold),
                                  ),
                              ],

                              // Actions
                              actions: [
                                // View Receipt
                                if (item.fileUrl != null)
                                  SizedBox(
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.visibility,
                                          size: 14),
                                      label: const Text('Receipt',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () => _viewReceipt(
                                          item.fileUrl!,
                                          item.receiptFilename ?? 'Receipt'),
                                    ),
                                  ),
                                // Edit Button (Only for Pending)
                                if (!isApproved &&
                                    item.status.toLowerCase() == 'pending') ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange),
                                      icon: const Icon(Icons.edit, size: 14),
                                      label: const Text('Edit',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () =>
                                          _openCreateExpenseDialog(item: item),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red),
                                      icon: const Icon(Icons.delete, size: 14),
                                      label: const Text('Delete',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () => _confirmDelete(item.id),
                                    ),
                                  ),
                                ],
                              ],
                            )
                                .animate(
                                    delay: (50 * (index % 10))
                                        .ms) // Modulo to stagger pages nicely
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.1, end: 0),
                          );
                        } else {
                          // Checked-In Item
                          final item = _checkedInItems[index];

                          // Prefer display_name, fallback to personName, fallback to 'Unknown'
                          final primaryName =
                              item.displayName ?? item.personName ?? 'Unknown';

                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppLayout.gapS),
                            child: DataListTile(
                              // Show approved total
                              title: _currencyFormat.format(item.approvedTotal),

                              // Blue Pill
                              statusPill: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: const Text(
                                  'Checked-In',
                                  style: TextStyle(
                                      color: Colors.blue, fontSize: 12),
                                ),
                              ),

                              compactRows: [
                                InfoRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Date',
                                  value: item.createdAt ?? '-',
                                ),
                                InfoRow(
                                  icon: Icons.person_outline,
                                  label: 'Name',
                                  value: primaryName,
                                ),
                              ],

                              expandedRows: [
                                if (item.filename != null)
                                  InfoRow(
                                    icon: Icons.attach_file,
                                    label: 'File',
                                    value: item.filename!,
                                  ),
                                if (item.approverName != null)
                                  InfoRow(
                                    icon: Icons.verified_user_outlined,
                                    label: 'Approver',
                                    value: item.approverName!,
                                  ),
                              ],

                              actions: [
                                if (item.url != null)
                                  SizedBox(
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.visibility,
                                          size: 14),
                                      label: const Text('View Document',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () => _viewReceipt(item.url!,
                                          item.filename ?? 'Document'),
                                    ),
                                  ),
                              ],
                            ).animate(delay: (50 * (index % 10)).ms).fadeIn(),
                          );
                        }
                      },
                      childCount: (_viewMode == 'personal'
                              ? _items.length
                              : _checkedInItems.length) +
                          1, // +1 for loader/spacer
                    ),
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: ScaleButton(
          onTap: _openCreateExpenseDialog,
          child: GlassContainer(
            isNeon: true,
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: Colors.white),
                const SizedBox(width: 8),
                Text('Add Expense',
                    style:
                        AppTypography.labelLarge.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          _currencyFormat.format(amount),
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
