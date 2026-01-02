import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:itl/src/common/utils/file_viewer_service.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/common/widgets/design_system/compact_data_tile.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/meter/models/meter_reading_model.dart';
import 'package:itl/src/services/meter_service.dart';

class MeterDashboardScreen extends StatefulWidget {
  const MeterDashboardScreen({super.key});

  @override
  State<MeterDashboardScreen> createState() => _MeterDashboardScreenState();
}

class _MeterDashboardScreenState extends State<MeterDashboardScreen> {
  final MeterService _meterService = MeterService();
  final ScrollController _scrollController = ScrollController();

  List<MeterReading> _readings = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  int _currentPage = 1;
  int _lastPage = 1;

  // State to determine if we are currently "Running" a meter
  bool _isMeterRunning = false;
  MeterReading? _latestReading;

  @override
  void initState() {
    super.initState();
    _fetchReadings();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isMoreLoading &&
        _currentPage < _lastPage) {
      _loadMore();
    }
  }

  Future<void> _fetchReadings() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final response = await _meterService.getReadings(page: 1);

      List<MeterReading> list = response.data.readings;
      MeterReading? latest;
      bool isRunning = false;

      if (list.isNotEmpty) {
        latest = list.first;
        // Logic: specific meter reading is open if ending_reading is null
        if (latest.startingReading != null && latest.endingReading == null) {
          isRunning = true;
        }
      }

      if (mounted) {
        setState(() {
          _readings = list;
          _currentPage = response.data.currentPage;
          _lastPage = response.data.lastPage;
          _latestReading = latest;
          _isMeterRunning = isRunning;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isMoreLoading) return;
    setState(() => _isMoreLoading = true);

    try {
      final response = await _meterService.getReadings(page: _currentPage + 1);
      if (mounted) {
        setState(() {
          _readings.addAll(response.data.readings);
          _currentPage = response.data.currentPage;
          _lastPage = response.data.lastPage;
          _isMoreLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMoreLoading = false);
      }
    }
  }

  void _openActionModal({required bool isStop}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MeterActionModal(
        isStop: isStop,
        onSubmit: (reading, desc, path) async {
          Navigator.pop(context); // close modal
          await _submitReading(reading, desc, path);
        },
      ),
    );
  }

  Future<void> _submitReading(
      double reading, String? desc, String? path) async {
    setState(() => _isLoading = true);
    try {
      await _meterService.uploadReading(
        currentReading: reading,
        description: desc,
        filePath: path,
      );
      if (!mounted) return;

      // Reset loading so _fetchReadings can run
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Meter reading submitted successfully!')));
      // Refresh list to update state
      _fetchReadings();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Meter Readings'),
          centerTitle: true,
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh), onPressed: _fetchReadings)
          ],
        ),
        body: Column(
          children: [
            _buildStatusCard(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_isLoading && _readings.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(AppLayout.gapM),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isMeterRunning
            ? AppPalette.electricBlue.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isMeterRunning
              ? AppPalette.electricBlue
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isMeterRunning ? AppPalette.electricBlue : Colors.grey,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isMeterRunning ? Icons.timelapse : Icons.check_circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isMeterRunning ? 'Meter Running' : 'Off Duty',
                  style: AppTypography.headlineSmall,
                ),
                if (_isMeterRunning && _latestReading != null)
                  Text(
                    'Started at: ${_latestReading?.startingReading ?? 0} km',
                    style: AppTypography.bodySmall.copyWith(color: Colors.grey),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isMeterRunning ? Colors.redAccent : AppPalette.successGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => _openActionModal(isStop: _isMeterRunning),
            child: Text(
              _isMeterRunning ? 'STOP' : 'START',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
          )
              .animate(target: _isMeterRunning ? 1 : 0)
              .shimmer(duration: 2.seconds, color: Colors.white54)
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading && _readings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_readings.isEmpty) {
      return const Center(child: Text('No meter readings found'));
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.gapM),
      itemCount: _readings.length + 1,
      itemBuilder: (context, index) {
        if (index == _readings.length) {
          return _isMoreLoading
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox(height: 60);
        }

        final item = _readings[index];
        final isCompleted = item.endingReading != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: DataListTile(
            title: isCompleted ? 'Trip Completed' : 'Trip In Progress',
            subtitle: item.startingAt ?? 'Unknown Date',
            statusPill: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isCompleted ? AppPalette.successGreen : Colors.orange)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isCompleted ? '${item.totalReading ?? 0} KM' : 'RUNNING',
                style: TextStyle(
                    color:
                        isCompleted ? AppPalette.successGreen : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
            ),
            compactRows: [
              InfoRow(
                  icon: Icons.play_arrow,
                  label: 'Start',
                  value: '${item.startingReading ?? '-'}'),
              if (isCompleted)
                InfoRow(
                    icon: Icons.stop,
                    label: 'End',
                    value: '${item.endingReading ?? '-'}'),
            ],
            expandedRows: [
              if (item.description != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child:
                      Text(item.description!, style: AppTypography.bodySmall),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.startingImage != null)
                    _buildImageBtn(context, 'Start Img', item.startingImage!),
                  const SizedBox(width: 8),
                  if (item.endingImage != null)
                    _buildImageBtn(context, 'End Img', item.endingImage!),
                ],
              )
            ],
            actions: [],
          ),
        ).animate().fadeIn(duration: 50.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }

  Widget _buildImageBtn(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => FileViewerService.viewFile(context, url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.image, size: 14),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _MeterActionModal extends StatefulWidget {
  final bool isStop;
  final Function(double reading, String? desc, String? path) onSubmit;

  const _MeterActionModal({required this.isStop, required this.onSubmit});

  @override
  State<_MeterActionModal> createState() => _MeterActionModalState();
}

class _MeterActionModalState extends State<_MeterActionModal> {
  final _readingCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isStop ? 'Stop Reading' : 'Start Reading',
              style: AppTypography.headlineSmall),
          const SizedBox(height: 16),

          TextField(
            controller: _readingCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: widget.isStop
                  ? 'Ending Reading (km)'
                  : 'Current Reading (km)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.speed),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 12),

          // Image Picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.camera_alt,
                      color: _imagePath != null
                          ? AppPalette.successGreen
                          : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(_imagePath == null
                          ? 'Take Photo of Meter'
                          : 'Photo Selected')),
                  if (_imagePath != null)
                    const Icon(Icons.check, color: AppPalette.successGreen),
                ],
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
                final val = double.tryParse(_readingCtrl.text);
                if (val == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please enter valid reading')));
                  return;
                }
                widget.onSubmit(val, _descCtrl.text, _imagePath);
              },
              child: const Text('SUBMIT',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? photo =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo != null) {
      setState(() => _imagePath = photo.path);
    }
  }
}
