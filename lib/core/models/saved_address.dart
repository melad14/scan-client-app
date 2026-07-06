class SavedAddress {
  final String id;
  final String label;
  final String icon;
  final String governorate;
  final String district;
  final String street;
  final String building;
  final String houseNumber;
  final String road;
  final String neighbourhood;
  final String suburb;
  final String city;
  final String postcode;
  final String country;
  final String countryCode;
  final int? floor;
  final bool hasElevator;
  final double? lat;
  final double? lng;
  final bool isDefault;

  SavedAddress({
    required this.id,
    required this.label,
    required this.icon,
    required this.governorate,
    required this.district,
    required this.street,
    required this.building,
    this.houseNumber = '',
    this.road = '',
    this.neighbourhood = '',
    this.suburb = '',
    this.city = '',
    this.postcode = '',
    this.country = 'مصر',
    this.countryCode = 'eg',
    this.floor,
    this.hasElevator = false,
    this.lat,
    this.lng,
    required this.isDefault,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates']?['coordinates'];
    return SavedAddress(
      id: json['_id'] ?? '',
      label: json['label'] ?? '',
      icon: json['icon'] ?? 'home',
      governorate: json['governorate'] ?? '',
      district: json['district'] ?? '',
      street: json['street'] ?? '',
      building: json['building'] ?? '',
      houseNumber: json['houseNumber'] ?? '',
      road: json['road'] ?? '',
      neighbourhood: json['neighbourhood'] ?? '',
      suburb: json['suburb'] ?? '',
      city: json['city'] ?? '',
      postcode: json['postcode'] ?? '',
      country: json['country'] ?? 'مصر',
      countryCode: json['countryCode'] ?? 'eg',
      floor: json['floor'] != null ? (json['floor'] as num).toInt() : null,
      hasElevator: json['hasElevator'] ?? false,
      lat: coords != null && coords.length > 1 ? (coords[1] as num).toDouble() : null,
      lng: coords != null && coords.length > 0 ? (coords[0] as num).toDouble() : null,
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'label': label,
      'icon': icon,
      'governorate': governorate,
      'district': district,
      'street': street,
      'building': building,
      'houseNumber': houseNumber,
      'road': road,
      'neighbourhood': neighbourhood,
      'suburb': suburb,
      'city': city,
      'postcode': postcode,
      'country': country,
      'countryCode': countryCode,
      'floor': floor,
      'hasElevator': hasElevator,
      'isDefault': isDefault,
      if (lat != null && lng != null)
        'coordinates': {
          'type': 'Point',
          'coordinates': [lng, lat]
        }
    };
  }

  String get shortAddress {
    String addr = district;
    if (street.isNotEmpty) addr += '، $street';
    if (building.isNotEmpty) addr += '، $building';
    return addr;
  }
}
