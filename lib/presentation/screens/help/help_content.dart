// Static Help Center content. Kept as plain data so screens stay presentational
// and the copy can be edited (or later moved to a CMS endpoint) in one place.

// Where support requests go. Mirrors AboutScreen so every route reaches one inbox.
const String helpSupportEmail = 'rokayaprabin11@gmail.com';
const String helpSupportPhone = '+977 9800000000';
const String helpOfficeHours = 'Sun–Fri, 10:00 AM – 5:00 PM (NPT)';
const String helpAppVersion = 'v2.4.0';

class HelpFaq {
  final String question;
  final String answer;
  const HelpFaq(this.question, this.answer);
}

class HelpFaqCategory {
  final String label;
  final List<HelpFaq> items;
  const HelpFaqCategory(this.label, this.items);
}

const helpFaqs = <HelpFaqCategory>[
  HelpFaqCategory('Booking', [
    HelpFaq('How do I book a guide?',
        'Open a heritage site or event, tap "Find a Guide," and choose from verified '
            'local guides by rating, language and price. Confirm the date to send a '
            'booking request.'),
    HelpFaq('How do I cancel?',
        'Go to My Bookings, open the booking, and tap Cancel Booking. Cancellations '
            'made more than 24 hours ahead are handled per the guide\'s policy.'),
    HelpFaq('How do I pay my guide?',
        'After the tour is marked complete, open the booking and submit your payment '
            'proof (eSewa, Khalti, Fonepay or cash). The guide confirms receipt and a '
            'receipt is issued — Sampada never holds your money.'),
  ]),
  HelpFaqCategory('App settings', [
    HelpFaq('How do I change language?',
        'Go to Profile > Settings > Language and choose between English and Nepali. '
            'The interface and content switch immediately.'),
    HelpFaq('How does offline mode work?',
        'Download a heritage site before you travel from its detail page. Downloaded '
            'content and on-device search stay available with no signal.'),
    HelpFaq('Why am I not getting notifications?',
        'Enable Push Notifications in Settings, and allow notifications for Sampada in '
            'your phone\'s system settings. Set the app to Unrestricted battery so '
            'reminders arrive while the screen is off.'),
  ]),
];

class HelpArticle {
  final String title;
  final String problem;
  final List<String> causes;
  final List<String> steps;
  const HelpArticle({
    required this.title,
    required this.problem,
    required this.causes,
    required this.steps,
  });
}

const helpArticles = <String, HelpArticle>{
  'gps': HelpArticle(
    title: 'GPS not working',
    problem: 'Your location doesn\'t appear on the map, or the blue dot is missing '
        'entirely near a heritage site.',
    causes: [
      'Location permission is off for Sampada',
      'Device location services are disabled',
      'You\'re indoors or in a valley with weak signal',
    ],
    steps: [
      'Open your phone\'s Settings > Apps > Sampada > Permissions and set Location to "Allow all the time."',
      'Turn on Location/GPS from your quick settings panel.',
      'Step outside or near a window and wait 15–20 seconds for a signal lock.',
      'Restart the app if the dot still doesn\'t appear.',
    ],
  ),
  'notif': HelpArticle(
    title: 'Notifications missing',
    problem: 'You\'re not receiving alerts for bookings, guide updates or nearby events.',
    causes: [
      'Notifications are disabled for Sampada in system settings',
      'Battery optimization is pausing background activity',
      'You\'re signed out or your session expired',
    ],
    steps: [
      'Go to Settings > Apps > Sampada > Notifications and enable all categories.',
      'Under Battery, set Sampada to "Unrestricted" so it can run in the background.',
      'Open the app and confirm you\'re still signed in under Profile.',
      'Toggle Push Notifications off and on in Profile > Settings.',
    ],
  ),
  'login': HelpArticle(
    title: 'Can\'t login',
    problem: 'Sign-in fails, hangs on a loading screen, or shows an error you believe '
        'is wrong.',
    causes: [
      'Incorrect password or expired reset link',
      'Poor internet connectivity',
      'Email not yet verified',
    ],
    steps: [
      'Check your internet connection and try switching between Wi-Fi and mobile data.',
      'Tap "Forgot Password" to reset via your registered email.',
      'Open the verification link sent to your email before signing in.',
      'Update the app to the latest version and try again.',
    ],
  ),
  'offline': HelpArticle(
    title: 'Offline content unavailable',
    problem: 'A previously downloaded heritage site won\'t open, or shows old data '
        'once you\'re offline.',
    causes: [
      'Download was interrupted before it finished',
      'Device storage is low',
      'Cached data is outdated and needs re-syncing',
    ],
    steps: [
      'Connect to Wi-Fi and reopen the site page to re-download it.',
      'Free up storage space if your device is nearly full.',
      'Clear the cache in Profile > Settings, then re-open the sites you need.',
      'Confirm the download finished before going offline.',
    ],
  ),
  'guideloc': HelpArticle(
    title: 'Guide location not updating',
    problem: 'Your guide\'s live location on the map appears frozen or several minutes '
        'behind.',
    causes: [
      'Your guide has weak signal along the trail',
      'Background refresh is limited on your phone',
      'The last fix is still being smoothed from a noisy GPS signal',
    ],
    steps: [
      'Pull down on the tracking screen to force a manual refresh.',
      'Make sure the tracking screen is open — sharing runs while it is on screen.',
      'Wait up to 60 seconds for the next position to arrive.',
      'If it\'s frozen for over 10 minutes, message your guide or contact support.',
    ],
  ),
};

