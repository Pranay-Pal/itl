class MeterResponse {
  final bool success;
  final MeterData data;

  MeterResponse({required this.success, required this.data});

  factory MeterResponse.fromJson(Map<String, dynamic> json) {
    return MeterResponse(
      success: json['success'] ?? false,
      data: MeterData.fromJson(json['data'] ?? {}),
    );
  }
}

class MeterData {
  final List<MeterReading> readings;
  final int currentPage;
  final int lastPage;
  final int total;

  MeterData({
    required this.readings,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory MeterData.fromJson(Map<String, dynamic> json) {
    var list = <MeterReading>[];
    if (json['data'] != null && json['data'] is List) {
      list =
          (json['data'] as List).map((v) => MeterReading.fromJson(v)).toList();
    }
    return MeterData(
      readings: list,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      total: json['total'] ?? 0,
    );
  }
}

class MeterReading {
  final int id;
  final String? description;
  final double? startingReading;
  final String? startingAt;
  final String? startingImage;
  final double? endingReading;
  final String? endingAt;
  final String? endingImage;
  final double? totalReading;

  MeterReading({
    required this.id,
    this.description,
    this.startingReading,
    this.startingAt,
    this.startingImage,
    this.endingReading,
    this.endingAt,
    this.endingImage,
    this.totalReading,
  });

  factory MeterReading.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      return double.tryParse(val.toString());
    }

    return MeterReading(
      id: json['id'],
      description: json['description'],
      startingReading: parseDouble(json['starting_reading']),
      startingAt: json['starting_at'],
      startingImage: json['starting_image'],
      endingReading: parseDouble(json['ending_reading']),
      endingAt: json['ending_at'],
      endingImage: json['ending_image'],
      totalReading: parseDouble(json['total_reading']),
    );
  }
}
