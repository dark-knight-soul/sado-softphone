part of 'strings.dart';

/// Английский.
class _En extends S {
  const _En();

  @override
  String get tagline => 'Your company phone';
  @override
  String get server => 'Server';
  @override
  String get number => 'Extension';
  @override
  String get password => 'Password';
  @override
  String get signIn => 'Sign in';
  @override
  String get signInQr => 'Sign in with QR code';
  @override
  String get qrHint =>
      "Point the phone's camera at the QR code from your administrator — SADO will open with the sign-in form filled in.";
  @override
  String get soon => 'Coming soon';
  @override
  String get fieldRequired => 'Fill in this field';

  @override
  String get tabDial => 'Keypad';
  @override
  String get tabHistory => 'Recents';
  @override
  String get tabContacts => 'Contacts';
  @override
  String get tabMore => 'More';

  @override
  String online(String number) => '$number · online';
  @override
  String get call => 'Call';
  @override
  String get calling => 'Calling…';

  @override
  String get history => 'Recents';
  @override
  String get filterAll => 'All';
  @override
  String get filterMissed => 'Missed';
  @override
  String get missed => 'missed';
  @override
  String minutes(int n) => '$n min';
  @override
  String get yesterday => 'yesterday';

  @override
  String get contacts => 'Contacts';
  @override
  String get searchHint => 'Name or number';
  @override
  String get employees => 'People';
  @override
  String get departments => 'Departments';
  @override
  String get statusFree => 'available';
  @override
  String get statusBusy => 'on a call';
  @override
  String get statusOffline => 'offline';
  @override
  String get group => 'group';
  @override
  String get nothingFound => 'No one found';

  @override
  String get incomingCall => 'Incoming call';
  @override
  String get unknownCaller => 'Unknown number';
  @override
  String get decline => 'Decline';
  @override
  String get accept => 'Accept';
  @override
  String get answerVerb => 'Answer';
  @override
  String get replyText => 'Reply with text';
  @override
  String get silent => 'Silence';
  @override
  String get secureHd => 'Secure call · HD';
  @override
  String get mic => 'Mute';
  @override
  String get keypad => 'Keypad';
  @override
  String get speaker => 'Speaker';
  @override
  String get soundOutput => 'Sound output';
  @override
  String get outputEarpiece => 'Phone';
  @override
  String get outputBluetooth => 'Bluetooth';
  @override
  String get outputWired => 'Headphones';
  @override
  String get hold => 'Hold';
  @override
  String get onHold => 'On hold';
  @override
  String get secondCall => 'Second call';
  @override
  String get swapCalls => 'Swap';
  @override
  String get talkFirst => 'Talk first';
  @override
  String get connectCalls => 'Connect';
  @override
  String get failConnect => 'Could not connect the calls';
  @override
  String get inCall => 'Call in progress';
  @override
  String get transfer => 'Transfer';
  @override
  String get addCall => 'Add';
  @override
  String get hangUp => 'End';

  @override
  String get settings => 'Settings';
  @override
  String get style => 'Style';
  @override
  String get theme => 'Theme';
  @override
  String get themeSystem => 'Auto';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeAlwaysDark => 'This style is always dark';
  @override
  String get language => 'Language';
  @override
  String get langSystem => 'Auto';
  @override
  String get account => 'Account';
  @override
  String get signOut => 'Sign out';
  @override
  String get demo => 'Demo';
  @override
  String get demoIncoming => 'Show an incoming call';
  @override
  String get demoNote => "This is a demo without a PBX: calls aren't real, contacts and history are samples.";
  @override
  String get tryDemo => 'Try without a server';
  @override
  String get insecureServer =>
      "A ws:// address is not encrypted: others on the network can see who calls whom and can try to guess the password. Use wss:// if your server supports it.";
  @override
  String get setupFilled => 'Details received from a link. Check the server address and tap “Sign in”.';
  @override
  String get setupSignedIn => "You're already signed in. To use the link, sign out first.";
  @override
  String get pasteSetup => 'Paste setup link';
  @override
  String get noSetupInClipboard => 'No setup link in the clipboard';
  @override
  String get scanHint => 'Point the camera at the QR code from your administrator';
  @override
  String get scanNotSetup => 'This QR code has no SADO setup link';
  @override
  String get scanNoCamera =>
      "No camera access. Allow it in phone settings, or point the phone's own camera at the code.";
  @override
  String get signingIn => 'Connecting…';
  @override
  String get errAuth => 'Wrong extension or password';
  @override
  String get errNetwork => "The server isn't responding. Check the address and your connection";
  @override
  String get errOther => "Couldn't sign in";
  @override
  String linkConnecting(String number) => '$number · connecting…';
  @override
  String linkOffline(String number) => '$number · offline';
  @override
  String linkAuth(String number) => '$number · sign-in error';
  @override
  String seconds(int n) => '$n sec';
  @override
  String get historyEmpty => 'Your calls will appear here';
  @override
  String get contactsLater =>
      'Your colleagues will appear here once the app can load them from the server. For now, call from the keypad.';
  @override
  String get failBusy => 'Busy';
  @override
  String get failRejected => 'Call declined';
  @override
  String get failNoAnswer => 'No answer';
  @override
  String get failUnavailable => 'Unavailable';
  @override
  String get failMic => 'No microphone access. Allow it in phone settings';
  @override
  String get failOffline => 'No connection to the PBX';
  @override
  String get failOther => 'Call failed';

