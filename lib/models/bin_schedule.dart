/// Domain models for the bin collection schedule app.
/// Ported from React Native binSchedule.ts.

enum WasteStream { general, recycling, garden, food }

enum Frequency {
  weekly,
  fortnightly,
  threeWeekly,
  fourWeekly,
  sixWeekly,
  eightWeekly,
  twelveWeekly,
}

class BinSchedule {
  final WasteStream stream;

  /// Dart convention: 1 = Monday … 7 = Sunday (RN used 0 = Sunday).
  final int dayOfWeek;
  final Frequency frequency;

  /// ISO date (YYYY-MM-DD) of one known collection, anchoring the phase of
  /// fortnightly / four-weekly rounds so we can project real calendar dates.
  final DateTime anchorDate;

  const BinSchedule({
    required this.stream,
    required this.dayOfWeek,
    required this.frequency,
    required this.anchorDate,
  });

  Map<String, dynamic> toJson() => {
        'stream': stream.name,
        'dayOfWeek': dayOfWeek,
        'frequency': frequency.name,
        'anchorDate': anchorDate.toIso8601String(),
      };

  static BinSchedule fromJson(Map<String, dynamic> json) => BinSchedule(
        stream: WasteStream.values.byName(json['stream'] as String),
        dayOfWeek: json['dayOfWeek'] as int,
        frequency: Frequency.values.byName(json['frequency'] as String),
        anchorDate: DateTime.parse(json['anchorDate'] as String),
      );
}

class AreaSchedule {
  final String postcode;
  final String areaName;
  final String council;
  final List<BinSchedule> schedules;

  const AreaSchedule({
    required this.postcode,
    required this.areaName,
    required this.council,
    required this.schedules,
  });

  Map<String, dynamic> toJson() => {
        'postcode': postcode,
        'areaName': areaName,
        'council': council,
        'schedules': schedules.map((s) => s.toJson()).toList(),
      };

  static AreaSchedule fromJson(Map<String, dynamic> json) => AreaSchedule(
        postcode: json['postcode'] as String,
        areaName: json['areaName'] as String,
        council: json['council'] as String,
        schedules: (json['schedules'] as List)
            .map((s) => BinSchedule.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class BinCollection {
  final DateTime date;
  final BinSchedule schedule;

  const BinCollection({
    required this.date,
    required this.schedule,
  });

  /// The waste stream for this collection, delegating to its schedule.
  WasteStream get stream => schedule.stream;
}

/// One calendar day and every bin due on it (1–3 collections).
class CollectionDay {
  final DateTime date;
  final List<BinCollection> collections;

  const CollectionDay({required this.date, required this.collections});
}

const Map<Frequency, String> frequencyLabel = {
  Frequency.weekly: 'Every week',
  Frequency.fortnightly: 'Every 2 weeks',
  Frequency.threeWeekly: 'Every 3 weeks',
  Frequency.fourWeekly: 'Every 4 weeks',
  Frequency.sixWeekly: 'Every 6 weeks',
  Frequency.eightWeekly: 'Every 8 weeks',
  Frequency.twelveWeekly: 'Every 12 weeks',
};

const List<String> weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
