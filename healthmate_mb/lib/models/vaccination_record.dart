class VaccinationRecord {
  final String vaccineId;
  final DateTime date;
  final String notes;

  const VaccinationRecord({
    required this.vaccineId,
    required this.date,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'vaccineId': vaccineId,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory VaccinationRecord.fromMap(Map<String, dynamic> map) {
    return VaccinationRecord(
      vaccineId: (map['vaccineId'] ?? map['id'] ?? '').toString(),
      date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}
