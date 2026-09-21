/// Arabic labels for the `relationship` enum stored on SavedPatient
/// (backend enum: self | spouse | parent | child | sibling | other).
///
/// Keep this as the single source of truth — screens used to print the
/// patient's free-text `label` instead, which showed things like "test"
/// where the relationship belonged.
String relationshipLabelAr(String? relationship) {
  switch (relationship) {
    case 'self':
      return 'أنا';
    case 'spouse':
      return 'الزوج / الزوجة';
    case 'parent':
      return 'الأب / الأم';
    case 'child':
      return 'الابن / الابنة';
    case 'sibling':
      return 'الأخ / الأخت';
    default:
      return 'قريب / آخر';
  }
}

/// Options for relationship dropdowns, in a sensible display order.
const List<MapEntry<String, String>> relationshipOptions = [
  MapEntry('spouse', 'الزوج / الزوجة'),
  MapEntry('parent', 'الأب / الأم'),
  MapEntry('child', 'الابن / الابنة'),
  MapEntry('sibling', 'الأخ / الأخت'),
  MapEntry('other', 'قريب / آخر'),
];
