/// Model satu meteran listrik (meter) yang dipantau WattCast.
///
/// Satu aplikasi dapat memantau banyak meteran sekaligus; setiap
/// meteran memiliki [name], [number] (nomor meter), dan kumpulan
/// pencatatan log tersendiri.
class Meter {
  const Meter({
    this.id,
    required this.name,
    this.number = '',
    required this.createdAt,
  });

  final int? id;
  final String name;

  /// Nomor meteran listrik, misalnya nomor dari kontrak/plang meter.
  final String number;

  final DateTime createdAt;

  Meter copyWith({int? id, String? name, String? number}) {
    return Meter(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'name': name,
        'number': number,
        'created_at': createdAt.toIso8601String(),
      };

  factory Meter.fromMap(Map<String, dynamic> map) => Meter(
        id: map['id'] as int?,
        name: map['name'] as String,
        number: (map['number'] as String?) ?? '',
        createdAt:
            DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}