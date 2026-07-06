class SavedPatient {
  final String id;
  final String label;
  final String name;
  final String phone;
  final int age;
  final String gender;
  final String relationship;
  final bool isDefault;
  final Map<String, dynamic>? caseDefaults;

  SavedPatient({
    required this.id,
    required this.label,
    required this.name,
    required this.phone,
    required this.age,
    required this.gender,
    required this.relationship,
    required this.isDefault,
    this.caseDefaults,
  });

  factory SavedPatient.fromJson(Map<String, dynamic> json) {
    return SavedPatient(
      id: json['_id'] ?? '',
      label: json['label'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      age: json['age'] ?? 0,
      gender: json['gender'] ?? 'male',
      relationship: json['relationship'] ?? 'other',
      isDefault: json['isDefault'] ?? false,
      caseDefaults: json['caseDefaults'] is Map<String, dynamic> ? json['caseDefaults'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'label': label,
      'name': name,
      'phone': phone,
      'age': age,
      'gender': gender,
      'relationship': relationship,
      'isDefault': isDefault,
      'caseDefaults': caseDefaults,
    };
  }
}
