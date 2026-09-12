import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VSP'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book your pitch easily and join teams'**
  String get welcomeSubtitle;

  /// No description provided for @iAmPlayer.
  ///
  /// In en, this message translates to:
  /// **'I AM A PLAYER'**
  String get iAmPlayer;

  /// No description provided for @iAmOwner.
  ///
  /// In en, this message translates to:
  /// **'I AM STADIUM OWNER'**
  String get iAmOwner;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter Your Email'**
  String get enterEmail;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'example@email.com'**
  String get emailHint;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyEmail;

  /// No description provided for @verificationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to'**
  String get verificationCodeSent;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Code'**
  String get enterCode;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @setPassword.
  ///
  /// In en, this message translates to:
  /// **'Set Your Password'**
  String get setPassword;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordHint;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account Created Successfully!'**
  String get accountCreated;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VSP Family'**
  String get welcomeMessage;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @facilityDetails.
  ///
  /// In en, this message translates to:
  /// **'Facility Details'**
  String get facilityDetails;

  /// No description provided for @stadiumName.
  ///
  /// In en, this message translates to:
  /// **'Stadium Name'**
  String get stadiumName;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @socialMedia.
  ///
  /// In en, this message translates to:
  /// **'Social Media Links'**
  String get socialMedia;

  /// No description provided for @uploadDocuments.
  ///
  /// In en, this message translates to:
  /// **'Upload Documents'**
  String get uploadDocuments;

  /// No description provided for @commercialRegister.
  ///
  /// In en, this message translates to:
  /// **'Commercial Register'**
  String get commercialRegister;

  /// No description provided for @taxCard.
  ///
  /// In en, this message translates to:
  /// **'Tax Card'**
  String get taxCard;

  /// No description provided for @nationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID Photo'**
  String get nationalId;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @hiSporty.
  ///
  /// In en, this message translates to:
  /// **'Hi Player'**
  String get hiSporty;

  /// No description provided for @playerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start By Creating An Account. This Makes It Easier To Book Your Next Match.'**
  String get playerSubtitle;

  /// No description provided for @hiPitch.
  ///
  /// In en, this message translates to:
  /// **'Hi Owner'**
  String get hiPitch;

  /// No description provided for @ownerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start By Creating An Account. This Makes It Easier To Manage Your Stadium.'**
  String get ownerSubtitle;

  /// No description provided for @createNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create new account'**
  String get createNewAccount;

  /// No description provided for @continueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue With Email'**
  String get continueWithEmail;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @termsText.
  ///
  /// In en, this message translates to:
  /// **'By using VSP , you agree to the\nTerms and '**
  String get termsText;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy.'**
  String get privacyPolicy;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @unleashChampion.
  ///
  /// In en, this message translates to:
  /// **'BE THE CHAMPION'**
  String get unleashChampion;

  /// No description provided for @premierPlatform.
  ///
  /// In en, this message translates to:
  /// **'Book your pitch in seconds, compete with teams, and earn champions ranking'**
  String get premierPlatform;

  /// No description provided for @readyToJoin.
  ///
  /// In en, this message translates to:
  /// **'READY TO JOIN?'**
  String get readyToJoin;

  /// No description provided for @signOutCurrentAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign out of current account'**
  String get signOutCurrentAccount;

  /// No description provided for @credentialAccess.
  ///
  /// In en, this message translates to:
  /// **'Credential Access'**
  String get credentialAccess;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// No description provided for @apple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get apple;

  /// No description provided for @google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @byUsingVsp.
  ///
  /// In en, this message translates to:
  /// **'By using VSP, you agree to the '**
  String get byUsingVsp;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your sports journey'**
  String get signInSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @firstNameHint.
  ///
  /// In en, this message translates to:
  /// **'Mohamed'**
  String get firstNameHint;

  /// No description provided for @lastNameHint.
  ///
  /// In en, this message translates to:
  /// **'Ahmed'**
  String get lastNameHint;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @dateOfBirthPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get dateOfBirthPlaceholder;

  /// No description provided for @addPersonalPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Add Number (Personal Phone Number)'**
  String get addPersonalPhoneNumber;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @governorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get governorate;

  /// No description provided for @preferredPosition.
  ///
  /// In en, this message translates to:
  /// **'Preferred Position'**
  String get preferredPosition;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @registerOwnerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register as owner and manage your pitch'**
  String get registerOwnerSubtitle;

  /// No description provided for @registerPlayerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register as player and start your journey'**
  String get registerPlayerSubtitle;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all fields'**
  String get fillAllFields;

  /// No description provided for @pleaseEnterDob.
  ///
  /// In en, this message translates to:
  /// **'Please enter your date of birth'**
  String get pleaseEnterDob;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get invalidPhone;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @verifyAccount.
  ///
  /// In en, this message translates to:
  /// **'VERIFY ACCOUNT'**
  String get verifyAccount;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'A 6-digit code was sent to '**
  String get otpSentTo;

  /// No description provided for @enterOtpPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to your device'**
  String get enterOtpPlaceholder;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'RESEND IN {seconds} SECONDS'**
  String resendIn(int seconds);

  /// No description provided for @homeNav.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNav;

  /// No description provided for @matchesNav.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matchesNav;

  /// No description provided for @championNav.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get championNav;

  /// No description provided for @bookedNav.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get bookedNav;

  /// No description provided for @profileNav.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileNav;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @nearbyStadiums.
  ///
  /// In en, this message translates to:
  /// **'Nearby Stadiums'**
  String get nearbyStadiums;

  /// No description provided for @joinMatches.
  ///
  /// In en, this message translates to:
  /// **'Join Matches'**
  String get joinMatches;

  /// No description provided for @joinChampionships.
  ///
  /// In en, this message translates to:
  /// **'Join Championships'**
  String get joinChampionships;

  /// No description provided for @searchStadiums.
  ///
  /// In en, this message translates to:
  /// **'Search stadiums, teams...'**
  String get searchStadiums;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// No description provided for @noStadiumsFoundIn.
  ///
  /// In en, this message translates to:
  /// **'No stadiums found in '**
  String get noStadiumsFoundIn;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @hi.
  ///
  /// In en, this message translates to:
  /// **'Hi'**
  String get hi;

  /// No description provided for @playerDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerDefaultName;

  /// No description provided for @tournament.
  ///
  /// In en, this message translates to:
  /// **'TOURNAMENT'**
  String get tournament;

  /// No description provided for @egCurrency.
  ///
  /// In en, this message translates to:
  /// **'eg'**
  String get egCurrency;

  /// No description provided for @spotsLeft.
  ///
  /// In en, this message translates to:
  /// **'SPOTS LEFT'**
  String get spotsLeft;

  /// No description provided for @teamsJoined.
  ///
  /// In en, this message translates to:
  /// **'{joinedCount}/{maxCount} TEAMS JOINED'**
  String teamsJoined(int joinedCount, int maxCount);

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @pitchConditions.
  ///
  /// In en, this message translates to:
  /// **'Pitch Conditions'**
  String get pitchConditions;

  /// No description provided for @ratings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get ratings;

  /// No description provided for @pricePerHour.
  ///
  /// In en, this message translates to:
  /// **'Price per hour'**
  String get pricePerHour;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'{count} Reviews'**
  String reviews(int count);

  /// No description provided for @na.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get na;

  /// No description provided for @informationStadium.
  ///
  /// In en, this message translates to:
  /// **'Stadium Information & Specs'**
  String get informationStadium;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get noDescription;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @featuresForMoney.
  ///
  /// In en, this message translates to:
  /// **'Additional Services & Add-ons'**
  String get featuresForMoney;

  /// No description provided for @ballAvailable.
  ///
  /// In en, this message translates to:
  /// **'Ball Available: {price} {currency}'**
  String ballAvailable(String price, String currency);

  /// No description provided for @ownerNotes.
  ///
  /// In en, this message translates to:
  /// **'Owner Notes'**
  String get ownerNotes;

  /// No description provided for @noOwnerNotes.
  ///
  /// In en, this message translates to:
  /// **'No specific notes have been added by the stadium owner.'**
  String get noOwnerNotes;

  /// No description provided for @punctuality.
  ///
  /// In en, this message translates to:
  /// **'Punctuality:'**
  String get punctuality;

  /// No description provided for @punctualityPolicy.
  ///
  /// In en, this message translates to:
  /// **'Customers must arrive on time for their reservation. Any delay may result in forfeiting part of their playing time without compensation.'**
  String get punctualityPolicy;

  /// No description provided for @reservationDuration.
  ///
  /// In en, this message translates to:
  /// **'Reservation Duration:'**
  String get reservationDuration;

  /// No description provided for @reservationDurationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Playing time cannot be extended after the booked slot expires. If additional time is required, a new reservation must be made (subject to availability).'**
  String get reservationDurationPolicy;

  /// No description provided for @cancellationPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancellation and Refund Policy:'**
  String get cancellationPolicyTitle;

  /// No description provided for @cancellationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Full refund (100%) is applicable if cancelled at least 6 hours before match kickoff, or at least 2 days (48 hours) prior for tournaments.\n\n20-Minute Grace Window: Cancellations within the first 20 minutes of booking are eligible for a refund minus non-refundable administrative and gateway processing fees.\n\nNo refund is provided if cancelled less than 6 hours prior to kickoff (or less than 2 days for tournaments) after the initial 20-minute window has expired.'**
  String get cancellationPolicy;

  /// No description provided for @liability.
  ///
  /// In en, this message translates to:
  /// **'Liability:'**
  String get liability;

  /// No description provided for @liabilityPolicy.
  ///
  /// In en, this message translates to:
  /// **'Stadium management is not responsible for lost, stolen, or damaged personal belongings. Players use the facilities at their own risk.'**
  String get liabilityPolicy;

  /// No description provided for @noReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet. Be the first to review!'**
  String get noReviews;

  /// No description provided for @recently.
  ///
  /// In en, this message translates to:
  /// **'Recently'**
  String get recently;

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @bookedTitle.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get bookedTitle;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noBookings.
  ///
  /// In en, this message translates to:
  /// **'No Bookings Yet'**
  String get noBookings;

  /// No description provided for @noBookingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book a stadium or join a match to see your schedule here!'**
  String get noBookingsSubtitle;

  /// No description provided for @exploreStadiums.
  ///
  /// In en, this message translates to:
  /// **'Explore Stadiums'**
  String get exploreStadiums;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'PRIVATE'**
  String get private;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @submitResult.
  ///
  /// In en, this message translates to:
  /// **'Submit Result'**
  String get submitResult;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @vsOpponent.
  ///
  /// In en, this message translates to:
  /// **'VS {opponent}'**
  String vsOpponent(String opponent);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @waitingOpponent.
  ///
  /// In en, this message translates to:
  /// **'Waiting for opponent result...'**
  String get waitingOpponent;

  /// No description provided for @addResult.
  ///
  /// In en, this message translates to:
  /// **'Add Result'**
  String get addResult;

  /// No description provided for @resultSuccess.
  ///
  /// In en, this message translates to:
  /// **'Result Submitted Successfully!'**
  String get resultSuccess;

  /// No description provided for @resultFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit result'**
  String get resultFailed;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get draw;

  /// No description provided for @win.
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get win;

  /// No description provided for @loss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get loss;

  /// No description provided for @disputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get disputed;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking?'**
  String get cancelBooking;

  /// No description provided for @cancelBookingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this booking? This action cannot be undone.'**
  String get cancelBookingConfirm;

  /// No description provided for @keepBooking.
  ///
  /// In en, this message translates to:
  /// **'Keep Booking'**
  String get keepBooking;

  /// No description provided for @cancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling booking...'**
  String get cancelling;

  /// No description provided for @cancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled successfully'**
  String get cancelSuccess;

  /// No description provided for @cancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel'**
  String get cancelFailed;

  /// No description provided for @shareStadiumText.
  ///
  /// In en, this message translates to:
  /// **'Check out {stadiumName} in {location} on VSP app!'**
  String shareStadiumText(String stadiumName, String location);

  /// No description provided for @perHour.
  ///
  /// In en, this message translates to:
  /// **'per hour'**
  String get perHour;

  /// No description provided for @myMatch.
  ///
  /// In en, this message translates to:
  /// **'MY MATCH'**
  String get myMatch;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'FULL'**
  String get full;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get open;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @playersJoined.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total} PLAYERS JOINED'**
  String playersJoined(int current, int total);

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'MANAGE'**
  String get manage;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'LEAVE'**
  String get leave;

  /// No description provided for @vspTeam.
  ///
  /// In en, this message translates to:
  /// **'VSP Team'**
  String get vspTeam;

  /// No description provided for @loginFirst.
  ///
  /// In en, this message translates to:
  /// **'Please login first'**
  String get loginFirst;

  /// No description provided for @joinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Joined Match Successfully!'**
  String get joinSuccess;

  /// No description provided for @joinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join match.'**
  String get joinFailed;

  /// No description provided for @leaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Left Match Successfully.'**
  String get leaveSuccess;

  /// No description provided for @leaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave match.'**
  String get leaveFailed;

  /// No description provided for @participantRemoved.
  ///
  /// In en, this message translates to:
  /// **'Participant removed.'**
  String get participantRemoved;

  /// No description provided for @maxCapacityReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum stadium capacity reached.'**
  String get maxCapacityReached;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update spots.'**
  String get updateFailed;

  /// No description provided for @manageMatch.
  ///
  /// In en, this message translates to:
  /// **'Manage Match'**
  String get manageMatch;

  /// No description provided for @bringingPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players you are bringing'**
  String get bringingPlayers;

  /// No description provided for @manageSpots.
  ///
  /// In en, this message translates to:
  /// **'Manage your reserved spots'**
  String get manageSpots;

  /// No description provided for @joinedFromApp.
  ///
  /// In en, this message translates to:
  /// **'Joined from App'**
  String get joinedFromApp;

  /// No description provided for @noPlayersYet.
  ///
  /// In en, this message translates to:
  /// **'No players joined yet'**
  String get noPlayersYet;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @positionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position: {pos}'**
  String positionLabel(String pos);

  /// No description provided for @adminModeActivated.
  ///
  /// In en, this message translates to:
  /// **'Admin Mode Activated'**
  String get adminModeActivated;

  /// No description provided for @winRate.
  ///
  /// In en, this message translates to:
  /// **'WIN RATE'**
  String get winRate;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'GOALS'**
  String get goals;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'MATCHES'**
  String get matches;

  /// No description provided for @favoriteStadiumLabel.
  ///
  /// In en, this message translates to:
  /// **'FAVORITE STADIUM: {stadium}'**
  String favoriteStadiumLabel(String stadium);

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @myTeam.
  ///
  /// In en, this message translates to:
  /// **'My Team'**
  String get myTeam;

  /// No description provided for @manageTeamInfo.
  ///
  /// In en, this message translates to:
  /// **'Manage Your Team Information'**
  String get manageTeamInfo;

  /// No description provided for @favoriteStadiums.
  ///
  /// In en, this message translates to:
  /// **'Favorite Stadiums'**
  String get favoriteStadiums;

  /// No description provided for @viewLikedFacilities.
  ///
  /// In en, this message translates to:
  /// **'View Your Liked Facilities'**
  String get viewLikedFacilities;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethods;

  /// No description provided for @managePaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Manage Your Payment Methods'**
  String get managePaymentMethods;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @manageNotificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Manage Your Notification Settings'**
  String get manageNotificationSettings;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @manageLanguagePreferences.
  ///
  /// In en, this message translates to:
  /// **'Manage Your Language Preferences'**
  String get manageLanguagePreferences;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @getHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Get Help & Support'**
  String get getHelpSupport;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @reportIssueFeature.
  ///
  /// In en, this message translates to:
  /// **'Report an issue or suggest a feature'**
  String get reportIssueFeature;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @signOutAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign out of your account'**
  String get signOutAccount;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// No description provided for @describeIssue.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue...'**
  String get describeIssue;

  /// No description provided for @attachScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Attach Screenshot'**
  String get attachScreenshot;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @pleaseEnterFeedback.
  ///
  /// In en, this message translates to:
  /// **'Please enter some feedback'**
  String get pleaseEnterFeedback;

  /// No description provided for @thankYouFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get thankYouFeedback;

  /// No description provided for @legendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get legendary;

  /// No description provided for @diamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get diamond;

  /// No description provided for @platinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get platinum;

  /// No description provided for @gold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get gold;

  /// No description provided for @silver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get silver;

  /// No description provided for @bronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get bronze;

  /// No description provided for @champion.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get champion;

  /// No description provided for @ranking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get ranking;

  /// No description provided for @championships.
  ///
  /// In en, this message translates to:
  /// **'Championships'**
  String get championships;

  /// No description provided for @teams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get teams;

  /// No description provided for @oneVsOnePlayers.
  ///
  /// In en, this message translates to:
  /// **'1v1 Players'**
  String get oneVsOnePlayers;

  /// No description provided for @noOneVsOneRanked.
  ///
  /// In en, this message translates to:
  /// **'No 1v1 players ranked yet'**
  String get noOneVsOneRanked;

  /// No description provided for @skillPointsLabel.
  ///
  /// In en, this message translates to:
  /// **'SKILL: {skill} | G: {goals}'**
  String skillPointsLabel(int skill, int goals);

  /// No description provided for @pts.
  ///
  /// In en, this message translates to:
  /// **'PTS'**
  String get pts;

  /// No description provided for @noTeamsInLoc.
  ///
  /// In en, this message translates to:
  /// **'No teams in {location} yet'**
  String noTeamsInLoc(String location);

  /// No description provided for @vspOfficialLeague.
  ///
  /// In en, this message translates to:
  /// **'VSP 1V1 OFFICIAL LEAGUE'**
  String get vspOfficialLeague;

  /// No description provided for @watchHighlights.
  ///
  /// In en, this message translates to:
  /// **'Watch highlights & follow the ultimate street ranking!'**
  String get watchHighlights;

  /// No description provided for @teamStats.
  ///
  /// In en, this message translates to:
  /// **'MP: {mp} | W: {w} | D: {d} | L: {l}'**
  String teamStats(int mp, int w, int d, int l);

  /// No description provided for @pointsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String pointsCount(int count);

  /// No description provided for @noChampionshipsInLoc.
  ///
  /// In en, this message translates to:
  /// **'No championships in {location} yet'**
  String noChampionshipsInLoc(String location);

  /// No description provided for @chooseBookingType.
  ///
  /// In en, this message translates to:
  /// **'Choose What Suits You'**
  String get chooseBookingType;

  /// No description provided for @bookPitch.
  ///
  /// In en, this message translates to:
  /// **'Book a Pitch'**
  String get bookPitch;

  /// No description provided for @bookPitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Private booking for you and friends. No ranking.'**
  String get bookPitchSubtitle;

  /// No description provided for @findPlayers.
  ///
  /// In en, this message translates to:
  /// **'Find Players'**
  String get findPlayers;

  /// No description provided for @findPlayersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Public match. Allow others to join to complete numbers.'**
  String get findPlayersSubtitle;

  /// No description provided for @teamIncompleteError.
  ///
  /// In en, this message translates to:
  /// **'You still need a complete team of 5+ to play challenge matches.'**
  String get teamIncompleteError;

  /// No description provided for @createTeamToCompete.
  ///
  /// In en, this message translates to:
  /// **'Create Team to Compete'**
  String get createTeamToCompete;

  /// No description provided for @createTeamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You need a team of 5+ players to play competitive matches. Start here!'**
  String get createTeamSubtitle;

  /// No description provided for @teamIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Team Incomplete'**
  String get teamIncomplete;

  /// No description provided for @teamIncompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You need 5+ players to play ranked matches. Add more players!'**
  String get teamIncompleteSubtitle;

  /// No description provided for @challengeMatch.
  ///
  /// In en, this message translates to:
  /// **'Challenge Match'**
  String get challengeMatch;

  /// No description provided for @challengeMatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compete against other teams and rank up.'**
  String get challengeMatchSubtitle;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get selectTime;

  /// No description provided for @bookedStatus.
  ///
  /// In en, this message translates to:
  /// **'BOOKED'**
  String get bookedStatus;

  /// No description provided for @expiredStatus.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get expiredStatus;

  /// No description provided for @privateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateLabel;

  /// No description provided for @currentPlayersWithYou.
  ///
  /// In en, this message translates to:
  /// **'Current Players with You'**
  String get currentPlayersWithYou;

  /// No description provided for @playersInGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How many players are already in your group?'**
  String get playersInGroupSubtitle;

  /// No description provided for @rentBallLabel.
  ///
  /// In en, this message translates to:
  /// **'Rent Ball (+{price} {currency})'**
  String rentBallLabel(int price, String currency);

  /// No description provided for @payPerBallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay Per Ball At This Pitch'**
  String get payPerBallSubtitle;

  /// No description provided for @totalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get totalPriceLabel;

  /// No description provided for @priceEgp.
  ///
  /// In en, this message translates to:
  /// **'{price} EGP'**
  String priceEgp(int price);

  /// No description provided for @confirmSelections.
  ///
  /// In en, this message translates to:
  /// **'Confirm Selections'**
  String get confirmSelections;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @bookingSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your reservation has been completed successfully'**
  String get bookingSuccess;

  /// No description provided for @bookingReference.
  ///
  /// In en, this message translates to:
  /// **'Booking Reference'**
  String get bookingReference;

  /// No description provided for @refHash.
  ///
  /// In en, this message translates to:
  /// **'REF# {id}'**
  String refHash(String id);

  /// No description provided for @myBookings.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get myBookings;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @bookingRefCopied.
  ///
  /// In en, this message translates to:
  /// **'Booking reference copied!'**
  String get bookingRefCopied;

  /// No description provided for @shareBookingMessage.
  ///
  /// In en, this message translates to:
  /// **'My booking on VSP: {stadium} - Ref# {id}'**
  String shareBookingMessage(String stadium, String id);

  /// No description provided for @selectOpponentTeam.
  ///
  /// In en, this message translates to:
  /// **'Select Opponent Team'**
  String get selectOpponentTeam;

  /// No description provided for @chooseOpponent.
  ///
  /// In en, this message translates to:
  /// **'Choose Opponent'**
  String get chooseOpponent;

  /// No description provided for @chooseOpponentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search for a team to challenge or pick from teams you\'ve played against.'**
  String get chooseOpponentSubtitle;

  /// No description provided for @searchTeamPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by Team Name or Captain\'s Phone'**
  String get searchTeamPlaceholder;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResults;

  /// No description provided for @noTeamsFound.
  ///
  /// In en, this message translates to:
  /// **'No teams found matching \'{query}\''**
  String noTeamsFound(String query);

  /// No description provided for @previousOpponents.
  ///
  /// In en, this message translates to:
  /// **'Teams You Played Against'**
  String get previousOpponents;

  /// No description provided for @noPreviousOpponents.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have previous opponents yet.\nStart by searching for a team.'**
  String get noPreviousOpponents;

  /// No description provided for @matchesPlayedCount.
  ///
  /// In en, this message translates to:
  /// **'Matches played: {count}'**
  String matchesPlayedCount(int count);

  /// No description provided for @firstTimePlaying.
  ///
  /// In en, this message translates to:
  /// **'First time playing against them. Set the tone!'**
  String get firstTimePlaying;

  /// No description provided for @headToHeadHistory.
  ///
  /// In en, this message translates to:
  /// **'HEAD-TO-HEAD HISTORY'**
  String get headToHeadHistory;

  /// No description provided for @yourWins.
  ///
  /// In en, this message translates to:
  /// **'YOUR WINS'**
  String get yourWins;

  /// No description provided for @draws.
  ///
  /// In en, this message translates to:
  /// **'DRAWS'**
  String get draws;

  /// No description provided for @theirWins.
  ///
  /// In en, this message translates to:
  /// **'THEIR WINS'**
  String get theirWins;

  /// No description provided for @seriesTied.
  ///
  /// In en, this message translates to:
  /// **'The series is tied! Break the deadlock!'**
  String get seriesTied;

  /// No description provided for @youDominate.
  ///
  /// In en, this message translates to:
  /// **'You dominate them. Keep the streak alive!'**
  String get youDominate;

  /// No description provided for @timeForRevenge.
  ///
  /// In en, this message translates to:
  /// **'Time for revenge! They have the upper hand.'**
  String get timeForRevenge;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhone;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @nameEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty.'**
  String get nameEmptyError;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccess;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile.'**
  String get profileUpdateFailed;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String errorOccurred(String error);

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @trophies.
  ///
  /// In en, this message translates to:
  /// **'Trophies'**
  String get trophies;

  /// No description provided for @teamName.
  ///
  /// In en, this message translates to:
  /// **'Team Name'**
  String get teamName;

  /// No description provided for @enterTeamName.
  ///
  /// In en, this message translates to:
  /// **'Enter your team name'**
  String get enterTeamName;

  /// No description provided for @sportsType.
  ///
  /// In en, this message translates to:
  /// **'Sports Type'**
  String get sportsType;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// No description provided for @teamMembersHeader.
  ///
  /// In en, this message translates to:
  /// **'Team Members ({current}/{max})'**
  String teamMembersHeader(int current, int max);

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get addMember;

  /// No description provided for @addMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Add your team members'**
  String get addMembersHint;

  /// No description provided for @teamAchievements.
  ///
  /// In en, this message translates to:
  /// **'Team Achievements'**
  String get teamAchievements;

  /// No description provided for @winStreak.
  ///
  /// In en, this message translates to:
  /// **'{count} Win Streak'**
  String winStreak(int count);

  /// No description provided for @registerTeamPrompt.
  ///
  /// In en, this message translates to:
  /// **'Register your team to start unlocking achievements!'**
  String get registerTeamPrompt;

  /// No description provided for @createTeam.
  ///
  /// In en, this message translates to:
  /// **'Create Team'**
  String get createTeam;

  /// No description provided for @deleteTeam.
  ///
  /// In en, this message translates to:
  /// **'Delete Team'**
  String get deleteTeam;

  /// No description provided for @deleteTeamConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This action cannot be undone and your team and achievements will be lost.'**
  String get deleteTeamConfirm;

  /// No description provided for @enterTeamNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a team name'**
  String get enterTeamNameError;

  /// No description provided for @teamCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Team created successfully!'**
  String get teamCreatedSuccess;

  /// No description provided for @teamUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Team updated successfully!'**
  String get teamUpdatedSuccess;

  /// No description provided for @teamDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Team deleted successfully'**
  String get teamDeletedSuccess;

  /// No description provided for @confirmBooking.
  ///
  /// In en, this message translates to:
  /// **'Confirm Booking'**
  String get confirmBooking;

  /// No description provided for @bookingSummary.
  ///
  /// In en, this message translates to:
  /// **'Booking Summary'**
  String get bookingSummary;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @cashPayAtStadium.
  ///
  /// In en, this message translates to:
  /// **'Cash (Pay at Stadium)'**
  String get cashPayAtStadium;

  /// No description provided for @cashPayment.
  ///
  /// In en, this message translates to:
  /// **'Cash Payment'**
  String get cashPayment;

  /// No description provided for @cashPaymentDesc.
  ///
  /// In en, this message translates to:
  /// **'Booking Confirmed - Please pay cash at the stadium'**
  String get cashPaymentDesc;

  /// No description provided for @sessionExpiredError.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get sessionExpiredError;

  /// No description provided for @bookingCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create booking'**
  String get bookingCreateFailed;

  /// No description provided for @bookingFailedError.
  ///
  /// In en, this message translates to:
  /// **'Booking failed: {error}'**
  String bookingFailedError(Object error);

  /// No description provided for @privateBooking.
  ///
  /// In en, this message translates to:
  /// **'Private Booking'**
  String get privateBooking;

  /// No description provided for @ranked.
  ///
  /// In en, this message translates to:
  /// **'Ranked'**
  String get ranked;

  /// No description provided for @friendly.
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get friendly;

  /// No description provided for @subtotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Subtotal Amount'**
  String get subtotalAmount;

  /// No description provided for @loginToJoinError.
  ///
  /// In en, this message translates to:
  /// **'Please login to join matches'**
  String get loginToJoinError;

  /// No description provided for @matchJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully joined the match!'**
  String get matchJoinSuccess;

  /// No description provided for @reportMatch.
  ///
  /// In en, this message translates to:
  /// **'Report Match'**
  String get reportMatch;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us maintain a safe community. Why are you reporting this match?'**
  String get reportSubtitle;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate Content'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonFake.
  ///
  /// In en, this message translates to:
  /// **'Fake Match'**
  String get reportReasonFake;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReasonOther;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted for review.'**
  String get reportSubmitted;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report.'**
  String get reportFailed;

  /// No description provided for @matchNotFound.
  ///
  /// In en, this message translates to:
  /// **'Match not found'**
  String get matchNotFound;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @publicMatchAt.
  ///
  /// In en, this message translates to:
  /// **'Public Match at {stadium}'**
  String publicMatchAt(String stadium);

  /// No description provided for @vsMatchFormat.
  ///
  /// In en, this message translates to:
  /// **'{team1} VS {team2}'**
  String vsMatchFormat(String team1, String team2);

  /// No description provided for @playersCount.
  ///
  /// In en, this message translates to:
  /// **'Players ({current}/{max})'**
  String playersCount(int current, int max);

  /// No description provided for @playerLabel.
  ///
  /// In en, this message translates to:
  /// **'Player {index}'**
  String playerLabel(int index);

  /// No description provided for @matchFull.
  ///
  /// In en, this message translates to:
  /// **'Match Full'**
  String get matchFull;

  /// No description provided for @joinMatch.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinMatch;

  /// No description provided for @captainRequiredError.
  ///
  /// In en, this message translates to:
  /// **'To join the tournament, you must be a team captain.'**
  String get captainRequiredError;

  /// No description provided for @minPlayersError.
  ///
  /// In en, this message translates to:
  /// **'Your team must have at least 5 players to participate.'**
  String get minPlayersError;

  /// No description provided for @alreadyJoinedError.
  ///
  /// In en, this message translates to:
  /// **'Your team has already joined this tournament.'**
  String get alreadyJoinedError;

  /// No description provided for @tournamentJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully joined the tournament! Good luck to team {team} '**
  String tournamentJoinSuccess(String team);

  /// No description provided for @joinConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Join Confirmation'**
  String get joinConfirmation;

  /// No description provided for @entryFee.
  ///
  /// In en, this message translates to:
  /// **'Entry Fee: {amount} {currency}'**
  String entryFee(int amount, String currency);

  /// No description provided for @tournamentPaymentDesc.
  ///
  /// In en, this message translates to:
  /// **'Payment will be made in Cash at the stadium when the tournament begins.'**
  String get tournamentPaymentDesc;

  /// No description provided for @confirmAndPay.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Pay'**
  String get confirmAndPay;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @groupStage.
  ///
  /// In en, this message translates to:
  /// **'Group Stage'**
  String get groupStage;

  /// No description provided for @quarterFinals.
  ///
  /// In en, this message translates to:
  /// **'Quarter Finals'**
  String get quarterFinals;

  /// No description provided for @finalMatch.
  ///
  /// In en, this message translates to:
  /// **'Final Match'**
  String get finalMatch;

  /// No description provided for @aboutTournament.
  ///
  /// In en, this message translates to:
  /// **'About The Tournament'**
  String get aboutTournament;

  /// No description provided for @matchRules.
  ///
  /// In en, this message translates to:
  /// **'Match Rules And Regulations'**
  String get matchRules;

  /// No description provided for @importantInstructions.
  ///
  /// In en, this message translates to:
  /// **'Important Instructions For Players'**
  String get importantInstructions;

  /// No description provided for @viewBrackets.
  ///
  /// In en, this message translates to:
  /// **'View Tournament Brackets'**
  String get viewBrackets;

  /// No description provided for @matchRulesContent.
  ///
  /// In en, this message translates to:
  /// **'Each Match Lasts {duration} Minutes.\nTeams Must Arrive 15 Minutes Before The Start Of The Match.\nA Team That Is More Than 10 Minutes Late Will Be Considered Forfeited.\nThe Tournament Is A League System, And The Top Teams Advance To The Knockout Stage.'**
  String matchRulesContent(int duration);

  /// No description provided for @importantInstructionsContent.
  ///
  /// In en, this message translates to:
  /// **'Each Player Must Wear Designated Sports Shoes (Kochi)—Barefoot Play Is Not Permitted.\nPlayers Must Bring Their Own Sports Clothing And Equipment.\nPlease Keep The Field Clean And Follow The Organizers\' Instructions.'**
  String get importantInstructionsContent;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search stadiums, teams, or cups...'**
  String get searchHint;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get recentSearches;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResults;

  /// No description provided for @stadiumsCategory.
  ///
  /// In en, this message translates to:
  /// **'Stadiums '**
  String get stadiumsCategory;

  /// No description provided for @teamsCategory.
  ///
  /// In en, this message translates to:
  /// **'Teams '**
  String get teamsCategory;

  /// No description provided for @championshipsCategory.
  ///
  /// In en, this message translates to:
  /// **'Championships '**
  String get championshipsCategory;

  /// No description provided for @prizeLabel.
  ///
  /// In en, this message translates to:
  /// **'{prize} Prize'**
  String prizeLabel(Object prize);

  /// No description provided for @markAll.
  ///
  /// In en, this message translates to:
  /// **'Mark All'**
  String get markAll;

  /// No description provided for @noNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Notifications Yet'**
  String get noNotificationsTitle;

  /// No description provided for @noNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will notify you about your matches and challenges.'**
  String get noNotificationsSubtitle;

  /// No description provided for @backToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to Dashboard'**
  String get backToDashboard;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(int count);

  /// No description provided for @matchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matchesTitle;

  /// No description provided for @noMatchesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No public matches available right now.'**
  String get noMatchesAvailable;

  /// No description provided for @hostOne.
  ///
  /// In en, this message translates to:
  /// **'Be the first to host one!'**
  String get hostOne;

  /// No description provided for @shareLink.
  ///
  /// In en, this message translates to:
  /// **'Share Link'**
  String get shareLink;

  /// No description provided for @shareTeamText.
  ///
  /// In en, this message translates to:
  /// **'Check out my team {name} on VSP! We are ranked {rank}. '**
  String shareTeamText(Object name, Object rank);

  /// No description provided for @addStadium.
  ///
  /// In en, this message translates to:
  /// **'Add Stadium'**
  String get addStadium;

  /// No description provided for @autoFetch.
  ///
  /// In en, this message translates to:
  /// **'Auto Fetch'**
  String get autoFetch;

  /// No description provided for @chooseManually.
  ///
  /// In en, this message translates to:
  /// **'Choose Manually'**
  String get chooseManually;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get workingHours;

  /// No description provided for @setDailyBreak.
  ///
  /// In en, this message translates to:
  /// **'Set Daily Break Time'**
  String get setDailyBreak;

  /// No description provided for @length.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get length;

  /// No description provided for @width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;

  /// No description provided for @bathrooms.
  ///
  /// In en, this message translates to:
  /// **'Bathrooms'**
  String get bathrooms;

  /// No description provided for @cafeteria.
  ///
  /// In en, this message translates to:
  /// **'Cafeteria'**
  String get cafeteria;

  /// No description provided for @garage.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get garage;

  /// No description provided for @changingRoom.
  ///
  /// In en, this message translates to:
  /// **'Changing Room'**
  String get changingRoom;

  /// No description provided for @seatCount.
  ///
  /// In en, this message translates to:
  /// **'Seat Count'**
  String get seatCount;

  /// No description provided for @amenities.
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get amenities;

  /// No description provided for @stadiumGallery.
  ///
  /// In en, this message translates to:
  /// **'Stadium Gallery'**
  String get stadiumGallery;

  /// No description provided for @submitStadium.
  ///
  /// In en, this message translates to:
  /// **'Submit Stadium'**
  String get submitStadium;

  /// No description provided for @stadiumPhotosHint.
  ///
  /// In en, this message translates to:
  /// **'High-quality photos increase your booking rate. Add at least 3 photos of the pitch, facilities, and surroundings.'**
  String get stadiumPhotosHint;

  /// No description provided for @basicInfoError.
  ///
  /// In en, this message translates to:
  /// **'Please fill basic info'**
  String get basicInfoError;

  /// No description provided for @selectFeaturesError.
  ///
  /// In en, this message translates to:
  /// **'Please select features'**
  String get selectFeaturesError;

  /// No description provided for @ballPriceMinError.
  ///
  /// In en, this message translates to:
  /// **'Ball rental price must be at least 5 EGP'**
  String get ballPriceMinError;

  /// No description provided for @uploadPhotoError.
  ///
  /// In en, this message translates to:
  /// **'Please upload at least one stadium image'**
  String get uploadPhotoError;

  /// No description provided for @stadiumSubmitSuccess.
  ///
  /// In en, this message translates to:
  /// **'Stadium Submitted for Review!'**
  String get stadiumSubmitSuccess;

  /// No description provided for @stadiumSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save stadium'**
  String get stadiumSaveFailed;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @breakStart.
  ///
  /// In en, this message translates to:
  /// **'Break Start'**
  String get breakStart;

  /// No description provided for @breakEnd.
  ///
  /// In en, this message translates to:
  /// **'Break End'**
  String get breakEnd;

  /// No description provided for @tapToFetch.
  ///
  /// In en, this message translates to:
  /// **'Tap to Fetch'**
  String get tapToFetch;

  /// No description provided for @ballAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Ball Available'**
  String get ballAvailableLabel;

  /// No description provided for @playersTeam.
  ///
  /// In en, this message translates to:
  /// **'Players per Team'**
  String get playersTeam;

  /// No description provided for @selectSport.
  ///
  /// In en, this message translates to:
  /// **'Select Sport'**
  String get selectSport;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorLabel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @wins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get wins;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @shareTeamCard.
  ///
  /// In en, this message translates to:
  /// **'Share Team Card'**
  String get shareTeamCard;

  /// No description provided for @freeAgent.
  ///
  /// In en, this message translates to:
  /// **'FREE AGENT'**
  String get freeAgent;

  /// No description provided for @freeAgentDescription.
  ///
  /// In en, this message translates to:
  /// **'You are currently a Free Agent.\nJoin or create a team to unlock your Ultimate Team Card and start competing!'**
  String get freeAgentDescription;

  /// No description provided for @buildYourSquad.
  ///
  /// In en, this message translates to:
  /// **'Build Your Squad'**
  String get buildYourSquad;

  /// No description provided for @editProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change your name, phone, position, and picture'**
  String get editProfileSubtitle;

  /// No description provided for @shareTeamMessage.
  ///
  /// In en, this message translates to:
  /// **'Check out my ultimate team \"{teamName}\" on the VSP App! \nDownload the app to challenge us!'**
  String shareTeamMessage(Object teamName);

  /// No description provided for @shareFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to share team card.'**
  String get shareFailedError;

  /// No description provided for @ovrLabel.
  ///
  /// In en, this message translates to:
  /// **'OVR'**
  String get ovrLabel;

  /// No description provided for @gldLabel.
  ///
  /// In en, this message translates to:
  /// **'GLD'**
  String get gldLabel;

  /// No description provided for @winRateLabel.
  ///
  /// In en, this message translates to:
  /// **'WIN%'**
  String get winRateLabel;

  /// No description provided for @winsLabel.
  ///
  /// In en, this message translates to:
  /// **'WINS'**
  String get winsLabel;

  /// No description provided for @strkLabel.
  ///
  /// In en, this message translates to:
  /// **'STRK'**
  String get strkLabel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @whatsAppNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp not installed'**
  String get whatsAppNotInstalled;

  /// No description provided for @createTeamFirstError.
  ///
  /// In en, this message translates to:
  /// **'Please create a team first to use this option.'**
  String get createTeamFirstError;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name required (First and Last name)'**
  String get nameRequired;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Valid phone number required'**
  String get phoneRequired;

  /// No description provided for @faq1_q.
  ///
  /// In en, this message translates to:
  /// **'How does Elo ranking work?'**
  String get faq1_q;

  /// No description provided for @faq1_a.
  ///
  /// In en, this message translates to:
  /// **'Your Elo increases when you win matches against opponents with similar or higher ranking. Losing to lower-ranked teams will decrease it more significantly.'**
  String get faq1_a;

  /// No description provided for @faq2_q.
  ///
  /// In en, this message translates to:
  /// **'How do I join a match?'**
  String get faq2_q;

  /// No description provided for @faq2_a.
  ///
  /// In en, this message translates to:
  /// **'Go to the Matches tab, find a public match that fits your schedule, and tap \"Join\". You can join as an individual or with your team.'**
  String get faq2_a;

  /// No description provided for @faq3_q.
  ///
  /// In en, this message translates to:
  /// **'Can I cancel a booking?'**
  String get faq3_q;

  /// No description provided for @faq3_a.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancellations are allowed up to 6 hours before kickoff for pitch bookings (and 2 days for tournaments) for a full refund. Cancellations within the first 20 minutes are eligible for a refund minus administrative processing fees.'**
  String get faq3_a;

  /// No description provided for @faq4_q.
  ///
  /// In en, this message translates to:
  /// **'How do I create a team?'**
  String get faq4_q;

  /// No description provided for @faq4_a.
  ///
  /// In en, this message translates to:
  /// **'In the Profile tab, select \"My Team\". From there, you can choose a name, logo, and invite your friends using their VSP ID.'**
  String get faq4_a;

  /// No description provided for @faq5_q.
  ///
  /// In en, this message translates to:
  /// **'What happens if a match is disputed?'**
  String get faq5_q;

  /// No description provided for @faq5_a.
  ///
  /// In en, this message translates to:
  /// **'If teams disagree on the result, a VSP moderator will review the match history and evidence to determine the final outcome.'**
  String get faq5_a;

  /// No description provided for @faq6_q.
  ///
  /// In en, this message translates to:
  /// **'How are stadium ratings calculated?'**
  String get faq6_q;

  /// No description provided for @faq6_a.
  ///
  /// In en, this message translates to:
  /// **'Ratings are an average of verified reviews left by players after their matches. Only players who actually played at the stadium can leave a review.'**
  String get faq6_a;

  /// No description provided for @faq7_q.
  ///
  /// In en, this message translates to:
  /// **'How do I edit my personal profile?'**
  String get faq7_q;

  /// No description provided for @faq7_a.
  ///
  /// In en, this message translates to:
  /// **'In the Profile tab, select \'Edit Profile\'. From there, you can update your name, picture, preferred position, and phone number.'**
  String get faq7_a;

  /// No description provided for @faq8_q.
  ///
  /// In en, this message translates to:
  /// **'Why is my match not appearing in the public list?'**
  String get faq8_q;

  /// No description provided for @faq8_a.
  ///
  /// In en, this message translates to:
  /// **'Private matches are hidden. Ensure you select \'Public Match\' during booking if you want others to find and join you.'**
  String get faq8_a;

  /// No description provided for @faq9_q.
  ///
  /// In en, this message translates to:
  /// **'How do I get a refund?'**
  String get faq9_q;

  /// No description provided for @faq9_a.
  ///
  /// In en, this message translates to:
  /// **'Upon valid cancellation, the amount is credited to your in-app wallet for future bookings.'**
  String get faq9_a;

  /// No description provided for @faq10_q.
  ///
  /// In en, this message translates to:
  /// **'How do I contact support?'**
  String get faq10_q;

  /// No description provided for @faq10_a.
  ///
  /// In en, this message translates to:
  /// **'Tap \'Chat with Support\' on this screen to start a WhatsApp conversation with our team directly.'**
  String get faq10_a;

  /// No description provided for @totalCollectedGross.
  ///
  /// In en, this message translates to:
  /// **'Total Collected (Gross)'**
  String get totalCollectedGross;

  /// No description provided for @netProfit.
  ///
  /// In en, this message translates to:
  /// **'NET PROFIT'**
  String get netProfit;

  /// No description provided for @pendingRev.
  ///
  /// In en, this message translates to:
  /// **'PENDING REV'**
  String get pendingRev;

  /// No description provided for @platformCommission.
  ///
  /// In en, this message translates to:
  /// **'Platform Commission'**
  String get platformCommission;

  /// No description provided for @debtCollectionNotice.
  ///
  /// In en, this message translates to:
  /// **'You owe {amount} EGP. Collection occurs every 2 months.'**
  String debtCollectionNotice(String amount);

  /// No description provided for @hoursBookedLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours Booked'**
  String get hoursBookedLabel;

  /// No description provided for @activeBookingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed Bookings'**
  String get activeBookingsLabel;

  /// No description provided for @bookedTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Booked Today'**
  String get bookedTodayLabel;

  /// No description provided for @liveBookingsForToday.
  ///
  /// In en, this message translates to:
  /// **'Live bookings for today'**
  String get liveBookingsForToday;

  /// No description provided for @includesPlatformFee.
  ///
  /// In en, this message translates to:
  /// **'Includes {amount} EGP platform fee'**
  String includesPlatformFee(String amount);

  /// No description provided for @showMoreBtn.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMoreBtn;

  /// No description provided for @allStadiumsFilter.
  ///
  /// In en, this message translates to:
  /// **'All Stadiums'**
  String get allStadiumsFilter;

  /// No description provided for @allTimeFilter.
  ///
  /// In en, this message translates to:
  /// **'All Time '**
  String get allTimeFilter;

  /// No description provided for @noBookingsForTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'No bookings for today'**
  String get noBookingsForTodayLabel;

  /// No description provided for @collectedSticker.
  ///
  /// In en, this message translates to:
  /// **'COLLECTED'**
  String get collectedSticker;

  /// No description provided for @pendingSticker.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get pendingSticker;

  /// No description provided for @platformCutApplied.
  ///
  /// In en, this message translates to:
  /// **'5% Platform Cut Applied'**
  String get platformCutApplied;

  /// No description provided for @youHaveStadiums.
  ///
  /// In en, this message translates to:
  /// **'You have {count} stadium(s)'**
  String youHaveStadiums(int count);

  /// No description provided for @tournamentsTab.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get tournamentsTab;

  /// No description provided for @bookedTab.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get bookedTab;

  /// No description provided for @profileTab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTab;

  /// No description provided for @hiPrefix.
  ///
  /// In en, this message translates to:
  /// **'Hi'**
  String get hiPrefix;

  /// No description provided for @ownerGuestFallback.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get ownerGuestFallback;

  /// No description provided for @individualPlayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Individual Player'**
  String get individualPlayerLabel;

  /// No description provided for @teamMatchLabel.
  ///
  /// In en, this message translates to:
  /// **'Team Match'**
  String get teamMatchLabel;

  /// No description provided for @playerTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerTypeLabel;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @resetLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetLabel;

  /// No description provided for @forceStartTournament.
  ///
  /// In en, this message translates to:
  /// **'Force Start Tournament?'**
  String get forceStartTournament;

  /// No description provided for @forceStartWarning.
  ///
  /// In en, this message translates to:
  /// **'Tournament is not full ({count} / {max} teams). Are you sure you want to force start? Make sure you have 4, 8, 16, or 32 teams for the brackets to work correctly.'**
  String forceStartWarning(int count, int max);

  /// No description provided for @forceStart.
  ///
  /// In en, this message translates to:
  /// **'Force Start'**
  String get forceStart;

  /// No description provided for @drawGeneratedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Draw Generated & Tournament Started!'**
  String get drawGeneratedSuccess;

  /// No description provided for @selectTournamentWinner.
  ///
  /// In en, this message translates to:
  /// **'Select Tournament Winner'**
  String get selectTournamentWinner;

  /// No description provided for @addTeamManually.
  ///
  /// In en, this message translates to:
  /// **'Add Team Manually'**
  String get addTeamManually;

  /// No description provided for @manualRegistrationSub.
  ///
  /// In en, this message translates to:
  /// **'Register a team that signed up via phone or in-person.'**
  String get manualRegistrationSub;

  /// No description provided for @manualRegistration.
  ///
  /// In en, this message translates to:
  /// **'Manual Registration'**
  String get manualRegistration;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get statusLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'CATEGORY'**
  String get categoryLabel;

  /// No description provided for @datesLabel.
  ///
  /// In en, this message translates to:
  /// **'DATES'**
  String get datesLabel;

  /// No description provided for @teamsLabel.
  ///
  /// In en, this message translates to:
  /// **'TEAMS'**
  String get teamsLabel;

  /// No description provided for @joinedTeamsLabel.
  ///
  /// In en, this message translates to:
  /// **'Joined Teams'**
  String get joinedTeamsLabel;

  /// No description provided for @addTeam.
  ///
  /// In en, this message translates to:
  /// **'Add Team'**
  String get addTeam;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @generateDrawStart.
  ///
  /// In en, this message translates to:
  /// **'GENERATE DRAW & START'**
  String get generateDrawStart;

  /// No description provided for @manualCrownChampion.
  ///
  /// In en, this message translates to:
  /// **'MANUAL CROWN CHAMPION'**
  String get manualCrownChampion;

  /// No description provided for @tournamentBrackets.
  ///
  /// In en, this message translates to:
  /// **'Tournament Brackets'**
  String get tournamentBrackets;

  /// No description provided for @noBracketsYet.
  ///
  /// In en, this message translates to:
  /// **'Brackets not generated yet.'**
  String get noBracketsYet;

  /// No description provided for @roundOf.
  ///
  /// In en, this message translates to:
  /// **'Round of {count}'**
  String roundOf(int count);

  /// No description provided for @finalRound.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get finalRound;

  /// No description provided for @semiFinalRound.
  ///
  /// In en, this message translates to:
  /// **'Semi Final'**
  String get semiFinalRound;

  /// No description provided for @quarterFinalRound.
  ///
  /// In en, this message translates to:
  /// **'Quarter Final'**
  String get quarterFinalRound;

  /// No description provided for @matchScheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Match scheduled for {time}'**
  String matchScheduledFor(String time);

  /// No description provided for @waitingPreviousWinners.
  ///
  /// In en, this message translates to:
  /// **'Waiting for previous round winners...'**
  String get waitingPreviousWinners;

  /// No description provided for @updateScore.
  ///
  /// In en, this message translates to:
  /// **'Update Score'**
  String get updateScore;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @drawNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Draws not allowed in knockout!'**
  String get drawNotAllowed;

  /// No description provided for @notScheduled.
  ///
  /// In en, this message translates to:
  /// **'Not Scheduled'**
  String get notScheduled;

  /// No description provided for @editLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editLabel;

  /// No description provided for @editTournamentTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Tournament'**
  String get editTournamentTitle;

  /// No description provided for @createTournamentTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Tournament'**
  String get createTournamentTitle;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @updateChanges.
  ///
  /// In en, this message translates to:
  /// **'Update Changes'**
  String get updateChanges;

  /// No description provided for @nextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextButton;

  /// No description provided for @basicsStep.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get basicsStep;

  /// No description provided for @systemStep.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemStep;

  /// No description provided for @schedulingStep.
  ///
  /// In en, this message translates to:
  /// **'Scheduling'**
  String get schedulingStep;

  /// No description provided for @quickTemplates.
  ///
  /// In en, this message translates to:
  /// **'Quick Templates'**
  String get quickTemplates;

  /// No description provided for @choosePresetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a preset template to quickly configure rules'**
  String get choosePresetSubtitle;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @tournamentNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Tournament Name'**
  String get tournamentNameLabel;

  /// No description provided for @sportTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Sport Type'**
  String get sportTypeLabel;

  /// No description provided for @entryFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry Fee'**
  String get entryFeeLabel;

  /// No description provided for @tournamentSystemLabel.
  ///
  /// In en, this message translates to:
  /// **'Tournament System'**
  String get tournamentSystemLabel;

  /// No description provided for @knockoutType.
  ///
  /// In en, this message translates to:
  /// **'Knockout'**
  String get knockoutType;

  /// No description provided for @leagueType.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get leagueType;

  /// No description provided for @maxTeamsLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Teams'**
  String get maxTeamsLabel;

  /// No description provided for @startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDateLabel;

  /// No description provided for @endDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDateLabel;

  /// No description provided for @matchDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Match Duration (min)'**
  String get matchDurationLabel;

  /// No description provided for @grandPrizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grand Prize'**
  String get grandPrizeLabel;

  /// No description provided for @myStadiumsTab.
  ///
  /// In en, this message translates to:
  /// **'My Stadiums'**
  String get myStadiumsTab;

  /// No description provided for @stadiumsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No stadiums found'**
  String get stadiumsEmptyTitle;

  /// No description provided for @stadiumsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap add stadium to list your first facility'**
  String get stadiumsEmptySubtitle;

  /// No description provided for @addStadiumLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Stadium'**
  String get addStadiumLabel;

  /// No description provided for @identityPendingVerification.
  ///
  /// In en, this message translates to:
  /// **'Identity Verification'**
  String get identityPendingVerification;

  /// No description provided for @bookedManually.
  ///
  /// In en, this message translates to:
  /// **'Booked Manually'**
  String get bookedManually;

  /// No description provided for @noWorkingHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'No working hours set'**
  String get noWorkingHoursTitle;

  /// No description provided for @noWorkingHoursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please configure stadium opening hours first'**
  String get noWorkingHoursSubtitle;

  /// No description provided for @breakTime.
  ///
  /// In en, this message translates to:
  /// **'Break Time'**
  String get breakTime;

  /// No description provided for @addManualBooking.
  ///
  /// In en, this message translates to:
  /// **'Add Manual Booking'**
  String get addManualBooking;

  /// No description provided for @closedBadge.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closedBadge;

  /// No description provided for @openBadge.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openBadge;

  /// No description provided for @collectedStatusAuto.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get collectedStatusAuto;

  /// No description provided for @pendingStatusAuto.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingStatusAuto;

  /// No description provided for @enterCustomerNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter customer name'**
  String get enterCustomerNameError;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @friendsRequiredNote.
  ///
  /// In en, this message translates to:
  /// **'Note: You need at least 6 members to create a team'**
  String get friendsRequiredNote;

  /// No description provided for @createTeamTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Team'**
  String get createTeamTitle;

  /// No description provided for @teamNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Team Name'**
  String get teamNameLabel;

  /// No description provided for @uploadLogo.
  ///
  /// In en, this message translates to:
  /// **'Upload Logo'**
  String get uploadLogo;

  /// No description provided for @changeLogo.
  ///
  /// In en, this message translates to:
  /// **'Change Logo'**
  String get changeLogo;

  /// No description provided for @teamMembers.
  ///
  /// In en, this message translates to:
  /// **'Team Members'**
  String get teamMembers;

  /// No description provided for @addMemberBtn.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get addMemberBtn;

  /// No description provided for @noMembersAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No members added yet.'**
  String get noMembersAddedYet;

  /// No description provided for @cancelBtn.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelBtn;

  /// No description provided for @confirmBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmBtn;

  /// No description provided for @sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get sports;

  /// No description provided for @priceRange.
  ///
  /// In en, this message translates to:
  /// **'Price Range'**
  String get priceRange;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @selectSports.
  ///
  /// In en, this message translates to:
  /// **'Select Sports'**
  String get selectSports;

  /// No description provided for @minRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum Rating'**
  String get minRating;

  /// No description provided for @anyRating.
  ///
  /// In en, this message translates to:
  /// **'Any Rating'**
  String get anyRating;

  /// No description provided for @stars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get stars;

  /// No description provided for @stadiumServices.
  ///
  /// In en, this message translates to:
  /// **'Stadium Services'**
  String get stadiumServices;

  /// No description provided for @badgeUnlockedStatus.
  ///
  /// In en, this message translates to:
  /// **'Badge Unlocked!'**
  String get badgeUnlockedStatus;

  /// No description provided for @badgeLockedStatus.
  ///
  /// In en, this message translates to:
  /// **'Badge Locked'**
  String get badgeLockedStatus;

  /// No description provided for @gotItBtn.
  ///
  /// In en, this message translates to:
  /// **'Got It'**
  String get gotItBtn;

  /// No description provided for @bookingDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking Details'**
  String get bookingDetailsTitle;

  /// No description provided for @manualBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Booking'**
  String get manualBookingTitle;

  /// No description provided for @timeAndStadium.
  ///
  /// In en, this message translates to:
  /// **'Time & Stadium'**
  String get timeAndStadium;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerName;

  /// No description provided for @enterNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterNameHint;

  /// No description provided for @phoneOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Phone (Optional)'**
  String get phoneOptionalHint;

  /// No description provided for @internalNotes.
  ///
  /// In en, this message translates to:
  /// **'Internal Notes'**
  String get internalNotes;

  /// No description provided for @internalNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Internal Notes Hint'**
  String get internalNotesHint;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// No description provided for @tournamentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get tournamentsTitle;

  /// No description provided for @coming.
  ///
  /// In en, this message translates to:
  /// **'Coming'**
  String get coming;

  /// No description provided for @ongoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get ongoing;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// No description provided for @noTournamentsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Tournaments'**
  String get noTournamentsTitle;

  /// No description provided for @noTournamentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a tournament to see it here'**
  String get noTournamentsSubtitle;

  /// No description provided for @createYourFirst.
  ///
  /// In en, this message translates to:
  /// **'Create Your First'**
  String get createYourFirst;

  /// No description provided for @shareTournamentText.
  ///
  /// In en, this message translates to:
  /// **'Check out {name} starting from {startDate} to {endDate}! Grand Prize: {prize} EGP, Entry Fee: {fee} EGP.'**
  String shareTournamentText(
    String name,
    String startDate,
    String endDate,
    int prize,
    int fee,
  );

  /// No description provided for @teamsJoinedCount.
  ///
  /// In en, this message translates to:
  /// **'{current}/{max} Teams'**
  String teamsJoinedCount(int current, int max);

  /// No description provided for @actualLabel.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get actualLabel;

  /// No description provided for @platformCommissionLabel.
  ///
  /// In en, this message translates to:
  /// **'Platform Commission'**
  String get platformCommissionLabel;

  /// No description provided for @bookedHours.
  ///
  /// In en, this message translates to:
  /// **'Booked Hours'**
  String get bookedHours;

  /// No description provided for @stadiumApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Stadium Approved'**
  String get stadiumApprovedTitle;

  /// No description provided for @stadiumApprovedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{name} has been approved!'**
  String stadiumApprovedSubtitle(String name);

  /// No description provided for @dismissBtn.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissBtn;

  /// No description provided for @createTournament.
  ///
  /// In en, this message translates to:
  /// **'Create Tournament'**
  String get createTournament;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get profileSettings;

  /// No description provided for @profileAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountLabel;

  /// No description provided for @profileAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account'**
  String get profileAccountSubtitle;

  /// No description provided for @profilePreferencesLabel.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profilePreferencesLabel;

  /// No description provided for @profileNotificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotificationsLabel;

  /// No description provided for @profileNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage notifications'**
  String get profileNotificationsSubtitle;

  /// No description provided for @profilePrivacyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get profilePrivacyLabel;

  /// No description provided for @profilePrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage privacy settings'**
  String get profilePrivacySubtitle;

  /// No description provided for @profileLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguageLabel;

  /// No description provided for @profileLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change application language'**
  String get profileLanguageSubtitle;

  /// No description provided for @profileSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSupportLabel;

  /// No description provided for @profileHelpCenterLabel.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get profileHelpCenterLabel;

  /// No description provided for @profileHelpCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get support and help'**
  String get profileHelpCenterSubtitle;

  /// No description provided for @profileLogoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profileLogoutLabel;

  /// No description provided for @profileLogoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of your account'**
  String get profileLogoutSubtitle;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @personalType.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personalType;

  /// No description provided for @teamType.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get teamType;

  /// No description provided for @challengeType.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get challengeType;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we will send you a link to reset your password.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @resetPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent! Check your inbox.'**
  String get resetPasswordSuccess;

  /// No description provided for @resetPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email. Please check the address and try again.'**
  String get resetPasswordError;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @selectImageSource.
  ///
  /// In en, this message translates to:
  /// **'Select Image Source'**
  String get selectImageSource;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @docUploadedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Document uploaded successfully!'**
  String get docUploadedSuccess;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(String error);

  /// No description provided for @uploadCommRegisterRequired.
  ///
  /// In en, this message translates to:
  /// **'Please upload your Commercial Register before continuing.'**
  String get uploadCommRegisterRequired;

  /// No description provided for @uploadIdFrontRequired.
  ///
  /// In en, this message translates to:
  /// **'Please upload the front side of your National ID.'**
  String get uploadIdFrontRequired;

  /// No description provided for @uploadIdBackRequired.
  ///
  /// In en, this message translates to:
  /// **'Please upload the back side of your National ID.'**
  String get uploadIdBackRequired;

  /// No description provided for @regCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration Complete! '**
  String get regCompleteTitle;

  /// No description provided for @regCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Your documents have been submitted for review. You can now access your dashboard and manage your stadiums.'**
  String get regCompleteBody;

  /// No description provided for @goToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to Dashboard'**
  String get goToDashboard;

  /// No description provided for @saveInfoFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save your information. Please check your connection and try again.'**
  String get saveInfoFailed;

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification Pending'**
  String get verificationPending;

  /// No description provided for @reviewingDocs.
  ///
  /// In en, this message translates to:
  /// **'We are reviewing your submitted documents.'**
  String get reviewingDocs;

  /// No description provided for @submissionStatus.
  ///
  /// In en, this message translates to:
  /// **'Submission Status'**
  String get submissionStatus;

  /// No description provided for @nationalIdFront.
  ///
  /// In en, this message translates to:
  /// **'National ID Front'**
  String get nationalIdFront;

  /// No description provided for @nationalIdBack.
  ///
  /// In en, this message translates to:
  /// **'National ID Back'**
  String get nationalIdBack;

  /// No description provided for @reviewDurationText.
  ///
  /// In en, this message translates to:
  /// **'The review process typically takes up to 24 hours. We will notify you once your account has been verified and activated.'**
  String get reviewDurationText;

  /// No description provided for @refreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh Status'**
  String get refreshStatus;

  /// No description provided for @verifiedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account verified successfully!'**
  String get verifiedSuccess;

  /// No description provided for @stillUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Documents are still under review.'**
  String get stillUnderReview;

  /// No description provided for @refreshStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh status: {error}'**
  String refreshStatusFailed(String error);

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get submitted;

  /// No description provided for @ownerInformationTitle.
  ///
  /// In en, this message translates to:
  /// **'Owner information'**
  String get ownerInformationTitle;

  /// No description provided for @clickToUploadRegister.
  ///
  /// In en, this message translates to:
  /// **'Click to upload commercial register'**
  String get clickToUploadRegister;

  /// No description provided for @uploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Uploaded Successfully'**
  String get uploadedSuccessfully;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & Continue'**
  String get saveAndContinue;

  /// No description provided for @uploadNationalIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload national ID'**
  String get uploadNationalIdTitle;

  /// No description provided for @submitDocuments.
  ///
  /// In en, this message translates to:
  /// **'Submit Documents'**
  String get submitDocuments;

  /// No description provided for @facilityOnboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your stadium and verify your account to start receiving bookings.'**
  String get facilityOnboardingSubtitle;

  /// No description provided for @addedStadiumsCount.
  ///
  /// In en, this message translates to:
  /// **'Your Stadiums ({count})'**
  String addedStadiumsCount(int count);

  /// No description provided for @noStadiumsAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No stadiums added yet'**
  String get noStadiumsAddedYet;

  /// No description provided for @addStadiumButtonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register your new stadium details'**
  String get addStadiumButtonSubtitle;

  /// No description provided for @confirmContinueBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Continue'**
  String get confirmContinueBtn;

  /// No description provided for @confirmContinueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload legal documents and ID'**
  String get confirmContinueSubtitle;

  /// No description provided for @addStadiumFirstError.
  ///
  /// In en, this message translates to:
  /// **'Please add a stadium first'**
  String get addStadiumFirstError;

  /// No description provided for @blockedBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Restricted '**
  String get blockedBannerTitle;

  /// No description provided for @blockedBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account has been restricted. Action capability is limited.'**
  String get blockedBannerSubtitle;

  /// No description provided for @geographicFallbackBanner.
  ///
  /// In en, this message translates to:
  /// **'No stadiums registered in your area yet .. here are the closest available stadiums in other areas.'**
  String get geographicFallbackBanner;

  /// No description provided for @teamMemberDeleteLockError.
  ///
  /// In en, this message translates to:
  /// **'Cannot remove team members while there is an active match or ongoing tournament to avoid penalizing the team with a forfeit '**
  String get teamMemberDeleteLockError;

  /// No description provided for @memberRemovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Team member has been removed successfully.'**
  String get memberRemovedSuccess;

  /// No description provided for @preliminaryRound.
  ///
  /// In en, this message translates to:
  /// **'Preliminary Round'**
  String get preliminaryRound;

  /// No description provided for @byeBadge.
  ///
  /// In en, this message translates to:
  /// **'[ Auto Qualified - BYE ]'**
  String get byeBadge;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @unpaidTeamsWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: The following teams have not paid the subscription fee: {teams}. Do you want to proceed anyway?'**
  String unpaidTeamsWarning(String teams);

  /// No description provided for @proceedAnyway.
  ///
  /// In en, this message translates to:
  /// **'Proceed anyway'**
  String get proceedAnyway;

  /// No description provided for @welcomePage1Title.
  ///
  /// In en, this message translates to:
  /// **'Live the Pro Vibe'**
  String get welcomePage1Title;

  /// No description provided for @welcomePage1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your pitch is ready, and new challenges await. Book your match with a single tap and head towards glory.'**
  String get welcomePage1Subtitle;

  /// No description provided for @welcomePage2Title.
  ///
  /// In en, this message translates to:
  /// **'Be the Area Champion'**
  String get welcomePage2Title;

  /// No description provided for @welcomePage2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Form your squad, compete in major tournaments, and climb the leaderboard to be the best in your region.'**
  String get welcomePage2Subtitle;

  /// No description provided for @welcomePage3Title.
  ///
  /// In en, this message translates to:
  /// **'Ready to Start?!'**
  String get welcomePage3Title;

  /// No description provided for @welcomePage3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your role now. Join as a player to take on challenges, or as an owner to manage your stadium smartly.'**
  String get welcomePage3Subtitle;

  /// No description provided for @fairPlayBannedTitle.
  ///
  /// In en, this message translates to:
  /// **'Banned from Ranked Challenges'**
  String get fairPlayBannedTitle;

  /// No description provided for @fairPlayBannedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your team\'s Fair Play score is {score}/100. Minimum required is 40%.'**
  String fairPlayBannedSubtitle(int score);

  /// No description provided for @fairPlayBannedError.
  ///
  /// In en, this message translates to:
  /// **'Your team\'s Fair Play score is below 40%. Cannot participate in ranked challenges.'**
  String get fairPlayBannedError;

  /// No description provided for @createTeamFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Team First'**
  String get createTeamFirstTitle;

  /// No description provided for @createTeamFirstContent.
  ///
  /// In en, this message translates to:
  /// **'You must create your own team to be able to create a booking and request other players to join.'**
  String get createTeamFirstContent;

  /// No description provided for @createTeamNow.
  ///
  /// In en, this message translates to:
  /// **'Create Team Now'**
  String get createTeamNow;

  /// No description provided for @findPlayersWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Important Warning'**
  String get findPlayersWarningTitle;

  /// No description provided for @findPlayersWarningContent.
  ///
  /// In en, this message translates to:
  /// **'The platform does not guarantee payment for absent players (No-Show). Full financial responsibility lies with the booking owner.'**
  String get findPlayersWarningContent;

  /// No description provided for @completeTeamButton.
  ///
  /// In en, this message translates to:
  /// **'Complete Team'**
  String get completeTeamButton;

  /// No description provided for @createTeamButton.
  ///
  /// In en, this message translates to:
  /// **'Create Team'**
  String get createTeamButton;

  /// No description provided for @completeYourPlayerProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile as Player'**
  String get completeYourPlayerProfile;

  /// No description provided for @completeYourOwnerProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile as Stadium Owner'**
  String get completeYourOwnerProfile;

  /// No description provided for @playAndContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Playing & Contact Info'**
  String get playAndContactInfo;

  /// No description provided for @ownerContactAndPayoutInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact & Financial Settlement Info'**
  String get ownerContactAndPayoutInfo;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completeRegistration;

  /// No description provided for @locationAutoDetectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not determine your location automatically. Please select your governorate manually.'**
  String get locationAutoDetectFailed;

  /// No description provided for @enterFirstName.
  ///
  /// In en, this message translates to:
  /// **'Enter first name'**
  String get enterFirstName;

  /// No description provided for @enterLastName.
  ///
  /// In en, this message translates to:
  /// **'Enter last name'**
  String get enterLastName;

  /// No description provided for @payoutInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout & Settlement Details'**
  String get payoutInfoTitle;

  /// No description provided for @payoutInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please provide at least one method to receive pitch booking revenues from VSP.'**
  String get payoutInfoSubtitle;

  /// No description provided for @instapayAddress.
  ///
  /// In en, this message translates to:
  /// **'InstaPay IPN Address'**
  String get instapayAddress;

  /// No description provided for @walletNumber.
  ///
  /// In en, this message translates to:
  /// **'E-Wallet Number (Vodafone/Etisalat/Orange)'**
  String get walletNumber;

  /// No description provided for @bankAccountIban.
  ///
  /// In en, this message translates to:
  /// **'Bank Account / IBAN & Beneficiary Name'**
  String get bankAccountIban;

  /// No description provided for @cancelRegistrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel registration & sign out?'**
  String get cancelRegistrationTitle;

  /// No description provided for @cancelRegistrationContent.
  ///
  /// In en, this message translates to:
  /// **'Entered data will not be saved.'**
  String get cancelRegistrationContent;

  /// No description provided for @cancelAndSignOut.
  ///
  /// In en, this message translates to:
  /// **'Cancel & Sign Out'**
  String get cancelAndSignOut;

  /// No description provided for @continueRegistration.
  ///
  /// In en, this message translates to:
  /// **'Continue Registration'**
  String get continueRegistration;

  /// No description provided for @selectPreferredPosition.
  ///
  /// In en, this message translates to:
  /// **'Please select your preferred position'**
  String get selectPreferredPosition;

  /// No description provided for @atLeastOnePayoutMethod.
  ///
  /// In en, this message translates to:
  /// **'Please provide at least one payout method'**
  String get atLeastOnePayoutMethod;

  /// No description provided for @iAgreeTo.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get iAgreeTo;

  /// No description provided for @pleaseAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Terms of Service & Privacy Policy to continue.'**
  String get pleaseAgreeToTerms;

  /// No description provided for @refundNoticeAuto.
  ///
  /// In en, this message translates to:
  /// **'Your {type} ({amount}) will be automatically refunded to your card or wallet within minutes.'**
  String refundNoticeAuto(String type, String amount);

  /// No description provided for @refundDeposit.
  ///
  /// In en, this message translates to:
  /// **'deposit'**
  String get refundDeposit;

  /// No description provided for @refundFullPayment.
  ///
  /// In en, this message translates to:
  /// **'payment'**
  String get refundFullPayment;

  /// No description provided for @paymentGatewayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to payment gateway. Please try again later.'**
  String get paymentGatewayUnavailable;

  /// No description provided for @verifyPaymentNow.
  ///
  /// In en, this message translates to:
  /// **'Verify Payment Status Now'**
  String get verifyPaymentNow;

  /// No description provided for @verifyingPayment.
  ///
  /// In en, this message translates to:
  /// **'Verifying payment status...'**
  String get verifyingPayment;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
