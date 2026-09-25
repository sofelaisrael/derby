import 'dart:io';
import 'dart:ui';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bin_schedule.dart';
import '../services/bin_scheme.dart';
import '../services/schedule_service.dart';

class CalendarExportService {
  static Future<bool> exportCollections({
    required AreaSchedule area,
    required String councilSlug,
    required String councilName,
    required String postcode,
    String? addressLabel,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final safePostcode =
          postcode.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final label = addressLabel ?? '$councilName $postcode';

      final days = getNextCollectionDays(area, 12, DateTime.now());
      final buffer = StringBuffer();
      final nowStr = _formatDate(DateTime.now().toUtc());

      buffer.writeAll([
        'BEGIN:VCALENDAR\r\n',
        'VERSION:2.0\r\n',
        'PRODID:-//Derby Bins//EN\r\n',
        'CALSCALE:GREGORIAN\r\n',
      ]);

      var id = 0;
      for (final day in days) {
        for (final collection in day.collections) {
          final binLabel =
              CouncilScheme.resolve(councilSlug, collection.stream).label;
          final dtStart = _formatDate(
              DateTime(day.date.year, day.date.month, day.date.day, 7));
          final dtEnd = _formatDate(
              DateTime(day.date.year, day.date.month, day.date.day, 7, 30));
          buffer.writeAll([
            'BEGIN:VEVENT\r\n',
            'DTSTART;VALUE=DATE-TIME:$dtStart\r\n',
            'DTEND;VALUE=DATE-TIME:$dtEnd\r\n',
            'DTSTAMP:$nowStr\r\n',
            'UID:derby-bins-$safePostcode-${id++}@derbybins.app\r\n',
            'SUMMARY:$binLabel bin collection - $label\r\n',
            'DESCRIPTION:$binLabel bin - ${frequencyLabel[collection.schedule.frequency]} collection\r\n',
            'LOCATION:$label\r\n',
            'END:VEVENT\r\n',
          ]);
        }
      }

      buffer.writeln('END:VCALENDAR');

      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/derby_bins_${safePostcode}_$councilSlug.ics');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/calendar')],
        text: 'My bin collection schedule for $label',
        subject: 'My bin collection schedule for $label',
        sharePositionOrigin: sharePositionOrigin,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the device calendar pre-filled with the next collection day.
  /// Returns true when the user saved the event, false on cancel/denial.
  static Future<bool> addNextCollectionToCalendar({
    required AreaSchedule area,
    required String councilName,
    required String postcode,
    String? addressLabel,
    String councilSlug = 'derby',
  }) async {
    try {
      final label = addressLabel ?? '$councilName $postcode';
      final days = getNextCollectionDays(area, 1, DateTime.now());
      if (days.isEmpty) return false;
      final day = days.first;
      final bins = day.collections
          .map((c) => CouncilScheme.resolve(councilSlug, c.stream).label)
          .join(', ');
      final start = DateTime(day.date.year, day.date.month, day.date.day, 7);
      final event = Event(
        title: '$bins bin collection - $label',
        description: '$bins bin - upcoming collection for $label',
        location: label,
        startDate: start,
        endDate: start.add(const Duration(minutes: 30)),
        timeZone: 'Europe/London',
        allDay: false,
      );
      return await Add2Calendar.addEvent2Cal(event);
    } catch (_) {
      return false;
    }
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}T${_pad(dt.hour)}${_pad(dt.minute)}${_pad(dt.second)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
