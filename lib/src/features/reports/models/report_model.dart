class ReportItem {
  final int id;
  final String? jobOrderNo;
  final String? clientName;
  final String? sampleDescription;
  final String? sampleQuality;
  final String? particulars;
  final String? reportUrl;

  ReportItem({
    required this.id,
    this.jobOrderNo,
    this.clientName,
    this.sampleDescription,
    this.sampleQuality,
    this.particulars,
    this.reportUrl,
  });

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    return ReportItem(
      id: json['id'],
      jobOrderNo: json['job_order_no'],
      clientName: json['client_name'],
      sampleDescription: json['sample_description'],
      sampleQuality: json['sample_quality'],
      particulars: json['particulars'],
      reportUrl: json['report_url'],
    );
  }
}

class ReportResponse {
  final List<ReportItem> items;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  ReportResponse({
    required this.items,
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    var itemsList = <ReportItem>[];
    Map<String, dynamic>? paginator;

    // Structure: data -> items -> { current_page, data: [...] }
    if (json['items'] != null) {
      if (json['items'] is Map) {
        paginator = json['items'];
        var rawData = paginator?['data'];
        if (rawData is List) {
          for (var v in rawData) {
            itemsList.add(ReportItem.fromJson(v));
          }
        }
      } else if (json['items'] is List) {
        // Fallback if structure is flat
        for (var v in json['items']) {
          itemsList.add(ReportItem.fromJson(v));
        }
      }
    }

    final metaSource = paginator ?? json;

    return ReportResponse(
      items: itemsList,
      total: metaSource['total'] ?? 0,
      perPage: int.tryParse(metaSource['per_page']?.toString() ?? '25') ?? 25,
      currentPage: metaSource['current_page'] ?? 1,
      lastPage: metaSource['last_page'] ?? 1,
    );
  }
}
