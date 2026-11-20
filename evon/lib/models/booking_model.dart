class BookingModel {
  final String id;
  final String stationId;
  final String stationName;
  final String stationAddress;
  final String slotId;
  final String slotDate;
  final String slotTime;
  final String vehicleType;
  final double batteryCapacity;
  final double currentSoc;
  final double desiredSoc;
  final double energyRequired;
  final double chargingDuration;
  final double estimatedCost;
  final String status; // 'Pending', 'Confirmed', 'Completed', 'Cancelled'
  final String paymentStatus; // 'Pending', 'Paid', 'Refunded'
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.stationId,
    required this.stationName,
    this.stationAddress = '',
    required this.slotId,
    required this.slotDate,
    required this.slotTime,
    this.vehicleType = 'Electric Car',
    required this.batteryCapacity,
    required this.currentSoc,
    required this.desiredSoc,
    required this.energyRequired,
    required this.chargingDuration,
    required this.estimatedCost,
    this.status = 'Pending',
    this.paymentStatus = 'Pending',
    required this.createdAt,
  });

  bool get isConfirmed =>
      status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'paid';
  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' ||
      paymentStatus.toLowerCase() == 'refunded';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get canCancel => !isCancelled && !isCompleted;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    String stId = '';
    String stName = 'EV Charging Station';
    String stAddr = '';

    if (json['station'] is Map) {
      stId = json['station']['_id'] ?? json['station']['id'] ?? '';
      final nameCandidate = json['station']['stationName'] ?? json['station']['name'];
      if (nameCandidate != null && nameCandidate.toString().trim().isNotEmpty) {
        stName = nameCandidate.toString().trim();
      }
      stAddr = json['station']['address'] ?? '';
    } else if (json['station'] != null) {
      stId = json['station'].toString();
      stName = 'EV Station #$stId';
    }

    String sId = '';
    if (json['slot'] is Map) {
      sId = json['slot']['_id'] ?? json['slot']['id'] ?? '';
    } else if (json['slot'] != null) {
      sId = json['slot'].toString();
    }

    DateTime created = DateTime.now();
    if (json['createdAt'] != null) {
      created =
          DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    }

    return BookingModel(
      id: json['_id'] ?? json['id'] ?? '',
      stationId: stId,
      stationName: stName,
      stationAddress: stAddr,
      slotId: sId,
      slotDate: json['slotDate'] ?? '',
      slotTime: json['slotTime'] ?? '',
      vehicleType: json['vehicleType'] ?? 'Electric Car',
      batteryCapacity: (json['batteryCapacity'] as num?)?.toDouble() ?? 60.0,
      currentSoc: (json['currentSoc'] as num?)?.toDouble() ?? 20.0,
      desiredSoc: (json['desiredSoc'] as num?)?.toDouble() ?? 80.0,
      energyRequired: (json['energyRequired'] as num?)?.toDouble() ?? 0.0,
      chargingDuration: (json['chargingDuration'] as num?)?.toDouble() ?? 0.0,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      status: json['bookingStatus'] ?? json['status'] ?? 'Confirmed',
      paymentStatus: json['paymentStatus'] ?? 'Pending',
      createdAt: created,
    );
  }
}
