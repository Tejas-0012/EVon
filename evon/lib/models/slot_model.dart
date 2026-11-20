class SlotModel {
  final String id;
  final String stationId;
  final String slotDate;
  final String slotTime;
  final String status; // 'Available', 'Booked', 'Occupied', 'Maintenance'

  SlotModel({
    required this.id,
    required this.stationId,
    required this.slotDate,
    required this.slotTime,
    required this.status,
  });

  bool get isAvailable => status.toLowerCase() == 'available';

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      id: json['_id'] ?? json['id'] ?? '',
      stationId: json['station'] is Map
          ? (json['station']['_id'] ?? json['station']['id'] ?? '')
          : (json['station']?.toString() ?? ''),
      slotDate: json['slotDate'] ?? '',
      slotTime: json['slotTime'] ?? '',
      status: json['status'] ?? 'Available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station': stationId,
      'slotDate': slotDate,
      'slotTime': slotTime,
      'status': status,
    };
  }
}