  @override
  String get swipeUpToAnswer => "Swipe up to answer";
  @override
  String get swipeDownToDecline => "Swipe down to decline";
  @override
  String get slideToAnswer => "Slide to answer";
  @override
  String get answerBy => "Answering calls";
  @override
  String get answerButtons => "Buttons";
  @override
  String get answerSwipe => "Swipe up or down";
  @override
  String get answerSlider => "Slide right";
  @override
  String get iconSet => "Icons";
  @override
  String get iconsOutlined => "Outlined";
  @override
  String get iconsFilled => "Filled";
  @override
  String get iconsRounded => "Rounded";

  @override
  String get background => "Background calls";
  @override
  String get backgroundOn => "Receive";
  @override
  String get backgroundOff => "Don't receive";
  @override
  String get backgroundNote =>
      "The app stays connected while minimized: a quiet notification stays in the shade, and the battery drains a little faster.";
  @override
  String get batteryAsk => "Remove battery restriction";
  @override
  String get batteryOk => "Battery restriction removed";
  @override
  String get autostartAsk => "Allow background activity";
  @override
  String get autostartNote =>
      "Xiaomi, Samsung, Huawei, Oppo and Vivo phones close apps on their own, and incoming calls stop arriving. In the list that opens, allow SADO to autostart or run without restrictions.";
  @override
  String get notifAsk => "Allow notifications";
  @override
  String get notifNote =>
      "Without notifications an incoming call will not ring or show up while the app is in the background.";
  @override
  String get missedCallTitle => "Missed call";
  @override
  String missedCallsTitle(int count) => "Missed calls: $count";
  @override
  String get fullScreenAsk => "Allow the call screen over the lock screen";
  @override
  String get fullScreenNote => "Without this, an incoming call on a locked phone shows only as a notification.";
  @override
  String get tabHome => "Home";
  @override
  String get tabKeypad => "Keypad";
  @override
  String get today => "Today";
  @override
  String get yesterdayTitle => "Yesterday";
  @override
  String get earlier => "Earlier";
  @override
  String get answerAuto => "Match the style";
  @override
  String get appIcon => "Home screen icon";

  @override
  String get about => "About";
  @override
  String versionLabel(String version) => "Version $version";
  @override
  String get checkUpdates => "Check for updates";
  @override
  String get updateNote => "The check contacts GitHub and runs only when you tap it.";
  @override
  String get upToDate => "You have the latest version";
  @override
  String updateAvailable(String version) => "Version $version is available";
  @override
  String get openDownload => "Open download page";
  @override
  String get updateFailed => "Couldn't check. Try again later.";

  @override
  String get answerPill => "Swipe sideways";
  @override
  String get newContact => "New contact";
  @override
  String get editContact => "Edit contact";
  @override
  String get contactName => "Name";
  @override
  String get save => "Save";
  @override
  String get delete => "Delete";
  @override
  String get cancel => "Cancel";
  @override
  String get noContacts => "No contacts yet";
  @override
  String get showPhoneContacts => "Show phone contacts";
  @override
  String get fromPhone => "From phone";
  @override
  String get phoneContactsTitle => "Phone contacts";
  @override
  String get saveToContacts => "Save to contacts";
  @override
  String get transferTitle => "Transfer call";
  @override
  String get transferHint => "Number to transfer to";
  @override
  String get dnd => "Do not disturb";
  @override
  String get dndOn => "On";
  @override
  String get dndOff => "Off";
  @override
  String get dndNote => "Incoming calls don't ring and the caller hears a busy tone. Missed calls stay in Recents.";
  @override
  String get ringtone => "Ringtone";
  @override
  String get ringtoneDefault => "Phone default";
  @override
  String get ringVibration => "Vibrate on ring";
  @override
  String get redialHint => "Tap call again to dial";
  @override
  String dndStatus(String number) => "$number · do not disturb";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Emerald',
    SadoStyleId.night => 'Night',
    SadoStyleId.air => 'Air',
    SadoStyleId.sunset => 'Sunset',
    SadoStyleId.cupertino => 'Cupertino',
    SadoStyleId.material => 'Material',
  };
}
