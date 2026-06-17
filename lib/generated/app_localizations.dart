import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ne.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('en'),
    Locale('ne')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sampada'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nepal Heritage Explorer'**
  String get appSubtitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navGuide.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get navGuide;

  /// No description provided for @navEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navEvents;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get navDownloads;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get navBookmarks;

  /// No description provided for @btnSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btnSave;

  /// No description provided for @btnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btnCancel;

  /// No description provided for @btnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get btnConfirm;

  /// No description provided for @btnSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get btnSubmit;

  /// No description provided for @btnTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get btnTryAgain;

  /// No description provided for @btnSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get btnSignOut;

  /// No description provided for @btnSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get btnSignIn;

  /// No description provided for @btnDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get btnDownload;

  /// No description provided for @btnDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get btnDelete;

  /// No description provided for @btnEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get btnEdit;

  /// No description provided for @btnShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get btnShare;

  /// No description provided for @btnBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get btnBack;

  /// No description provided for @btnReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read More'**
  String get btnReadMore;

  /// No description provided for @btnShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get btnShowLess;

  /// No description provided for @btnTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get btnTranslate;

  /// No description provided for @btnOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get btnOriginal;

  /// No description provided for @btnBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get btnBookmark;

  /// No description provided for @btnRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove Bookmark'**
  String get btnRemoveBookmark;

  /// No description provided for @btnBookGuide.
  ///
  /// In en, this message translates to:
  /// **'Book Guide'**
  String get btnBookGuide;

  /// No description provided for @btnViewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on Map'**
  String get btnViewOnMap;

  /// No description provided for @btnStartAudioGuide.
  ///
  /// In en, this message translates to:
  /// **'Start Audio Guide'**
  String get btnStartAudioGuide;

  /// No description provided for @btnDownloadOffline.
  ///
  /// In en, this message translates to:
  /// **'Download for Offline'**
  String get btnDownloadOffline;

  /// No description provided for @btnWriteReview.
  ///
  /// In en, this message translates to:
  /// **'Write a Review'**
  String get btnWriteReview;

  /// No description provided for @btnSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get btnSubmitReview;

  /// No description provided for @btnSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get btnSelectDate;

  /// No description provided for @btnApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get btnApply;

  /// No description provided for @btnClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get btnClearFilter;

  /// No description provided for @catAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get catAll;

  /// No description provided for @catTemple.
  ///
  /// In en, this message translates to:
  /// **'Temples'**
  String get catTemple;

  /// No description provided for @catStupa.
  ///
  /// In en, this message translates to:
  /// **'Stupas'**
  String get catStupa;

  /// No description provided for @catPalace.
  ///
  /// In en, this message translates to:
  /// **'Palaces'**
  String get catPalace;

  /// No description provided for @catDurbar.
  ///
  /// In en, this message translates to:
  /// **'Durbar'**
  String get catDurbar;

  /// No description provided for @catMonument.
  ///
  /// In en, this message translates to:
  /// **'Monuments'**
  String get catMonument;

  /// No description provided for @catMuseum.
  ///
  /// In en, this message translates to:
  /// **'Museums'**
  String get catMuseum;

  /// No description provided for @catMonastery.
  ///
  /// In en, this message translates to:
  /// **'Monasteries'**
  String get catMonastery;

  /// No description provided for @catLake.
  ///
  /// In en, this message translates to:
  /// **'Lakes'**
  String get catLake;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSection;

  /// No description provided for @settingsStorageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage & Data'**
  String get settingsStorageSection;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get settingsLightMode;

  /// No description provided for @settingsSystemMode.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settingsSystemMode;

  /// No description provided for @settingsTextSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsTextSmall;

  /// No description provided for @settingsTextMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsTextMedium;

  /// No description provided for @settingsTextLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsTextLarge;

  /// No description provided for @settingsPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get settingsPushNotifications;

  /// No description provided for @settingsNearbySiteAlerts.
  ///
  /// In en, this message translates to:
  /// **'Nearby Site Alerts'**
  String get settingsNearbySiteAlerts;

  /// No description provided for @settingsOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get settingsOfflineMode;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get settingsCacheCleared;

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network.'**
  String get errNetwork;

  /// No description provided for @errServer.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errServer;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get errNotFound;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errUnknown;

  /// No description provided for @errAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please sign in again.'**
  String get errAuthFailed;

  /// No description provided for @errLocationDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled.'**
  String get errLocationDisabled;

  /// No description provided for @errPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied.'**
  String get errPermissionDenied;

  /// No description provided for @errCacheEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cached data available. Please connect to the internet.'**
  String get errCacheEmpty;

  /// No description provided for @errTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation unavailable.'**
  String get errTranslation;

  /// No description provided for @errInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields.'**
  String get errInvalidInput;

  /// No description provided for @errReviewMinLength.
  ///
  /// In en, this message translates to:
  /// **'Review must be at least 10 characters.'**
  String get errReviewMinLength;

  /// No description provided for @sectionNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby Heritage Sites'**
  String get sectionNearby;

  /// No description provided for @sectionFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured Sites'**
  String get sectionFeatured;

  /// No description provided for @sectionUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Cultural Events'**
  String get sectionUpcomingEvents;

  /// No description provided for @sectionDistricts.
  ///
  /// In en, this message translates to:
  /// **'Browse by District'**
  String get sectionDistricts;

  /// No description provided for @sectionReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get sectionReviews;

  /// No description provided for @sectionGuides.
  ///
  /// In en, this message translates to:
  /// **'Local Guides'**
  String get sectionGuides;

  /// No description provided for @sectionGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get sectionGallery;

  /// No description provided for @sectionAboutSite.
  ///
  /// In en, this message translates to:
  /// **'About this Site'**
  String get sectionAboutSite;

  /// No description provided for @sectionNearbyAttractions.
  ///
  /// In en, this message translates to:
  /// **'Nearby Attractions'**
  String get sectionNearbyAttractions;

  /// No description provided for @sectionOpeningHours.
  ///
  /// In en, this message translates to:
  /// **'Opening Hours'**
  String get sectionOpeningHours;

  /// No description provided for @sectionHowToReach.
  ///
  /// In en, this message translates to:
  /// **'How to Reach'**
  String get sectionHowToReach;

  /// No description provided for @sectionDownloads.
  ///
  /// In en, this message translates to:
  /// **'Offline Packs'**
  String get sectionDownloads;

  /// No description provided for @sectionCurrentEvents.
  ///
  /// In en, this message translates to:
  /// **'Current Cultural Events'**
  String get sectionCurrentEvents;

  /// No description provided for @sectionNearbyFestivals.
  ///
  /// In en, this message translates to:
  /// **'Nearby & Upcoming Festivals'**
  String get sectionNearbyFestivals;

  /// No description provided for @emptyBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet.\nTap ♥ on any site to save it.'**
  String get emptyBookmarks;

  /// No description provided for @emptyVisitHistory.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t visited any sites yet.'**
  String get emptyVisitHistory;

  /// No description provided for @emptyNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get emptyNotifications;

  /// No description provided for @emptyEvents.
  ///
  /// In en, this message translates to:
  /// **'No events found for this period.'**
  String get emptyEvents;

  /// No description provided for @emptyDownloads.
  ///
  /// In en, this message translates to:
  /// **'No offline packs downloaded.'**
  String get emptyDownloads;

  /// No description provided for @emptyReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet. Be the first to review!'**
  String get emptyReviews;

  /// No description provided for @emptyGuides.
  ///
  /// In en, this message translates to:
  /// **'No guides available in this area.'**
  String get emptyGuides;

  /// No description provided for @emptySearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results found for your search.'**
  String get emptySearchResults;

  /// No description provided for @noSitesFound.
  ///
  /// In en, this message translates to:
  /// **'No heritage sites found.'**
  String get noSitesFound;

  /// No description provided for @siteNotFound.
  ///
  /// In en, this message translates to:
  /// **'Heritage site not found.'**
  String get siteNotFound;

  /// No description provided for @unescoSite.
  ///
  /// In en, this message translates to:
  /// **'UNESCO World Heritage Site'**
  String get unescoSite;

  /// No description provided for @ratingLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get ratingLabel;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String reviewsCount(int count);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{distance} km away'**
  String distanceKm(String distance);

  /// No description provided for @establishedYear.
  ///
  /// In en, this message translates to:
  /// **'Est. {year}'**
  String establishedYear(int year);

  /// No description provided for @labelAvailableOffline.
  ///
  /// In en, this message translates to:
  /// **'Available Offline'**
  String get labelAvailableOffline;

  /// No description provided for @labelVisited.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get labelVisited;

  /// No description provided for @labelVerifiedGuide.
  ///
  /// In en, this message translates to:
  /// **'Verified Guide'**
  String get labelVerifiedGuide;

  /// No description provided for @labelPerDay.
  ///
  /// In en, this message translates to:
  /// **'/ day'**
  String get labelPerDay;

  /// No description provided for @labelPerHalfDay.
  ///
  /// In en, this message translates to:
  /// **'/ half day'**
  String get labelPerHalfDay;

  /// No description provided for @labelLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get labelLanguages;

  /// No description provided for @labelSpecializations.
  ///
  /// In en, this message translates to:
  /// **'Specializations'**
  String get labelSpecializations;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notifMarkAllRead;

  /// No description provided for @notifFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notifFilterAll;

  /// No description provided for @notifFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notifFilterUnread;

  /// No description provided for @notifFilterEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get notifFilterEvents;

  /// No description provided for @notifTypeEventNearby.
  ///
  /// In en, this message translates to:
  /// **'Event Nearby'**
  String get notifTypeEventNearby;

  /// No description provided for @notifTypeHeritageUpdate.
  ///
  /// In en, this message translates to:
  /// **'Heritage Update'**
  String get notifTypeHeritageUpdate;

  /// No description provided for @notifTypeBookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking Confirmed'**
  String get notifTypeBookingConfirmed;

  /// No description provided for @notifTypeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notifTypeSystem;

  /// No description provided for @packReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get packReady;

  /// No description provided for @packBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building...'**
  String get packBuilding;

  /// No description provided for @packNotBuilt.
  ///
  /// In en, this message translates to:
  /// **'Not Built'**
  String get packNotBuilt;

  /// No description provided for @packError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get packError;

  /// No description provided for @packSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String packSizeMb(String size);

  /// No description provided for @reviewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Share your experience...'**
  String get reviewPlaceholder;

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating...'**
  String get translating;

  /// No description provided for @nearbyHeritageTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby Heritage Sites'**
  String get nearbyHeritageTitle;

  /// No description provided for @loadingText.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingText;

  /// No description provided for @pashupatinath.
  ///
  /// In en, this message translates to:
  /// **'Pashupatinath'**
  String get pashupatinath;

  /// No description provided for @lumbini.
  ///
  /// In en, this message translates to:
  /// **'Lumbini'**
  String get lumbini;

  /// No description provided for @swayambhunath.
  ///
  /// In en, this message translates to:
  /// **'Swayambhunath'**
  String get swayambhunath;

  /// No description provided for @discoverNepal.
  ///
  /// In en, this message translates to:
  /// **'Discover Nepal'**
  String get discoverNepal;

  /// No description provided for @onboardingDesc.
  ///
  /// In en, this message translates to:
  /// **'Explore the rich cultural heritage and ancient monuments of Nepal.'**
  String get onboardingDesc;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @joinJourney.
  ///
  /// In en, this message translates to:
  /// **'Join the Journey'**
  String get joinJourney;

  /// No description provided for @authDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in to bookmark your favorite sites and track your visits.'**
  String get authDesc;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleSignIn;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @temples.
  ///
  /// In en, this message translates to:
  /// **'Temples'**
  String get temples;

  /// No description provided for @stupas.
  ///
  /// In en, this message translates to:
  /// **'Stupas'**
  String get stupas;

  /// No description provided for @palaces.
  ///
  /// In en, this message translates to:
  /// **'Palaces'**
  String get palaces;

  /// No description provided for @monuments.
  ///
  /// In en, this message translates to:
  /// **'Monuments'**
  String get monuments;

  /// No description provided for @featuredSites.
  ///
  /// In en, this message translates to:
  /// **'Featured Sites'**
  String get featuredSites;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @browseByDistrict.
  ///
  /// In en, this message translates to:
  /// **'Browse by District'**
  String get browseByDistrict;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @visitHistory.
  ///
  /// In en, this message translates to:
  /// **'Visit History'**
  String get visitHistory;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @manageDownloads.
  ///
  /// In en, this message translates to:
  /// **'Manage Downloads'**
  String get manageDownloads;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get textSize;

  /// No description provided for @autoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get autoSync;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @aboutSampada.
  ///
  /// In en, this message translates to:
  /// **'About Sampada'**
  String get aboutSampada;
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
      <String>['en', 'ne'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ne':
      return AppLocalizationsNe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
