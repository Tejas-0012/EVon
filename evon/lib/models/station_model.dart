class BayModel {
  final int bayNumber;
  final String status; // 'Available', 'Parked', 'Charging', 'Offline'
  final DateTime lastUpdated;

  BayModel({
    required this.bayNumber,
    required this.status,
    required this.lastUpdated,
  });

  bool get isAvailable => status.toLowerCase() == 'available';
  bool get isParked => status.toLowerCase() == 'parked';
  bool get isCharging => status.toLowerCase() == 'charging';
  bool get isOffline => status.toLowerCase() == 'offline';

  factory BayModel.fromJson(Map<String, dynamic> json) {
    return BayModel(
      bayNumber: (json['bayNumber'] as num?)?.toInt() ?? 1,
      status: json['status'] ?? 'Available',
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class StationModel {
  final String id;
  final String stationName;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final String chargerType;
  final double chargerPower;
  final int totalSlots;
  final int availableSlots;
  final int occupiedSlots;
  final String status;
  final double pricePerKwh;
  final int waitMinutes;
  final String congestion;
  final bool isIotHub;
  final bool isIotActive;
  final String iotStatusMessage;
  final List<BayModel> bays;
  final double? distanceKm;
  final String? distanceText;

  StationModel({
    required this.id,
    required this.stationName,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.chargerType,
    required this.chargerPower,
    required this.totalSlots,
    required this.availableSlots,
    required this.occupiedSlots,
    required this.status,
    this.pricePerKwh = 12.0,
    this.waitMinutes = 0,
    this.congestion = 'Low',
    this.isIotHub = false,
    this.isIotActive = false,
    this.iotStatusMessage = 'Not Available',
    this.bays = const [],
    this.distanceKm,
    this.distanceText,
  });

  factory StationModel.fromJson(Map<String, dynamic> json) {
    double lat = 12.9716;
    double lng = 77.5946;

    if (json['latitude'] != null && json['longitude'] != null) {
      lat = (json['latitude'] as num).toDouble();
      lng = (json['longitude'] as num).toDouble();
    } else if (json['location'] != null &&
        json['location']['coordinates'] != null &&
        (json['location']['coordinates'] as List).length >= 2) {
      lng = (json['location']['coordinates'][0] as num).toDouble();
      lat = (json['location']['coordinates'][1] as num).toDouble();
    }

    int waitMins = 0;
    String cong = 'Low';
    if (json['waitTime'] != null) {
      waitMins = (json['waitTime']['estimatedWaitMinutes'] as num?)?.toInt() ?? 0;
      cong = json['waitTime']['congestion'] ?? 'Low';
    }

    final bool isHub = json['isIotHub'] == true ||
        (json['stationName']?.toString().toLowerCase().contains('evon charging hub') ?? false);

    final bool isActive = json['isIotActive'] == true;
    final String statusMsg = json['iotStatusMessage'] ??
        (isActive ? 'Active (Live Synced)' : 'Not Available (ESP32 Offline)');

    List<BayModel> bayList = [];
    if (json['bays'] is List) {
      bayList = (json['bays'] as List).map((b) => BayModel.fromJson(b)).toList();
    } else if (isHub) {
      bayList = [
        BayModel(bayNumber: 1, status: isActive ? 'Available' : 'Offline', lastUpdated: DateTime.now()),
        BayModel(bayNumber: 2, status: isActive ? 'Available' : 'Offline', lastUpdated: DateTime.now()),
      ];
    }

    return StationModel(
      id: json['id'] ?? json['_id'] ?? '',
      stationName: json['stationName'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? 'Bangalore',
      latitude: lat,
      longitude: lng,
      chargerType: json['chargerType'] ?? 'DC Fast',
      chargerPower: (json['chargerPower'] as num?)?.toDouble() ?? 50.0,
      totalSlots: (json['totalSlots'] as num?)?.toInt() ?? 2,
      availableSlots: (json['availableSlots'] as num?)?.toInt() ?? (isActive ? 2 : 0),
      occupiedSlots: (json['occupiedSlots'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'Active',
      pricePerKwh: (json['pricePerKwh'] as num?)?.toDouble() ?? 12.0,
      waitMinutes: waitMins,
      congestion: cong,
      isIotHub: isHub,
      isIotActive: isActive,
      iotStatusMessage: statusMsg,
      bays: bayList,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ??
          (json['distFromOriginKm'] as num?)?.toDouble(),
      distanceText: json['distanceText'] ??
          (json['distanceKm'] != null ? '${(json['distanceKm'] as num).toStringAsFixed(1)} km' : null),
    );
  }
}
