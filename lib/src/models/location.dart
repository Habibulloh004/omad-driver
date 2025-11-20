class RegionModel {
  RegionModel({
    required this.id,
    required this.nameUzLat,
    required this.nameUzCyr,
    required this.nameRu,
    this.districts = const <DistrictModel>[],
  });

  factory RegionModel.fromJson(Map<String, dynamic> json) {
    final districtsData = json['districts'];
    List<DistrictModel> districts = const <DistrictModel>[];
    if (districtsData is List) {
      districts = districtsData
          .whereType<Map<String, dynamic>>()
          .map(DistrictModel.fromJson)
          .toList();
    }
    return RegionModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      nameUzLat: (json['name_uz_lat'] ?? json['name_uz_latin'] ?? '')
          .toString(),
      nameUzCyr: (json['name_uz_cyr'] ?? json['name_uz_cyrillic'] ?? '')
          .toString(),
      nameRu: (json['name_ru'] ?? json['name_russian'] ?? '').toString(),
      districts: districts,
    );
  }

  final int id;
  final String nameUzLat;
  final String nameUzCyr;
  final String nameRu;
  final List<DistrictModel> districts;

  RegionModel copyWith({List<DistrictModel>? districts}) {
    return RegionModel(
      id: id,
      nameUzLat: nameUzLat,
      nameUzCyr: nameUzCyr,
      nameRu: nameRu,
      districts: districts ?? this.districts,
    );
  }
}

class DistrictModel {
  DistrictModel({
    required this.id,
    required this.regionId,
    required this.nameUzLat,
    required this.nameUzCyr,
    required this.nameRu,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      regionId: json['region_id'] is int
          ? json['region_id'] as int
          : int.tryParse('${json['region_id']}') ?? 0,
      nameUzLat: (json['name_uz_lat'] ?? json['name_uz_latin'] ?? '')
          .toString(),
      nameUzCyr: (json['name_uz_cyr'] ?? json['name_uz_cyrillic'] ?? '')
          .toString(),
      nameRu: (json['name_ru'] ?? json['name_russian'] ?? '').toString(),
    );
  }

  final int id;
  final int regionId;
  final String nameUzLat;
  final String nameUzCyr;
  final String nameRu;
}

class PickupLocation {
  const PickupLocation({
    required this.latitude,
    required this.longitude,
    this.address = '',
  });

  final double latitude;
  final double longitude;
  final String address;

  bool get hasAddress => address.trim().isNotEmpty;

  PickupLocation copyWith({
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return PickupLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }
}
