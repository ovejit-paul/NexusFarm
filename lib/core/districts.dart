/// The 64 districts of Bangladesh, in their current official spellings.
///
/// District is what groups outbreak reports, so it has to be chosen from
/// a list rather than typed. Typed, one farmer writes "Bogra", another
/// "Bogura", a third "Bagura" — and a real outbreak split three ways
/// never reaches the alert threshold at all.
///
/// The backend keeps the same list in backend/districts.py. Change both
/// together.
library;

class District {
  final String name;
  final String division;

  const District(this.name, this.division);
}

const districts = <District>[
  // Dhaka
  District('Dhaka', 'Dhaka'),
  District('Faridpur', 'Dhaka'),
  District('Gazipur', 'Dhaka'),
  District('Gopalganj', 'Dhaka'),
  District('Kishoreganj', 'Dhaka'),
  District('Madaripur', 'Dhaka'),
  District('Manikganj', 'Dhaka'),
  District('Munshiganj', 'Dhaka'),
  District('Narayanganj', 'Dhaka'),
  District('Narsingdi', 'Dhaka'),
  District('Rajbari', 'Dhaka'),
  District('Shariatpur', 'Dhaka'),
  District('Tangail', 'Dhaka'),
  // Chattogram
  District('Bandarban', 'Chattogram'),
  District('Brahmanbaria', 'Chattogram'),
  District('Chandpur', 'Chattogram'),
  District('Chattogram', 'Chattogram'),
  District("Cox's Bazar", 'Chattogram'),
  District('Cumilla', 'Chattogram'),
  District('Feni', 'Chattogram'),
  District('Khagrachhari', 'Chattogram'),
  District('Lakshmipur', 'Chattogram'),
  District('Noakhali', 'Chattogram'),
  District('Rangamati', 'Chattogram'),
  // Rajshahi
  District('Bogura', 'Rajshahi'),
  District('Chapai Nawabganj', 'Rajshahi'),
  District('Joypurhat', 'Rajshahi'),
  District('Naogaon', 'Rajshahi'),
  District('Natore', 'Rajshahi'),
  District('Pabna', 'Rajshahi'),
  District('Rajshahi', 'Rajshahi'),
  District('Sirajganj', 'Rajshahi'),
  // Khulna
  District('Bagerhat', 'Khulna'),
  District('Chuadanga', 'Khulna'),
  District('Jashore', 'Khulna'),
  District('Jhenaidah', 'Khulna'),
  District('Khulna', 'Khulna'),
  District('Kushtia', 'Khulna'),
  District('Magura', 'Khulna'),
  District('Meherpur', 'Khulna'),
  District('Narail', 'Khulna'),
  District('Satkhira', 'Khulna'),
  // Barishal
  District('Barguna', 'Barishal'),
  District('Barishal', 'Barishal'),
  District('Bhola', 'Barishal'),
  District('Jhalokati', 'Barishal'),
  District('Patuakhali', 'Barishal'),
  District('Pirojpur', 'Barishal'),
  // Sylhet
  District('Habiganj', 'Sylhet'),
  District('Moulvibazar', 'Sylhet'),
  District('Sunamganj', 'Sylhet'),
  District('Sylhet', 'Sylhet'),
  // Rangpur
  District('Dinajpur', 'Rangpur'),
  District('Gaibandha', 'Rangpur'),
  District('Kurigram', 'Rangpur'),
  District('Lalmonirhat', 'Rangpur'),
  District('Nilphamari', 'Rangpur'),
  District('Panchagarh', 'Rangpur'),
  District('Rangpur', 'Rangpur'),
  District('Thakurgaon', 'Rangpur'),
  // Mymensingh
  District('Jamalpur', 'Mymensingh'),
  District('Mymensingh', 'Mymensingh'),
  District('Netrokona', 'Mymensingh'),
  District('Sherpur', 'Mymensingh'),
];

/// Old and common alternative spellings, mapped to the official name.
/// Most are the pre-2018 English spellings still printed on older signs
/// and forms. "Savar" is here because early versions of this app used it
/// as a default; it is an upazila of Dhaka district.
const _aliases = <String, String>{
  'bogra': 'Bogura',
  'chittagong': 'Chattogram',
  'comilla': 'Cumilla',
  'barisal': 'Barishal',
  'jessore': 'Jashore',
  'nawabganj': 'Chapai Nawabganj',
  'laxmipur': 'Lakshmipur',
  'maulvibazar': 'Moulvibazar',
  'netrakona': 'Netrokona',
  'jhalakathi': 'Jhalokati',
  'jhalokathi': 'Jhalokati',
  'khagrachari': 'Khagrachhari',
  'narshingdi': 'Narsingdi',
  'hobiganj': 'Habiganj',
  'jhenaidaha': 'Jhenaidah',
  'coxbazar': "Cox's Bazar",
  'savar': 'Dhaka',
};

String _key(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

final Map<String, String> _byKey = {
  for (final d in districts) _key(d.name): d.name,
  ..._aliases,
};

/// The official name for [input], or null if it is not a district.
///
/// Ignores case, spaces and punctuation, and accepts the common old
/// spellings, so "bogra", "BOGURA" and " Bogura " all give "Bogura".
String? normalizeDistrict(String input) => _byKey[_key(input)];

bool isKnownDistrict(String input) => normalizeDistrict(input) != null;

String? divisionOf(String name) {
  for (final d in districts) {
    if (d.name == name) return d.division;
  }
  return null;
}
