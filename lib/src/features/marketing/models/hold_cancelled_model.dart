class HoldCancelledItem {
  final int id;
  final String jobOrderNo;
  final String description;
  final HoldStatus status;
  final HoldEnquiry? enquiry;

  HoldCancelledItem({
    required this.id,
    required this.jobOrderNo,
    required this.description,
    required this.status,
    this.enquiry,
  });

  factory HoldCancelledItem.fromJson(Map<String, dynamic> json) {
    return HoldCancelledItem(
      id: json['id'],
      jobOrderNo: json['job_order_no'] ?? '',
      description: json['description'] ?? '',
      status: HoldStatus.fromJson(json['status'] ?? {}),
      enquiry: json['enquiry'] != null
          ? HoldEnquiry.fromJson(json['enquiry'])
          : null,
    );
  }
}

class HoldStatus {
  final String label;
  final String type; // e.g., 'warning', 'danger'
  final String reason;

  HoldStatus({
    required this.label,
    required this.type,
    required this.reason,
  });

  factory HoldStatus.fromJson(Map<String, dynamic> json) {
    return HoldStatus(
      label: json['label'] ?? '',
      type: json['type'] ?? 'default',
      reason: json['reason'] ?? '',
    );
  }
}

class HoldEnquiry {
  final int id;
  final String note;
  final List<HoldMedia> media;
  final String createdAt;

  HoldEnquiry({
    required this.id,
    required this.note,
    required this.media,
    required this.createdAt,
  });

  factory HoldEnquiry.fromJson(Map<String, dynamic> json) {
    return HoldEnquiry(
      id: json['id'],
      note: json['note'] ?? '',
      media: (json['media'] as List?)
              ?.map((e) => HoldMedia.fromJson(e))
              .toList() ??
          [],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class HoldMedia {
  final String path;
  final String name;
  final String url;

  HoldMedia({
    required this.path,
    required this.name,
    required this.url,
  });

  factory HoldMedia.fromJson(Map<String, dynamic> json) {
    return HoldMedia(
      path: json['path'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
