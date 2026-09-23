import '../../core/dates.dart';

enum Species { cattle, goat, chicken, duck }

extension SpeciesInfo on Species {
  String get label => switch (this) {
        Species.cattle => 'Cattle',
        Species.goat => 'Goat',
        Species.chicken => 'Chicken',
        Species.duck => 'Duck',
      };

  String get emoji => switch (this) {
        Species.cattle => '🐄',
        Species.goat => '🐐',
        Species.chicken => '🐔',
        Species.duck => '🦆',
      };

  /// Poultry are counted as flocks — nobody names forty hens. Cattle and
  /// goats are tracked one by one, because milk, treatment and sale all
  /// happen per animal.
  bool get keptAsFlock => this == Species.chicken || this == Species.duck;

  /// The everyday product a withdrawal period can block.
  Product get dailyProduct => keptAsFlock ? Product.eggs : Product.milk;

  String get producingLabel => keptAsFlock ? 'Laying' : 'Milking';

  String get dateLabel => keptAsFlock ? 'Hatch date' : 'Date of birth';
}

enum Product { milk, eggs, meat }

extension ProductInfo on Product {
  String get label => switch (this) {
        Product.milk => 'Milk',
        Product.eggs => 'Eggs',
        Product.meat => 'Meat',
      };

  String get unit => switch (this) {
        Product.milk => 'L',
        Product.eggs => 'eggs',
        Product.meat => 'kg',
      };

  /// What the farmer must not do while a withdrawal period runs.
  String holdAction(String animalName) => switch (this) {
        Product.milk => 'Do not sell or drink milk from $animalName',
        Product.eggs => 'Do not sell or eat eggs from $animalName',
        Product.meat => 'Do not slaughter or sell $animalName for meat',
      };
}

/// One animal, or one flock of birds.
class Animal {
  final String id;
  final Species species;
  final String name;

  /// 1 for an individual animal; the number of birds for a flock.
  final int headCount;

  final DateTime? birthDate;

  /// Milking or laying now.
  final bool producing;

  final String notes;
  final DateTime createdAt;

  const Animal({
    required this.id,
    required this.species,
    required this.name,
    this.headCount = 1,
    this.birthDate,
    this.producing = false,
    this.notes = '',
    required this.createdAt,
  });

  bool get isFlock => species.keptAsFlock;

  Animal copyWith({
    String? name,
    int? headCount,
    DateTime? birthDate,
    bool clearBirthDate = false,
    bool? producing,
    String? notes,
  }) =>
      Animal(
        id: id,
        species: species,
        name: name ?? this.name,
        headCount: headCount ?? this.headCount,
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        producing: producing ?? this.producing,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'species': species.name,
        'name': name,
        'headCount': headCount,
        'birthDate': birthDate == null ? null : isoDay(birthDate!),
        'producing': producing,
        'notes': notes,
        'createdAt': isoDay(createdAt),
      };

  factory Animal.fromJson(Map<String, dynamic> j) => Animal(
        id: j['id'] as String,
        species: Species.values.byName(j['species'] as String),
        name: j['name'] as String,
        headCount: (j['headCount'] as num?)?.toInt() ?? 1,
        birthDate: j['birthDate'] == null
            ? null
            : parseDay(j['birthDate'] as String),
        producing: j['producing'] as bool? ?? false,
        notes: j['notes'] as String? ?? '',
        createdAt: parseDay(j['createdAt'] as String),
      );
}

enum HealthEventType { vaccination, treatment, deworming }

extension HealthEventTypeInfo on HealthEventType {
  String get label => switch (this) {
        HealthEventType.vaccination => 'Vaccination',
        HealthEventType.treatment => 'Treatment',
        HealthEventType.deworming => 'Deworming',
      };
}

/// A vaccination, treatment or deworming, with its withdrawal periods.
///
/// Withdrawal periods come from the product label: the days after
/// administration before milk, eggs or meat are safe for people. The
/// same principle as the pre-harvest interval on crops.
class HealthEvent {
  final String id;
  final String animalId;
  final HealthEventType type;
  final String name;
  final DateTime date;
  final int milkWithdrawalDays;
  final int eggWithdrawalDays;
  final int meatWithdrawalDays;
  final double cost;
  final String notes;

  const HealthEvent({
    required this.id,
    required this.animalId,
    required this.type,
    required this.name,
    required this.date,
    this.milkWithdrawalDays = 0,
    this.eggWithdrawalDays = 0,
    this.meatWithdrawalDays = 0,
    this.cost = 0,
    this.notes = '',
  });

  int withdrawalDaysFor(Product p) => switch (p) {
        Product.milk => milkWithdrawalDays,
        Product.eggs => eggWithdrawalDays,
        Product.meat => meatWithdrawalDays,
      };

  /// First day the product is safe again, or null if no withdrawal applies.
  DateTime? safeFrom(Product p) {
    final days = withdrawalDaysFor(p);
    return days > 0 ? addDays(date, days) : null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'animalId': animalId,
        'type': type.name,
        'name': name,
        'date': isoDay(date),
        'milkWithdrawalDays': milkWithdrawalDays,
        'eggWithdrawalDays': eggWithdrawalDays,
        'meatWithdrawalDays': meatWithdrawalDays,
        'cost': cost,
        'notes': notes,
      };

  factory HealthEvent.fromJson(Map<String, dynamic> j) => HealthEvent(
        id: j['id'] as String,
        animalId: j['animalId'] as String,
        type: HealthEventType.values.byName(j['type'] as String),
        name: j['name'] as String,
        date: parseDay(j['date'] as String),
        milkWithdrawalDays: (j['milkWithdrawalDays'] as num?)?.toInt() ?? 0,
        eggWithdrawalDays: (j['eggWithdrawalDays'] as num?)?.toInt() ?? 0,
        meatWithdrawalDays: (j['meatWithdrawalDays'] as num?)?.toInt() ?? 0,
        cost: (j['cost'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String? ?? '',
      );
}

/// A day's milk or eggs from one animal or flock.
class ProductionLog {
  final String id;
  final String animalId;
  final DateTime date;
  final Product product;
  final double quantity;

  /// True when collected during a withdrawal period — recorded so the
  /// numbers stay honest, but never counted as usable.
  final bool discarded;

  const ProductionLog({
    required this.id,
    required this.animalId,
    required this.date,
    required this.product,
    required this.quantity,
    this.discarded = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'animalId': animalId,
        'date': isoDay(date),
        'product': product.name,
        'quantity': quantity,
        'discarded': discarded,
      };

  factory ProductionLog.fromJson(Map<String, dynamic> j) => ProductionLog(
        id: j['id'] as String,
        animalId: j['animalId'] as String,
        date: parseDay(j['date'] as String),
        product: Product.values.byName(j['product'] as String),
        quantity: (j['quantity'] as num).toDouble(),
        discarded: j['discarded'] as bool? ?? false,
      );
}
