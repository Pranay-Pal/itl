class CheckedInExpense {
  final int id;
  final String? url;
  final String? filename;
  final double approvedTotal;
  final String? approvedSection;
  final String? createdAt;
  final String? personName;
  final String? displayName;
  final int? approverId;
  final String? approverName;

  CheckedInExpense({
    required this.id,
    this.url,
    this.filename,
    this.approvedTotal = 0.0,
    this.approvedSection,
    this.createdAt,
    this.personName,
    this.displayName,
    this.approverId,
    this.approverName,
  });

  factory CheckedInExpense.fromJson(Map<String, dynamic> json) {
    return CheckedInExpense(
      id: json['id'] is int
          ? json['id']
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      url: json['url']?.toString(),
      filename: json['filename']?.toString(),
      approvedTotal:
          double.tryParse(json['approved_total']?.toString() ?? '0') ?? 0.0,
      approvedSection: json['approved_section']?.toString(),
      createdAt: json['created_at']?.toString(),
      personName: json['person_name']?.toString(),
      displayName: json['display_name']?.toString(),
      approverId: int.tryParse(json['approver_id']?.toString() ?? ''),
      approverName: json['approver_name']?.toString(),
    );
  }
}

class CheckedInExpenseResponse {
  final List<CheckedInExpense> items;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  CheckedInExpenseResponse({
    required this.items,
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory CheckedInExpenseResponse.fromJson(Map<String, dynamic> json) {
    var itemsList = <CheckedInExpense>[];
    var dataRoot = json['data'];

    // Handle standard Laravel pagination structure
    // root -> data -> data (items)
    var rawItems = [];
    int total = 0;
    int perPage = 15;
    int currentPage = 1;
    int lastPage = 1;

    if (dataRoot is Map<String, dynamic>) {
      if (dataRoot['data'] is List) {
        rawItems = dataRoot['data'];
      }
      total = dataRoot['total'] is int ? dataRoot['total'] : 0;
      perPage = int.tryParse(dataRoot['per_page']?.toString() ?? '15') ?? 15;
      currentPage =
          dataRoot['current_page'] is int ? dataRoot['current_page'] : 1;
      lastPage = dataRoot['last_page'] is int ? dataRoot['last_page'] : 1;
    } else if (json['data'] is List) {
      // Fallback if data is directly the list (unlikely based on example but good safety)
      rawItems = json['data'];
    }

    for (var item in rawItems) {
      if (item is Map<String, dynamic>) {
        itemsList.add(CheckedInExpense.fromJson(item));
      }
    }

    return CheckedInExpenseResponse(
      items: itemsList,
      total: total,
      perPage: perPage,
      currentPage: currentPage,
      lastPage: lastPage,
    );
  }
}
