import 'package:flutter/material.dart';

/// Types of waste streams for Derbyshire councils.
enum WasteStream {
  general('General Waste', Icons.delete_outline, Color(0xFF6B7280)),
  recycling('Recycling', Icons.recycling, Color(0xFF2563EB)),
  garden('Garden Waste', Icons.yard, Color(0xFF16A34A)),
  food('Food Waste', Icons.set_meal, Color(0xFFF59E0B));

  final String displayName;
  final IconData icon;
  final Color color;

  const WasteStream(this.displayName, this.icon, this.color);

  static WasteStream fromString(String value) {
    return WasteStream.values.firstWhere(
      (w) => w.name.toLowerCase() == value.toLowerCase(),
      orElse: () => WasteStream.general,
    );
  }
}

/// Collection frequency.
enum Frequency {
  weekly,
  fortnightly,
  everyFourWeeks,
  monthly;

  static Frequency fromString(String value) {
    switch (value.toLowerCase()) {
      case 'weekly':
        return Frequency.weekly;
      case 'fortnightly':
      case 'bi-weekly':
        return Frequency.fortnightly;
      case 'every 4 weeks':
      case 'four-weekly':
        return Frequency.everyFourWeeks;
      case 'monthly':
        return Frequency.monthly;
      default:
        return Frequency.fortnightly;
    }
  }

  String get shortLabel {
    switch (this) {
      case Frequency.weekly:
        return 'Weekly';
      case Frequency.fortnightly:
        return 'Fortnightly';
      case Frequency.everyFourWeeks:
        return 'Every 4 weeks';
      case Frequency.monthly:
        return 'Monthly';
    }
  }
}

/// A single bin collection day with its waste streams.
class BinCollection {
  final DateTime date;
  final List<WasteStream> wasteStreams;
  final Frequency frequency;

  const BinCollection({
    required this.date,
    required this.wasteStreams,
    required this.frequency,
  });

  factory BinCollection.fromJson(Map<String, dynamic> json) {
    return BinCollection(
      date: DateTime.parse(json['date']),
      wasteStreams: (json['wasteStreams'] as List)
          .map((w) => WasteStream.fromString(w.toString()))
          .toList(),
      frequency: Frequency.fromString(json['frequency'] ?? 'fortnightly'),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'wasteStreams': wasteStreams.map((w) => w.name).toList(),
        'frequency': frequency.name,
      };

  /// Days until this collection.
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final collectionDay = DateTime(date.year, date.month, date.day);
    return collectionDay.difference(today).inDays;
  }

  /// Is this collection today?
  bool get isToday => daysUntil == 0;

  /// Is this collection tomorrow?
  bool get isTomorrow => daysUntil == 1;

  /// Is this collection in the past?
  bool get isPast => daysUntil < 0;
}

/// A collection schedule for a specific address.
class CollectionSchedule {
  final String uprn;
  final String address;
  final String council;
  final List<BinCollection> collections;
  final DateTime lastUpdated;

  const CollectionSchedule({
    required this.uprn,
    required this.address,
    required this.council,
    required this.collections,
    required this.lastUpdated,
  });

  factory CollectionSchedule.fromJson(Map<String, dynamic> json) {
    return CollectionSchedule(
      uprn: json['uprn'] ?? '',
      address: json['address'] ?? '',
      council: json['council'] ?? '',
      collections: (json['collections'] as List? ?? [])
          .map((c) => BinCollection.fromJson(c))
          .toList(),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uprn': uprn,
        'address': address,
        'council': council,
        'collections': collections.map((c) => c.toJson()).toList(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  /// Get upcoming (non-past) collections sorted by date.
  List<BinCollection> get upcomingCollections =>
      collections.where((c) => !c.isPast).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  /// Get today's collection, if any.
  BinCollection? get todayCollection {
    for (final c in collections) {
      if (c.isToday) return c;
    }
    return null;
  }

  /// Get the next collection after today.
  BinCollection? get nextCollection {
    final upcoming = upcomingCollections;
    if (upcoming.isEmpty) return null;
    return upcoming.first;
  }

  /// Get the next N collections.
  List<BinCollection> nextCollections(int count) =>
      upcomingCollections.take(count).toList();
}
