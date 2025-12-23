import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:itl/src/config/constants.dart';
import 'package:itl/src/services/api_service.dart';
import 'package:itl/src/services/marketing_service.dart';
import 'package:itl/src/features/expenses/models/expense_model.dart';
import 'package:itl/src/services/download_util.dart';
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
    _loadExpenses(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses({bool reset = false}) async {
    if (_loading) return;

    final userCode = _apiService.userCode;
    if (userCode == null) {
      _showSnack('User code not found');
      return;
    }

    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        _items = [];
      }
    });

    try {
      final response = await _marketingService.getExpenses(
        userCode: userCode,
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
            // Keep existing totals or update if needed? usually totals are global for the filter
            if (response.totals != null) _totals = response.totals;
          }
          _lastPage = response.lastPage;
          _page = response.currentPage;
        });
      }
    } catch (e) {
      _showSnack('Failed to load expenses: $e');
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

  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        int? tempMonth = _selectedMonth;
        int? tempYear = _selectedYear;
        return AlertDialog(
          title: const Text('Filter Expenses'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(labelText: 'Search'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: tempMonth,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...List.generate(12, (i) => i + 1).map((m) =>
                      DropdownMenuItem(
                          value: m,
                          child:
                              Text(DateFormat.MMMM().format(DateTime(0, m)))))
                ],
                onChanged: (v) => tempMonth = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: tempYear,
                decoration: const InputDecoration(labelText: 'Year'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...List.generate(5, (i) => DateTime.now().year - i).map((y) =>
                      DropdownMenuItem(value: y, child: Text(y.toString())))
                ],
                onChanged: (v) => tempYear = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchTerm = '';
                  _selectedMonth = null;
                  _selectedYear = null;
                });
                Navigator.pop(ctx);
                _loadExpenses(reset: true);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchTerm = _searchController.text;
                  _selectedMonth = tempMonth;
                  _selectedYear = tempYear;
                });
                Navigator.pop(ctx);
                _loadExpenses(reset: true);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _openCreateExpenseDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final sectionController = TextEditingController();
    DateTime? selectedDate = DateTime.now();
    String? filePath;
    String? fileName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickFile() async {
            showModalBottomSheet(
              context: context,
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
                      },
                    ),
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
            if (userCode == null) return;

            try {
              Navigator.pop(context); // Close dialog first
              _showSnack('Creating expense...');
              await _marketingService.createExpense(
                userCode: userCode,
                amount: amount,
                section: sectionController.text.isNotEmpty
                    ? sectionController.text
                    : 'personal',
                fromDate: DateFormat('yyyy-MM-dd').format(selectedDate!),
                description: descriptionController.text,
                filePath: filePath,
              );
              _showSnack('Expense created!');
              _loadExpenses(reset: true);
            } catch (e) {
              _showSnack('Error creating expense: $e');
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('New Expense',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount *'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: sectionController,
                      decoration: const InputDecoration(
                          labelText: 'Category (Optional)'),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date'),
                        child: Text(selectedDate != null
                            ? DateFormat('dd MMM yyyy').format(selectedDate!)
                            : 'Select Date'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_file),
                      title: Text(fileName ?? 'Attach Receipt (Optional)'),
                      onTap: pickFile,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: submit,
                      child: const Text('Submit'),
                    ),
                    const SizedBox(height: 20),
                  ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace:
            Container(decoration: BoxDecoration(gradient: kBlueGradient)),
        title: const Text('Expenses', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadExpenses(reset: true),
          )
        ],
      ),
      body: _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Center(child: Text('No expenses found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80, top: 10, left: 10, right: 10),
      itemCount: _items.length + 2, // +1 for summary, +1 for loader/end
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          if (_totals == null) return const SizedBox.shrink();
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryItem(
                        'Total', _totals!.totalAmount, Colors.blue),
                    const VerticalDivider(),
                    _buildSummaryItem(
                        'Approved', _totals!.approvedAmount, Colors.green),
                    const VerticalDivider(),
                    _buildSummaryItem(
                        'Pending', _totals!.pendingAmount, Colors.orange),
                  ],
                ),
              ),
            ),
          );
        }

        final index = i - 1;
        if (index == _items.length) {
          if (_page < _lastPage) {
            return Center(
              child: TextButton(
                  onPressed: _loadMore, child: const Text('Load More')),
            );
          }
          return const SizedBox.shrink();
        }

        final item = _items[index];
        final isApproved = item.status.toLowerCase() == 'approved';

        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currencyFormat.format(item.amount),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: _getStatusColor(item.status)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _getStatusColor(item.status))),
                      child: Text(
                        item.statusLabel,
                        style: TextStyle(
                            color: _getStatusColor(item.status), fontSize: 12),
                      ),
                    )
                  ],
                ),
                if (isApproved && item.approvedAmount != item.amount) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Approved: ${_currencyFormat.format(item.approvedAmount)}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ],
                if (item.dueAmount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${_currencyFormat.format(item.dueAmount)}',
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Text(item.description ?? 'No description',
                    style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.expenseDate != null)
                          Text(item.expenseDate!,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        Text('Category: ${item.section}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    if (item.fileUrl != null)
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('View',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () {
                            final url = item.fileUrl!;
                            final ext = url
                                .split('.')
                                .last
                                .split('?')
                                .first
                                .toLowerCase();
                            if (ext == 'pdf') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfViewerScreen(
                                    url: url,
                                    title: item.receiptFilename ?? 'Receipt',
                                  ),
                                ),
                              );
                            } else {
                              downloadAndOpen(url);
                            }
                          },
                        ),
                      )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
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

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700]),
        ),
        const SizedBox(height: 4),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
