import 'package:flutter_test/flutter_test.dart';
import 'package:apk/models/ledger_record.dart';
import 'package:apk/models/line_item.dart';
import 'package:apk/services/language_service.dart';
import 'package:apk/services/ethiopian_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Other Transactions (ሌሎች ግብይቶች) Unit Tests', () {
    test('Translations resolve correctly for otherTransactions and legacy keys', () async {
      await LanguageService.loadTranslations();

      // Test English
      await LanguageService.setLanguage('en');
      expect(LanguageService.t('otherTransactions'), equals('Other Transactions'));
      expect(LanguageService.t('delalaReturnedPaid'), equals('Other Transactions'));
      expect(LanguageService.t('purchaseBoughtGoods'), equals('Other Transactions'));
      expect(LanguageService.t('incomeReceived'), equals('Income / Received (+)'));
      expect(LanguageService.t('expensePaid'), equals('Expense / Paid (-)'));

      // Test Amharic
      await LanguageService.setLanguage('am');
      expect(LanguageService.t('otherTransactions'), equals('ሌሎች ግብይቶች'));
      expect(LanguageService.t('delalaReturnedPaid'), equals('ሌሎች ግብይቶች'));
      expect(LanguageService.t('purchaseBoughtGoods'), equals('ሌሎች ግብይቶች'));
      expect(LanguageService.t('incomeReceived'), equals('ገቢ / ተቀበልን (+)'));
      expect(LanguageService.t('expensePaid'), equals('ወጪ / ከፈልን (-)'));
    });

    test('Other Transactions with positive (+) Income/Received increases debit', () {
      final record = LedgerRecord(
        id: 'rec-test-1',
        type: 'customer',
        title: 'Abebe Customer',
        date: '2026-11-18',
        items: [
          LineItem(
            id: 'item-1',
            name: 'ሌሎች ግብይቶች',
            unitPrice: 500.0,
            quantity: 1.0,
            sign: '+',
            customType: 'Other Transactions',
          ),
        ],
      );

      expect(record.totalDebit, equals(500.0));
      expect(record.totalCredit, equals(0.0));
      expect(record.balance, equals(500.0));
    });

    test('Other Transactions with negative (-) Expense/Paid increases credit', () {
      final record = LedgerRecord(
        id: 'rec-test-2',
        type: 'customer',
        title: 'Abebe Customer',
        date: '2026-11-18',
        items: [
          LineItem(
            id: 'item-1',
            name: 'ሌሎች ግብይቶች',
            unitPrice: 350.0,
            quantity: 1.0,
            sign: '-',
            customType: 'Other Transactions',
          ),
        ],
      );

      expect(record.totalDebit, equals(0.0));
      expect(record.totalCredit, equals(350.0));
      expect(record.balance, equals(-350.0));
    });

    test('Preserves existing records with legacy transaction names', () {
      final record = LedgerRecord(
        id: 'rec-test-3',
        type: 'delala',
        title: 'Kebede Delala',
        date: '2026-11-18',
        items: [
          LineItem(
            id: 'item-leg-1',
            name: 'ደላላ መለሰ / ከፈለ (-)',
            unitPrice: 1200.0,
            quantity: 1.0,
            sign: '-',
          ),
          LineItem(
            id: 'item-leg-2',
            name: 'ግዢ (+) ዕቃ ተቀበልን',
            unitPrice: 2000.0,
            quantity: 1.0,
            sign: '+',
          ),
        ],
      );

      expect(record.totalDebit, equals(2000.0));
      expect(record.totalCredit, equals(1200.0));
      expect(record.balance, equals(800.0));
    });

    test('Ethiopian Amharic calendar formats with Arabic numerals and converts Ge\'ez numerals', () {
      // Test geezToArabic
      expect(EthiopianCalendar.geezToArabic('መስከረም ፪, ፪ሺ፲፯'), contains('2'));
      expect(EthiopianCalendar.geezToArabic('ጥቅምት ፲፭, ፳፻፲፯'), contains('15'));
      expect(EthiopianCalendar.geezToArabic('ጥር ፴'), equals('ጥር 30'));

      // Test formatAnyDate
      final formatted = EthiopianCalendar.formatAnyDate('2024-09-11', lang: 'am');
      expect(formatted, contains('መስከረም 1, 2017'));

      // Test ISO timestamp string
      final isoFormatted = EthiopianCalendar.formatAnyDate('2024-09-11T10:30:00Z', lang: 'am');
      expect(isoFormatted, contains('መስከረም 1, 2017'));
    });
  });
}
