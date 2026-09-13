import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_validator.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_payload_builder.dart';

void main() {
  group('StadiumWizardValidator', () {
    test('validateStep0 returns error if location is empty', () {
      final res = StadiumWizardValidator.validateStep0(
        location: '',
        name: 'Test Field',
        stadiumPhone: '01012345678',
        sportType: 'Football',
        price: '150',
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: false,
        breakTimes: [],
        isArabic: false,
      );
      expect(res, equals('Please select stadium location on map first'));
    });

    test('validateStep0 returns error if name is empty', () {
      final res = StadiumWizardValidator.validateStep0(
        location: 'Cairo, Egypt',
        name: '',
        stadiumPhone: '01012345678',
        sportType: 'Football',
        price: '150',
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: false,
        breakTimes: [],
        isArabic: true,
      );
      expect(res, equals('يرجى إدخال اسم الملعب'));
    });

    test('validateStep0 returns error if sportType is null', () {
      final res = StadiumWizardValidator.validateStep0(
        location: 'Cairo, Egypt',
        name: 'Camp Nou',
        stadiumPhone: '01012345678',
        sportType: null,
        price: '150',
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: false,
        breakTimes: [],
        isArabic: false,
      );
      expect(res, equals('Please select sport type'));
    });

    test('validateStep0 returns null when all inputs are valid', () {
      final res = StadiumWizardValidator.validateStep0(
        location: 'Cairo, Egypt',
        name: 'Camp Nou',
        stadiumPhone: '01012345678',
        sportType: 'Football',
        price: '150',
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: false,
        breakTimes: [],
        isArabic: false,
      );
      expect(res, isNull);
    });

    test('validateStep0 allows empty or null breakTimes when isSplitShift is true (strictly optional)', () {
      final resEmpty = StadiumWizardValidator.validateStep0(
        location: 'Cairo, Egypt',
        name: 'Camp Nou',
        stadiumPhone: '01012345678',
        sportType: 'Football',
        price: '150',
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: true,
        breakTimes: [],
        isArabic: false,
      );
      expect(resEmpty, isNull);

      final resNullBreak = StadiumWizardValidator.validateStep0(
        location: 'Cairo, Egypt',
        name: 'Camp Nou',
        stadiumPhone: '01012345678',
        sportType: 'Football',
        price: '150',
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: true,
        breakTimes: [{'start': null, 'end': null}],
        isArabic: false,
      );
      expect(resNullBreak, isNull);
    });

    test('validateStep0 validates completed breaks and rejects out-of-bounds break', () {
      final resValidBreak = StadiumWizardValidator.validateStep0(
        location: 'Cairo, Egypt',
        name: 'Camp Nou',
        stadiumPhone: '01012345678',
        sportType: 'Football',
        price: '150',
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: true,
        breakTimes: [
          {'start': const TimeOfDay(hour: 18, minute: 0), 'end': const TimeOfDay(hour: 19, minute: 0)}
        ],
        isArabic: false,
      );
      expect(resValidBreak, isNull);

      final resInvalidBreak = StadiumWizardValidator.validateStep0(
        location: 'Cairo, Egypt',
        name: 'Camp Nou',
        stadiumPhone: '01012345678',
        sportType: 'Football',
        price: '150',
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: true,
        breakTimes: [
          {'start': const TimeOfDay(hour: 10, minute: 0), 'end': const TimeOfDay(hour: 11, minute: 0)}
        ],
        isArabic: true,
      );
      expect(resInvalidBreak, contains('فترة الراحة 1 يجب أن تكون داخل مواعيد العمل الرسمية'));
    });

    test('validateStep1 checks features and deposit limits', () {
      final nullFeatures = StadiumWizardValidator.validateStep1(
        selectedBathOption: null,
        cafeteria: null,
        hasBall: false,
        ballPriceText: '',
        requireDeposit: false,
        depositText: '',
        priceText: '200',
        isArabic: false,
        selectFeaturesError: 'Select features',
        ballPriceMinError: 'Ball min error',
      );
      expect(nullFeatures, equals('Select features'));

      final excessDeposit = StadiumWizardValidator.validateStep1(
        selectedBathOption: 'Yes',
        cafeteria: true,
        hasBall: false,
        ballPriceText: '',
        requireDeposit: true,
        depositText: '120',
        priceText: '200',
        isArabic: false,
        selectFeaturesError: 'Select features',
        ballPriceMinError: 'Ball min error',
      );
      expect(excessDeposit, contains('Deposit amount cannot exceed 50%'));

      final validStep1 = StadiumWizardValidator.validateStep1(
        selectedBathOption: 'Yes',
        cafeteria: true,
        hasBall: true,
        ballPriceText: '20',
        requireDeposit: true,
        depositText: '50',
        priceText: '200',
        isArabic: false,
        selectFeaturesError: 'Select features',
        ballPriceMinError: 'Ball min error',
      );
      expect(validStep1, isNull);
    });

    test('validateStep2 checks empty images for new stadium', () {
      final noImages = StadiumWizardValidator.validateStep2(
        images: [],
        stadiumId: null,
        uploadPhotoError: 'Upload a photo',
      );
      expect(noImages, equals('Upload a photo'));

      final uploadingImages = StadiumWizardValidator.validateStep2(
        images: [
          {'url': 'https://example.com/img.jpg', 'isUploading': true}
        ],
        stadiumId: '123',
        uploadPhotoError: 'Upload a photo',
      );
      expect(uploadingImages, contains('Please wait'));

      final validImages = StadiumWizardValidator.validateStep2(
        images: [
          {'url': 'https://example.com/img.jpg', 'isUploading': false}
        ],
        stadiumId: null,
        uploadPhotoError: 'Upload a photo',
      );
      expect(validImages, isNull);
    });
  });

  group('StadiumWizardPayloadBuilder', () {
    test('buildFeatures builds valid nested map', () {
      final features = StadiumWizardPayloadBuilder.buildFeatures(
        stadiumPhone: '01012345678',
        sportType: 'Football',
        floorType: 'Turf',
        bathOption: 'Yes',
        cafeteria: true,
        garage: false,
        changingRoom: true,
        seats: '50',
        length: '40',
        width: '20',
        hasBall: true,
        ballPrice: 25.0,
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: false,
        breakTimes: [],
        uploadedUrls: ['https://example.com/img1.jpg'],
      );

      expect(features['stadiumPhone'], equals('01012345678'));
      expect(features['sportType'], equals('Football'));
      expect(features['hasBall'], isTrue);
      expect(features['ballPrice'], equals(25.0));
      expect(features['workingHours']['start'], equals('16:00:00'));
      expect(features['allImages'], contains('https://example.com/img1.jpg'));
    });

    test('buildFeatures filters incomplete breakTimes and sets isSplitShift to false if empty', () {
      final features = StadiumWizardPayloadBuilder.buildFeatures(
        stadiumPhone: '01012345678',
        sportType: 'Football',
        floorType: 'Turf',
        bathOption: 'Yes',
        cafeteria: true,
        garage: false,
        changingRoom: true,
        seats: '50',
        length: '40',
        width: '20',
        hasBall: false,
        ballPrice: 0.0,
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: true,
        breakTimes: [
          {'start': null, 'end': null},
          {'start': const TimeOfDay(hour: 17, minute: 0), 'end': null},
        ],
        uploadedUrls: [],
      );

      expect(features['isSplitShift'], isFalse);
      expect(features['breakTimes'], isEmpty);
      expect(features['breakTime'], isNull);
    });

    test('buildFeatures preserves valid completed breakTimes', () {
      final features = StadiumWizardPayloadBuilder.buildFeatures(
        stadiumPhone: '01012345678',
        sportType: 'Football',
        floorType: 'Turf',
        bathOption: 'Yes',
        cafeteria: true,
        garage: false,
        changingRoom: true,
        seats: '50',
        length: '40',
        width: '20',
        hasBall: false,
        ballPrice: 0.0,
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: true,
        breakTimes: [
          {'start': const TimeOfDay(hour: 18, minute: 0), 'end': const TimeOfDay(hour: 19, minute: 0)},
          {'start': null, 'end': null},
        ],
        uploadedUrls: [],
      );

      expect(features['isSplitShift'], isTrue);
      expect(features['breakTimes'].length, equals(1));
      expect(features['breakTimes'].first['start'], equals('18:00:00'));
      expect(features['breakTimes'].first['end'], equals('19:00:00'));
      expect(features['breakTime']['start'], equals('18:00:00'));
    });

    test('buildUpdatePayload builds proper schema map', () {
      final payload = StadiumWizardPayloadBuilder.buildUpdatePayload(
        name: 'Anfield',
        location: 'Liverpool',
        governorate: 'Cairo',
        pricePerHour: 250.0,
        capacity: 6,
        requireDeposit: true,
        depositAmount: 50.0,
        uploadedUrls: ['https://example.com/stadium.png'],
        notes: 'Strict rules apply',
        features: {'floorType': 'Turf'},
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        latitude: 30.0444,
        longitude: 31.2357,
      );

      expect(payload['name'], equals('Anfield'));
      expect(payload['total_field_capacity'], equals(12));
      expect(payload['needs_deposit'], isTrue);
      expect(payload['deposit_amount'], equals(50.0));
      expect(payload['imageUrl'], equals('https://example.com/stadium.png'));
    });
  });
}
