import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/glass_container.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/marketing/models/hold_cancelled_model.dart';
import 'package:itl/src/services/api_service.dart';

class HoldCancelledScreen extends StatefulWidget {
  const HoldCancelledScreen({super.key});

  @override
  State<HoldCancelledScreen> createState() => _HoldCancelledScreenState();
}

class _HoldCancelledScreenState extends State<HoldCancelledScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final List<HoldCancelledItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _searchJob;

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
      final response = await _apiService.getHoldCancelledItems(
        page: _currentPage,
        job: _searchJob,
      );

      if (response != null && response['data'] != null) {
        final data = response['data'];
        List<dynamic> list = [];
        if (data is Map && data['data'] is List) {
          list = data['data'];
        }

        final newItems = list
            .map(
                (e) => HoldCancelledItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        setState(() {
          _items.addAll(newItems);
          _currentPage++;
          if (newItems.isEmpty || newItems.length < 10) {
            _hasMore = false; // Assuming per_page is ~10-15
          }
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      debugPrint('Error fetching hold/cancel items: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEnquiryDialog(HoldCancelledItem item) {
    final noteController = TextEditingController();
    List<String> files = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text('Submit Enquiry\n${item.jobOrderNo}',
                style: AppTypography.titleMedium),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                      hintText: 'Enter details...',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text('Attachments:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ...files.map((f) => Chip(
                            label: Text(f.split(Platform.pathSeparator).last),
                            onDeleted: () => setState(() => files.remove(f)),
                          )),
                      ActionChip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: const Text('Add File'),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            type: FileType.any,
                          );
                          if (result != null) {
                            setState(() {
                              files.addAll(
                                  result.paths.whereType<String>().toList());
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (noteController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a note')));
                    return;
                  }
                  Navigator.pop(dialogContext); // Close dialog

                  final success = await _apiService.submitHoldCancelEnquiry(
                    itemId: item.id,
                    note: noteController.text,
                    filePaths: files.isNotEmpty ? files : null,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? 'Enquiry submitted successfully'
                            : 'Failed to submit enquiry'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                    if (success) _fetchItems(refresh: true);
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Hold & Cancelled List'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .scaffoldBackgroundColor
                .withValues(alpha: 0.8),
          ),
        ),
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
                    hintText: 'Search by Job Order No.',
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        setState(() {
                          _searchJob = _searchController.text.trim();
                          if (_searchJob!.isEmpty) _searchJob = null;
                        });
                        _fetchItems(refresh: true);
                      },
                    ),
                  ),
                  onSubmitted: (val) {
                    setState(() {
                      _searchJob = val.trim();
                      if (_searchJob!.isEmpty) _searchJob = null;
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

  Widget _buildItemCard(HoldCancelledItem item) {
    Color statusColor;
    if (item.status.type == 'warning') {
      statusColor = AppPalette.warningOrange;
    } else if (item.status.type == 'danger') {
      statusColor = AppPalette.dangerRed;
    } else {
      statusColor = Colors.grey;
    }

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
                Text(item.jobOrderNo, style: AppTypography.titleMedium),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    item.status.label,
                    style:
                        AppTypography.labelSmall.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.description,
                style: AppTypography.bodyMedium
                    .copyWith(color: Colors.grey.shade400)),
            const SizedBox(height: 8),
            if (item.status.reason.isNotEmpty) ...[
              Text('Reason: ${item.status.reason}',
                  style:
                      AppTypography.bodySmall.copyWith(color: Colors.orange)),
              const SizedBox(height: 12),
            ],

            // Existing Enquiry Info if any
            if (item.enquiry != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Latest Enquiry:',
                        style: AppTypography.labelSmall
                            .copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(item.enquiry!.note, style: AppTypography.bodySmall),
                    if (item.enquiry!.media.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Attachments: ${item.enquiry!.media.length}',
                          style: AppTypography.caption),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _showEnquiryDialog(item),
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Submit Enquiry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primaryPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
