// Ethiopian Calendar & Gregorian Date Converter for Flutter / Dart
// Matches src/lib/ethiopianCalendar.ts algorithm exactly.

class EthiopianDate {
  final int year;
  final int month;
  final int day;

  const EthiopianDate({
    required this.year,
    required this.month,
    required this.day,
  });

  @override
  String toString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class GregorianDate {
  final int year;
  final int month;
  final int day;

  const GregorianDate({
    required this.year,
    required this.month,
    required this.day,
  });

  @override
  String toString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class EthiopianCalendar {
  static const List<String> monthsAm = [
    '',
    'መስከረም',
    'ጥቅምት',
    'ኅዳር',
    'ታኅሣሥ',
    'ጥር',
    'የካቲት',
    'መጋቢት',
    'ሚያዝያ',
    'ግንቦት',
    'ሰኔ',
    'ሐምሌ',
    'ነሐሴ',
    'ጳጉሜን',
  ];

  static const List<String> monthsEn = [
    '',
    'Meskerem',
    'Tikimt',
    'Hidar',
    'Tahsas',
    'Tir',
    'Yakatit',
    'Megabit',
    'Miazia',
    'Ginbot',
    'Sene',
    'Hamle',
    'Nehase',
    'Pagume',
  ];

  static const int anchorEthYear = 2017;
  static const int anchorUnixDay = 19977;

  static bool isLeapYear(int year) {
    return ((year % 4) + 4) % 4 == 3;
  }

  static int getDaysInMonth(int year, int month) {
    if (month < 1 || month > 13) return 30;
    if (month == 13) {
      return isLeapYear(year) ? 6 : 5;
    }
    return 30;
  }

  static int _ethiopianNewYearUnixDay(int ethYear) {
    if (ethYear == anchorEthYear) return anchorUnixDay;

    if (ethYear > anchorEthYear) {
      int days = (ethYear - anchorEthYear) * 365;
      for (int y = anchorEthYear; y < ethYear; y++) {
        if (isLeapYear(y)) days += 1;
      }
      return anchorUnixDay + days;
    } else {
      int days = (anchorEthYear - ethYear) * 365;
      for (int y = ethYear; y < anchorEthYear; y++) {
        if (isLeapYear(y)) days += 1;
      }
      return anchorUnixDay - days;
    }
  }

  static int _gregorianToUnixDay(int year, int month, int day) {
    final utc = DateTime.utc(year, month, day);
    return utc.millisecondsSinceEpoch ~/ 86400000;
  }

  static GregorianDate _unixDayToGregorian(int unixDay) {
    final d = DateTime.fromMillisecondsSinceEpoch(unixDay * 86400000, isUtc: true);
    return GregorianDate(year: d.year, month: d.month, day: d.day);
  }

  static GregorianDate toGregorian(int ethYear, int ethMonth, int ethDay) {
    final clampedMonth = ethMonth.clamp(1, 13);
    final maxDay = getDaysInMonth(ethYear, clampedMonth);
    final clampedDay = ethDay.clamp(1, maxDay);

    final newYearUnixDay = _ethiopianNewYearUnixDay(ethYear);
    final dayInYear = (clampedMonth - 1) * 30 + (clampedDay - 1);
    final targetUnixDay = newYearUnixDay + dayInYear;
    return _unixDayToGregorian(targetUnixDay);
  }

  static EthiopianDate toEthiopian(int gYear, int gMonth, int gDay) {
    final targetUnixDay = _gregorianToUnixDay(gYear, gMonth, gDay);

    int ethYear = gYear - 8;
    while (_ethiopianNewYearUnixDay(ethYear + 1) <= targetUnixDay) {
      ethYear++;
    }
    while (_ethiopianNewYearUnixDay(ethYear) > targetUnixDay) {
      ethYear--;
    }

    final daysIntoYear = targetUnixDay - _ethiopianNewYearUnixDay(ethYear);
    final ethMonth = (daysIntoYear ~/ 30) + 1;
    final ethDay = (daysIntoYear % 30) + 1;

    return EthiopianDate(year: ethYear, month: ethMonth, day: ethDay);
  }

  static String formatDisplay(EthiopianDate eth, {String lang = 'am'}) {
    final monthName = lang == 'am'
        ? (eth.month <= 13 ? monthsAm[eth.month] : 'ወር ${eth.month}')
        : (eth.month <= 13 ? monthsEn[eth.month] : 'Month ${eth.month}');
    return '$monthName ${eth.day}, ${eth.year}';
  }

  /// Returns current date in authentic Ethiopian calendar
  static EthiopianDate now() {
    final dt = DateTime.now();
    return toEthiopian(dt.year, dt.month, dt.day);
  }

  /// Formats current date in Ethiopian calendar
  static String nowDisplay({String lang = 'am'}) {
    return formatDisplay(now(), lang: lang);
  }

  /// Converts any Ge'ez numeral sequence (፩, ፪, ፫, ፲, etc.) to standard Arabic numbers
  static String geezToArabic(String text) {
    if (!text.contains(RegExp(r'[\u1369-\u137C]'))) return text;

    final Map<String, int> geezMap = {
      '፩': 1, '፪': 2, '፫': 3, '፬': 4, '፭': 5,
      '፮': 6, '፯': 7, '፰': 8, '፱': 9, '፲': 10,
      '፳': 20, '፴': 30, '፵': 40, '፶': 50, '፷': 60,
      '፸': 70, '፹': 80, '፺': 90, '፻': 100, '፼': 10000,
    };

    return text.replaceAllMapped(RegExp(r'[\u1369-\u137C]+'), (match) {
      final geezSeq = match.group(0)!;
      int total = 0;
      int current = 0;
      for (int i = 0; i < geezSeq.length; i++) {
        final ch = geezSeq[i];
        final val = geezMap[ch] ?? 0;
        if (val == 100) {
          total += (current == 0 ? 1 : current) * 100;
          current = 0;
        } else if (val == 10000) {
          total += (current == 0 ? 1 : current) * 10000;
          current = 0;
        } else {
          current += val;
        }
      }
      total += current;
      return total.toString();
    });
  }

  /// Converts any Gregorian, ISO, or Ge'ez date string into an authentic Amharic Ethiopian date string
  static String formatAnyDate(String rawDate, {String lang = 'am'}) {
    if (rawDate.trim().isEmpty) return '';
    try {
      final cleaned = geezToArabic(rawDate.trim());
      for (final m in monthsAm) {
        if (m.isNotEmpty && cleaned.contains(m)) return cleaned;
      }
      for (final m in monthsEn) {
        if (m.isNotEmpty && cleaned.contains(m)) return cleaned;
      }

      final dateOnly = cleaned.split(RegExp(r'[T\s]'))[0];
      final parts = dateOnly.split(RegExp(r'[-/]'));
      if (parts.length == 3) {
        final p0 = int.tryParse(parts[0]);
        final p1 = int.tryParse(parts[1]);
        final p2 = int.tryParse(parts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          if (p0 > 1900 && p0 <= 2100) {
            final eth = toEthiopian(p0, p1, p2);
            return formatDisplay(eth, lang: lang);
          }
          if (p2 > 1900 && p2 <= 2100) {
            final eth = toEthiopian(p2, p1, p0);
            return formatDisplay(eth, lang: lang);
          }
        }
      }

      final dt = DateTime.tryParse(cleaned);
      if (dt != null) {
        final eth = toEthiopian(dt.year, dt.month, dt.day);
        return formatDisplay(eth, lang: lang);
      }
      return cleaned;
    } catch (_) {}
    return rawDate;
  }
}

