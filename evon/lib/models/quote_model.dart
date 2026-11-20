class QuoteModel {
  final double energyRequired;
  final double chargingDuration;
  final double estimatedCost;
  final double estimatedWaitTime;
  final String demandLevel;
  final String congestion;

  QuoteModel({
    required this.energyRequired,
    required this.chargingDuration,
    required this.estimatedCost,
    required this.estimatedWaitTime,
    required this.demandLevel,
    required this.congestion,
  });

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    String demand = 'Moderate';
    String cong = 'Low';

    if (json['mlDemand'] is Map) {
      demand = json['mlDemand']['demandLevel'] ?? 'Moderate';
    }
    if (json['waitReport'] is Map) {
      cong = json['waitReport']['congestion'] ?? 'Low';
    }

    return QuoteModel(
      energyRequired: (json['energyRequired'] as num?)?.toDouble() ?? 0.0,
      chargingDuration: (json['chargingDuration'] as num?)?.toDouble() ?? 0.0,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      estimatedWaitTime: (json['estimatedWaitTime'] as num?)?.toDouble() ?? 0.0,
      demandLevel: demand,
      congestion: cong,
    );
  }
}