class HelpEmergency {
  final String name;
  final String number;
  const HelpEmergency(this.name, this.number);
}

/// Nepal emergency numbers.
const helpEmergencyContacts = <HelpEmergency>[
  HelpEmergency('Police', '100'),
  HelpEmergency('Ambulance', '102'),
  HelpEmergency('Fire Brigade', '101'),
  HelpEmergency('Tourist Police', '1144'),
  HelpEmergency('Traffic Police', '103'),
];

class HelpTopicInfo {
  final String heading;
  final String body;
  const HelpTopicInfo(this.heading, this.body);
}

const helpTopicInfo = <String, List<HelpTopicInfo>>{
  'account': [
    HelpTopicInfo('Profile & verification',
        'Update your name, photo and phone number, and verify your email to unlock '
            'reviews, RSVPs and guide bookings.'),
    HelpTopicInfo('Language & theme',
        'Switch between English and Nepali and choose a light or dark theme from '
            'Profile > Settings.'),
    HelpTopicInfo('Delete account',
        'Permanently remove your account and data from Profile > Account Settings. '
            'This can\'t be undone.'),
  ],
  'booking': [
    HelpTopicInfo('Finding a guide',
        'Browse verified guides by heritage site, rating, language and price, then '
            'send a booking request for your date.'),
    HelpTopicInfo('During the tour',
        'Once a guide accepts, chat opens and you can share live location with each '
            'other until the tour ends.'),
    HelpTopicInfo('After the tour',
        'Both sides confirm completion, you pay the guide directly and submit proof, '
            'then leave a multi-criteria review.'),
  ],
  'events': [
    HelpTopicInfo('Finding events',
        'Browse cultural events by date and district. Events show both Bikram Sambat '
            'and Gregorian dates and their start time.'),
    HelpTopicInfo('RSVP & reminders',
        'RSVP to an event to get reminders before it starts — enable them so alerts '
            'arrive even while your screen is off.'),
  ],
  'heritage': [
    HelpTopicInfo('Exploring sites',
        'Discover heritage sites with bilingual descriptions, galleries, maps and '
            'nearby detection based on your location.'),
    HelpTopicInfo('Offline access',
        'Download sites before you travel so browsing and search keep working without '
            'a connection.'),
  ],
};

/// Safety Center content.
const helpSafetyPoints = <HelpTopicInfo>[
  HelpTopicInfo('Verified guides only',
      'Every guide is reviewed and approved by our team, with identity documents '
          'checked before they can accept bookings.'),
  HelpTopicInfo('Share your live location',
      'During a tour you and your guide can see each other on the map — share your '
          'trip status with a friend for extra peace of mind.'),
  HelpTopicInfo('Report anything off',
      'Use Report a Problem to flag a guide, user, event or site. Our team reviews '
          'every report.'),
  HelpTopicInfo('Trust your instincts',
      'If something feels wrong, end the tour, move to a public area and use the '
          'Emergency Contacts screen for immediate help.'),
];
