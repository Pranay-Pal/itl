import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/features/expenses/data/expenses_repository.dart';
import 'package:itl/src/features/expenses/models/expense.dart';
import 'package:itl/src/features/expenses/models/expenses_response.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/services/download_util.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  final ExpensesRepository _repository = ExpensesRepository();
  final ApiService _apiService = ApiService();
  late final TabController _tabController;

  final Map<String, List<Expense>> _itemsBySection = {
    'marketing': <Expense>[],
    'office': <Expense>[],
    'personal': <Expense>[],
  };

  final Map<String, ExpensesResponse?> _responseBySection = {
    'marketing': null,
    'office': null,
    'personal': null,
  };

  final Map<String, bool> _loadingBySection = {
    'marketing': false,
    'office': false,
    'personal': false,
  };

  final Map<String, bool> _loadingMoreBySection = {
    'marketing': false,
    'office': false,
    'personal': false,
  };

  final Map<String, int> _pageBySection = {
    'marketing': 1,
    'office': 1,
    'personal': 1,
  };

  final TextEditingController _searchController = TextEditingController();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  String _statusFilter = 'all';
  int? _selectedMonth;
  int? _selectedYear;
  String? _searchTerm;
  bool _groupPersonal = false;
  int _perPage = 10;

  bool _isSendingApproval = false;
  final String _currentSection = 'personal';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadSection(_currentSection, reset: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSection(String section, {bool reset = false}) async {
    if (_loadingBySection[section] == true) return;
    setState(() {
      _loadingBySection[section] = true;
      if (reset) _pageBySection[section] = 1;
    });

    final page = _pageBySection[section] ?? 1;

    try {
      final response = await _repository.fetchExpenses(
        section: section,
        status: _statusFilter == 'all' ? null : _statusFilter,
        month: _selectedMonth,
        year: _selectedYear,
        search: _searchTerm,
        groupPersonal: section == 'personal' ? _groupPersonal : null,
        page: page,
        perPage: _perPage,
      );

      setState(() {
        _responseBySection[section] = response;
        final current =
            reset ? <Expense>[] : (_itemsBySection[section] ?? <Expense>[]);
        _itemsBySection[section] = [...current, ...response.expenses];
      });
    } catch (error) {
      _showSnack('Failed to load $section expenses: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loadingBySection[section] = false;
          _loadingMoreBySection[section] = false;
        });
      }
    }
  }

  Future<void> _loadMore(String section) async {
    if (!_canLoadMore(section) || (_loadingMoreBySection[section] ?? false)) {
      return;
    }
    setState(() {
      _loadingMoreBySection[section] = true;
      _pageBySection[section] = (_pageBySection[section] ?? 1) + 1;
    });
    await _loadSection(section);
  }

  bool _canLoadMore(String section) {
    final meta = _responseBySection[section]?.meta;
    if (meta == null) return false;
    final current = _asInt(meta['current_page']);
    final last = _asInt(meta['last_page']);
    if (current == null || last == null) return false;
    return current < last;
  }

  Future<void> _refreshCurrentSection() {
    return _loadSection(_currentSection, reset: true);
  }

  void _openFilterDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        String tempStatus = _statusFilter;
        int? tempMonth = _selectedMonth;
        int? tempYear = _selectedYear;
        String? tempSearch = _searchTerm;
        bool tempGroupPersonal = _groupPersonal;
        int tempPerPage = _perPage;
        _searchController.text = tempSearch ?? '';

        return AlertDialog(
          title: const Text('Filter expenses'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey('status-$tempStatus'),
                      initialValue: tempStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(
                            value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => tempStatus = value ?? 'all'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey('month-${tempMonth ?? 'all'}'),
                            initialValue: tempMonth,
                            decoration: const InputDecoration(
                              labelText: 'Month',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('All months')),
                              ...List.generate(12, (index) {
                                final monthNumber = index + 1;
                                return DropdownMenuItem(
                                  value: monthNumber,
                                  child: Text(DateFormat.MMMM()
                                      .format(DateTime(0, monthNumber))),
                                );
                              }),
                            ],
                            onChanged: (value) =>
                                setDialogState(() => tempMonth = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey('year-${tempYear ?? 'all'}'),
                            initialValue: tempYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('All years')),
                              ...List.generate(6, (index) {
                                final year = DateTime.now().year - index;
                                return DropdownMenuItem(
                                    value: year, child: Text(year.toString()));
                              }),
                            ],
                            onChanged: (value) =>
                                setDialogState(() => tempYear = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search name or code',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setDialogState(() => tempSearch =
                          value.trim().isEmpty ? null : value.trim()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      key: ValueKey('perpage-$tempPerPage'),
                      initialValue: tempPerPage,
                      decoration: const InputDecoration(
                        labelText: 'Items per page',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 20, child: Text('20')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => tempPerPage = value ?? 10),
                    ),
                    if (_currentSection == 'personal') ...[
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Group personal expenses'),
                        value: tempGroupPersonal,
                        onChanged: (value) =>
                            setDialogState(() => tempGroupPersonal = value),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clearFilters();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _statusFilter = tempStatus;
                  _selectedMonth = tempMonth;
                  _selectedYear = tempYear;
                  _searchTerm = tempSearch;
                  _perPage = tempPerPage;
                  if (_currentSection == 'personal') {
                    _groupPersonal = tempGroupPersonal;
                  }
                  _pageBySection[_currentSection] = 1;
                  _itemsBySection[_currentSection] = <Expense>[];
                });
                _loadSection(_currentSection, reset: true);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = 'all';
      _selectedMonth = null;
      _selectedYear = null;
      _searchTerm = null;
      _searchController.clear();
      _perPage = 10;
      _groupPersonal = false;
      _itemsBySection[_currentSection] = <Expense>[];
      _pageBySection[_currentSection] = 1;
    });
    _loadSection(_currentSection, reset: true);
  }

  bool get _hasActiveFilters {
    return _statusFilter != 'all' ||
        _selectedMonth != null ||
        _selectedYear != null ||
        (_searchTerm != null && _searchTerm!.isNotEmpty) ||
        (_currentSection == 'personal' && _groupPersonal) ||
        _perPage != 10;
  }

  List<Widget> _buildFilterChips() {
    final chips = <Widget>[];
    if (_statusFilter != 'all') {
      chips.add(_buildChip('Status: $_statusFilter', () {
        setState(() => _statusFilter = 'all');
        _refreshCurrentSection();
      }));
    }
    if (_selectedMonth != null) {
      final monthLabel = DateFormat.MMMM().format(DateTime(0, _selectedMonth!));
      chips.add(_buildChip('Month: $monthLabel', () {
        setState(() => _selectedMonth = null);
        _refreshCurrentSection();
      }));
    }
    if (_selectedYear != null) {
      chips.add(_buildChip('Year: $_selectedYear', () {
        setState(() => _selectedYear = null);
        _refreshCurrentSection();
      }));
    }
    if (_searchTerm != null && _searchTerm!.isNotEmpty) {
      chips.add(_buildChip('Search: $_searchTerm', () {
        setState(() => _searchTerm = null);
        _refreshCurrentSection();
      }));
    }
    if (_currentSection == 'personal' && !_groupPersonal) {
      chips.add(_buildChip('Grouped: Off', () {
        setState(() => _groupPersonal = true);
        _refreshCurrentSection();
      }));
    }
    if (_perPage != 10) {
      chips.add(_buildChip('Per page: $_perPage', () {
        setState(() => _perPage = 10);
        _refreshCurrentSection();
      }));
    }
    return chips;
  }

  Widget _buildChip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        onDeleted: onDeleted,
      ),
    );
  }

  Widget _buildSectionBody(String section) {
    final items = _itemsBySection[section] ?? <Expense>[];
    final isLoading = _loadingBySection[section] ?? false;
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadSection(section, reset: true),
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('No expenses yet. Tap + to add.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSection(section, reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: items.length + (_canLoadMore(section) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loadingMoreBySection[section] == true
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: () => _loadMore(section),
                        child: const Text('Load more'),
                      ),
              ),
            );
          }
          final expense = items[index];
          return _ExpenseCard(
            expense: expense,
            currencyFormat: _currencyFormat,
            onViewDetails: () => _showExpenseDetails(expense),
            onDownloadReceipt: () {
              final url = expense.receiptUrl ??
                  (expense.receiptUrls.isNotEmpty
                      ? expense.receiptUrls.first
                      : null);
              if (url != null) downloadAndOpen(url);
            },
            onDownloadSummary: expense.approvalSummaryUrl == null
                ? null
                : () => downloadAndOpen(expense.approvalSummaryUrl!),
            onEdit: expense.isPersonal && expense.isPending
                ? () => _openExpenseForm(existing: expense)
                : null,
            onDelete: expense.isPersonal && expense.isPending
                ? () => _confirmDelete(expense)
                : null,
          );
        },
      ),
    );
  }

  void _showExpenseDetails(Expense expense) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    expense.personName ??
                        expense.marketingPersonName ??
                        'Expense #${expense.id}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(expense.section.toUpperCase())),
                      Chip(label: Text(expense.status.toUpperCase())),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoRow('Amount', _currencyFormat.format(expense.amount)),
                  _infoRow('Approved',
                      _currencyFormat.format(expense.approvedAmount)),
                  _infoRow('Due', _currencyFormat.format(expense.dueAmount)),
                  _infoRow('Date range',
                      _formatDateRange(expense.fromDate, expense.toDate)),
                  if (expense.description?.isNotEmpty ?? false)
                    _infoRow('Description', expense.description!),
                  if (expense.approvalSummaryUrl != null)
                    TextButton.icon(
                      onPressed: () =>
                          downloadAndOpen(expense.approvalSummaryUrl!),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Open approval summary'),
                    ),
                  if (expense.receiptUrl != null ||
                      expense.receiptUrls.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        final url =
                            expense.receiptUrl ?? expense.receiptUrls.first;
                        downloadAndOpen(url);
                      },
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('View receipt'),
                    ),
                  if (expense.isPersonal && expense.isPending)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openExpenseForm(existing: expense);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDelete(expense);
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Not specified';
    final formatter = DateFormat('dd MMM yyyy');
    if (start != null && end != null) {
      return '${formatter.format(start)} - ${formatter.format(end)}';
    }
    final solo = start ?? end;
    return formatter.format(solo!);
  }

  void _confirmDelete(Expense expense) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete expense'),
          content: const Text('This personal expense is pending. Delete it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final success =
                    await _repository.deletePersonalExpense(expense.id);
                if (success) {
                  if (!mounted) return;
                  setState(() {
                    _itemsBySection['personal']
                        ?.removeWhere((e) => e.id == expense.id);
                  });
                  _showSnack('Expense deleted');
                } else {
                  _showSnack('Failed to delete expense');
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _openExpenseForm({Expense? existing}) {
    const String section = 'personal';
    final formKey = GlobalKey<FormState>();
    final String storedName = _apiService.userName?.trim() ?? '';
    final String existingName =
        (existing?.personName ?? existing?.marketingPersonName ?? '').trim();
    final String resolvedName =
        storedName.isNotEmpty ? storedName : existingName;
    final bool needsManualName = resolvedName.isEmpty;
    final TextEditingController manualNameController =
        TextEditingController(text: existingName);
    final TextEditingController amountController =
        TextEditingController(text: existing?.amount.toString());
    final TextEditingController descriptionController =
        TextEditingController(text: existing?.description ?? '');
    DateTime? fromDate = existing?.fromDate;
    DateTime? toDate = existing?.toDate;
    String? receiptPath;
    String? receiptName;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> localPickReceipt() async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                );
                if (result == null) return;
                final file = result.files.single;
                if (file.size > 20 * 1024 * 1024) {
                  _showSnack('File must be under 20 MB.');
                  return;
                }
                if (file.path == null) return;
                setSheetState(() {
                  receiptPath = file.path;
                  receiptName = file.name;
                });
              }

              Future<void> localPickDate(bool isStart) async {
                final result = await showDatePicker(
                  context: context,
                  initialDate: (isStart ? fromDate : toDate) ?? DateTime.now(),
                  firstDate: DateTime(DateTime.now().year - 5),
                  lastDate: DateTime(DateTime.now().year + 1),
                );
                if (result != null) {
                  setSheetState(() {
                    if (isStart) {
                      fromDate = result;
                      if (toDate != null && toDate!.isBefore(fromDate!)) {
                        toDate = result;
                      }
                    } else {
                      toDate = result;
                    }
                  });
                }
              }

              Future<void> submit() async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                if (fromDate == null || toDate == null) {
                  _showSnack('Select a date range.');
                  return;
                }
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;
                if (amount <= 0) {
                  _showSnack('Enter a valid amount.');
                  return;
                }

                Navigator.pop(context);

                final String nameForPayload = needsManualName
                    ? manualNameController.text.trim()
                    : resolvedName.trim();
                final descriptionText = descriptionController.text.trim();

                if (existing == null) {
                  await _repository.createExpense(
                    section: section,
                    marketingPersonName: nameForPayload,
                    amount: amount,
                    fromDate: fromDate!,
                    toDate: toDate!,
                    description: descriptionText,
                    receiptFilePath: receiptPath,
                  );
                } else {
                  await _repository.updatePersonalExpense(
                    expenseId: existing.id,
                    amount: amount,
                    fromDate: fromDate!,
                    toDate: toDate!,
                    marketingPersonName: nameForPayload,
                    description: descriptionText,
                    receiptFilePath: receiptPath,
                  );
                }

                await _loadSection(section, reset: true);
                if (!mounted) return;
                _showSnack(existing == null
                    ? 'Expense created successfully'
                    : 'Expense updated successfully');
              }

              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing == null ? 'New expense' : 'Update expense',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      needsManualName
                          ? TextFormField(
                              controller: manualNameController,
                              decoration: const InputDecoration(
                                labelText: 'Person name*',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Person name is required';
                                }
                                return null;
                              },
                            )
                          : InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Person name',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(resolvedName,
                                  style:
                                      const TextStyle(color: Colors.black87)),
                            ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter amount';
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed <= 0) {
                            return 'Invalid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => localPickDate(true),
                              child: Text(
                                fromDate == null
                                    ? 'From date'
                                    : DateFormat('dd MMM yyyy')
                                        .format(fromDate!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => localPickDate(false),
                              child: Text(
                                toDate == null
                                    ? 'To date'
                                    : DateFormat('dd MMM yyyy').format(toDate!),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Description is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: localPickReceipt,
                        icon: const Icon(Icons.attach_file_outlined),
                        label: Text(receiptName ?? 'Attach receipt (optional)'),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: submit,
                          child: Text(existing == null
                              ? 'Create expense'
                              : 'Update expense'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _sendPersonalApproval() async {
    setState(() => _isSendingApproval = true);
    try {
      final response = await _repository.sendPersonalExpensesForApproval(
        month: _selectedMonth,
        year: _selectedYear,
      );
      if (!mounted) return;
      if (response == null) {
        _showSnack('No pending expenses to submit.');
        return;
      }
      final url = response['download_url']?.toString();
      if (url != null) {
        await downloadAndOpen(url);
        if (!mounted) return;
      }
      _showSnack(
        'Submitted ${response['pending_count'] ?? 0} expenses for approval.',
      );
      _loadSection('personal', reset: true);
    } catch (error) {
      _showSnack('Failed to submit: $error');
    } finally {
      if (mounted) setState(() => _isSendingApproval = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final response = _responseBySection[_currentSection];
    final totals = response?.totals;
    final summaryCards = totals == null
        ? const SizedBox.shrink()
        : Row(
            children: [
              Expanded(
                  child: _SummaryCard(
                      label: 'Total',
                      value: _currencyFormat.format(totals.totalExpenses))),
              const SizedBox(width: 12),
              Expanded(
                  child: _SummaryCard(
                      label: 'Approved',
                      value: _currencyFormat.format(totals.approved))),
              const SizedBox(width: 12),
              Expanded(
                  child: _SummaryCard(
                      label: 'Due', value: _currencyFormat.format(totals.due))),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        flexibleSpace:
            Container(decoration: BoxDecoration(gradient: kBlueGradient)),
        title: const Text('Expenses', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _openFilterDialog,
            icon: Stack(
              children: [
                const Icon(Icons.filter_alt_outlined),
                if (_hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(gradient: kBlueGradient),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Personal'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                summaryCards,
                if (_hasActiveFilters)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _buildFilterChips(),
                    ),
                  ),
                if (_currentSection == 'personal')
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          _isSendingApproval ? null : _sendPersonalApproval,
                      icon: _isSendingApproval
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: const Text('Send for approval'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSectionBody('personal'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExpenseForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.currencyFormat,
    required this.onViewDetails,
    required this.onDownloadReceipt,
    this.onDownloadSummary,
    this.onEdit,
    this.onDelete,
  });

  final Expense expense;
  final NumberFormat currencyFormat;
  final VoidCallback onViewDetails;
  final VoidCallback? onDownloadReceipt;
  final VoidCallback? onDownloadSummary;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Color get _statusColor {
    switch (expense.status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense.personName ??
                        expense.marketingPersonName ??
                        'Expense #${expense.id}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    expense.status.toUpperCase(),
                    style: TextStyle(
                        color: _statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              expense.section.toUpperCase(),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Amount'),
                      Text(
                        currencyFormat.format(expense.amount),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Approved'),
                      Text(currencyFormat.format(expense.approvedAmount)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Due'),
                      Text(currencyFormat.format(expense.dueAmount)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formatDateRange(expense.fromDate, expense.toDate),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onViewDetails,
                  child: const Text('Details'),
                ),
                if (onDownloadReceipt != null)
                  OutlinedButton(
                    onPressed: onDownloadReceipt,
                    child: const Text('Receipt'),
                  ),
                if (onDownloadSummary != null)
                  OutlinedButton(
                    onPressed: onDownloadSummary,
                    child: const Text('Summary'),
                  ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Date not provided';
    final formatter = DateFormat('dd MMM yyyy');
    if (start != null && end != null) {
      return '${formatter.format(start)} - ${formatter.format(end)}';
    }
    final solo = start ?? end;
    return formatter.format(solo!);
  }
}
