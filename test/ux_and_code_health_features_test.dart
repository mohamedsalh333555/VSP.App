import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/utils/vsp_match_invite_formatter.dart';
import 'package:vsp_application/core/utils/vsp_quick_booking_receipt_formatter.dart';
import 'package:vsp_application/core/services/fast_cache_service.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/data/models.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();

 setUpAll(() async {
 await initializeDateFormatting('ar', null);
 await initializeDateFormatting('en', null);
 SharedPreferences.setMockInitialValues({});
 });

 group(' 1. WhatsApp Match Invite Formatter Tests', () {
 test('Builds formatted Arabic match invite with player count and maps link', () {
 final startTime = DateTime(2026, 8, 25, 20, 0); // 8:00 PM
 final endTime = DateTime(2026, 8, 25, 21, 0); // 9:00 PM

 final invite = VSPMatchInviteFormatter.buildInviteMessage(
 stadiumName: 'ملعب النجوم الدولي',
 bookingId: 'bk_test_123',
 startTime: startTime,
 endTime: endTime,
 googleMapsUrl: 'https://maps.google.com/?q=30.0444,31.2357',
 currentPlayers: 7,
 maxPlayers: 10,
 costPerPerson: 50.0,
 totalPrice: 500.0,
 hostName: 'كابتن زياد',
 isArabic: true,
 );

 expect(invite, contains('ملعب النجوم الدولي'));
 expect(invite, contains('كابتن زياد'));
 expect(invite, contains('ناقص 3 لاعيبة'));
 expect(invite, contains('50 ج.م'));
 expect(invite, contains('https://maps.google.com/?q=30.0444,31.2357'));
 expect(invite, contains('https://vsp.app/match/bk_test_123'));
 });

 test('Builds formatted English match invite correctly', () {
 final startTime = DateTime(2026, 8, 25, 18, 0);
 final endTime = DateTime(2026, 8, 25, 19, 0);

 final invite = VSPMatchInviteFormatter.buildInviteMessage(
 stadiumName: 'Camp Nou Arena',
 bookingId: 'bk_eng_456',
 startTime: startTime,
 endTime: endTime,
 currentPlayers: 8,
 maxPlayers: 10,
 costPerPerson: 60.0,
 isArabic: false,
 );

 expect(invite, contains('Camp Nou Arena'));
 expect(invite, contains('2 more players needed'));
 expect(invite, contains('60 EGP'));
 expect(invite, contains('https://vsp.app/match/bk_eng_456'));
 });
 });

 group(' 2. Owner Quick Booking Receipt Formatter Tests', () {
 test('Builds complete Arabic cashier receipt for WhatsApp', () {
 final startTime = DateTime(2026, 8, 25, 21, 0);
 final endTime = DateTime(2026, 8, 25, 22, 0);

 final receipt = VSPQuickBookingReceiptFormatter.buildReceiptMessage(
 stadiumName: 'ستاد الملوك',
 bookingRef: 'BK-9921X',
 customerName: 'كابتن محمد صلاح',
 startTime: startTime,
 endTime: endTime,
 totalPrice: 400.0,
 depositPaid: 100.0,
 googleMapsUrl: 'https://maps.google.com/?q=stadium_loc',
 stadiumPhone: '01000000000',
 isArabic: true,
 );

 expect(receipt, contains('ستاد الملوك'));
 expect(receipt, contains('كابتن محمد صلاح'));
 expect(receipt, contains('400 ج.م'));
 expect(receipt, contains('عربون مسدد: 100 ج.م'));
 expect(receipt, contains('المتبقي: 300 ج.م عند الحضور'));
 expect(receipt, contains('#BK-9921X'));
 expect(receipt, contains('01000000000'));
 expect(receipt, contains('يرجى الحضور قبل الموعد بـ 10 دقائق'));
 });

 test('Handles full payment and zero deposit accurately', () {
 final startTime = DateTime(2026, 8, 25, 20, 0);
 final endTime = DateTime(2026, 8, 25, 21, 0);

 final fullPaid = VSPQuickBookingReceiptFormatter.buildReceiptMessage(
 stadiumName: 'Alpha Pitch',
 bookingRef: 'REF1',
 customerName: 'Captain Tarek',
 startTime: startTime,
 endTime: endTime,
 totalPrice: 300.0,
 depositPaid: 300.0,
 isArabic: false,
 );
 expect(fullPaid, contains('Paid in full '));

 final cashAtPitch = VSPQuickBookingReceiptFormatter.buildReceiptMessage(
 stadiumName: 'Alpha Pitch',
 bookingRef: 'REF2',
 customerName: 'Captain Tarek',
 startTime: startTime,
 endTime: endTime,
 totalPrice: 300.0,
 depositPaid: 0.0,
 isArabic: false,
 );
 expect(cashAtPitch, contains('Cash at pitch: 300 EGP'));
 });
 });

 group(' 3. Fast Offline-First Cache Tests', () {
 test('FastCacheService stores and returns in-memory stadiums instantly', () async {
 final List<Stadium> mockStadiums = [
 Stadium(
 id: 'test_std_1',
 name: 'Fast Stadium 1',
 location: 'Nasr City, Cairo',
 pricePerHour: 350.0,
 imageUrl: 'https://images.unsplash.com/photo-1529900748604-07564a03e7a6',
 rating: 4.8,
 isVerified: true,
 ownerId: 'owner_1',
 openingTime: '04:00 PM',
 closingTime: '02:00 AM',
 type: 'Football',
 size: '5x5',
 baths: 2,
 cafeteria: 1,
 playersPerTeam: 5,
 totalFieldCapacity: 10,
 area: 'Nasr City',
 ),
 ];

 await FastCacheService.cacheStadiums(mockStadiums);

 expect(FastCacheService.hasMemoryCache(), isTrue);
 final cached = FastCacheService.getMemoryStadiumsSync();
 expect(cached.length, equals(1));
 expect(cached.first.name, equals('Fast Stadium 1'));
 });
 });

 group(' 4. Quick Night Shift & No-Deposit Filter Tests', () {
 test('StadiumProvider filters night shift stadiums correctly', () {
 final provider = StadiumProvider();

 expect(provider.activeQuickFilter, isNull);

 provider.toggleQuickFilter('night_shift');
 expect(provider.activeQuickFilter, equals('night_shift'));

 provider.toggleQuickFilter('night_shift');
 expect(provider.activeQuickFilter, isNull);

 provider.toggleQuickFilter('no_deposit');
 expect(provider.activeQuickFilter, equals('no_deposit'));
 });
 });
}
