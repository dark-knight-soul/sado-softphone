part of 'strings.dart';

/// Немецкий.
class _De extends S {
  const _De();

  @override
  String get tagline => 'Ihr Firmentelefon';
  @override
  String get server => 'Server';
  @override
  String get number => 'Nebenstelle';
  @override
  String get password => 'Passwort';
  @override
  String get signIn => 'Anmelden';
  @override
  String get signInQr => 'Mit QR-Code anmelden';
  @override
  String get qrHint =>
      'Richten Sie die Kamera auf den QR-Code von Ihrem Administrator – SADO öffnet sich mit ausgefülltem Anmeldeformular.';
  @override
  String get soon => 'Demnächst';
  @override
  String get fieldRequired => 'Bitte ausfüllen';

  @override
  String get tabDial => 'Tastatur';
  @override
  String get tabHistory => 'Anrufe';
  @override
  String get tabContacts => 'Kontakte';
  @override
  String get tabMore => 'Mehr';

  @override
  String online(String number) => '$number · online';
  @override
  String get call => 'Anrufen';
  @override
  String get calling => 'Wird angerufen…';

  @override
  String get history => 'Anrufliste';
  @override
  String get filterAll => 'Alle';
  @override
  String get filterMissed => 'Verpasst';
  @override
  String get missed => 'verpasst';
  @override
  String minutes(int n) => '$n Min.';
  @override
  String get yesterday => 'gestern';

  @override
  String get contacts => 'Kontakte';
  @override
  String get searchHint => 'Name oder Nummer';
  @override
  String get employees => 'Personen';
  @override
  String get departments => 'Abteilungen';
  @override
  String get statusFree => 'verfügbar';
  @override
  String get statusBusy => 'im Gespräch';
  @override
  String get statusOffline => 'offline';
  @override
  String get group => 'Gruppe';
  @override
  String get nothingFound => 'Niemand gefunden';

  @override
  String get incomingCall => 'Eingehender Anruf';
  @override
  String get unknownCaller => 'Unbekannte Nummer';
  @override
  String get decline => 'Ablehnen';
  @override
  String get accept => 'Annehmen';
  @override
  String get answerVerb => 'Annehmen';
  @override
  String get replyText => 'Mit SMS antworten';
  @override
  String get silent => 'Lautlos';
  @override
  String get secureHd => 'Sicherer Anruf · HD';
  @override
  String get mic => 'Stumm';
  @override
  String get keypad => 'Tastatur';
  @override
  String get speaker => 'Lautsprecher';
  @override
  String get soundOutput => 'Audioausgabe';
  @override
  String get outputEarpiece => 'Telefon';
  @override
  String get outputBluetooth => 'Bluetooth';
  @override
  String get outputWired => 'Kopfhörer';
  @override
  String get hold => 'Halten';
  @override
  String get onHold => 'Gehalten';
  @override
  String get secondCall => 'Zweiter Anruf';
  @override
  String get swapCalls => 'Wechseln';
  @override
  String get talkFirst => 'Rückfrage';
  @override
  String get connectCalls => 'Verbinden';
  @override
  String get mergeCalls => 'Konferenz';
  @override
  String get conference => 'Konferenz';
  @override
  String get record => 'Aufnehmen';
  @override
  String get recordingOn => 'Aufnahme läuft';
  @override
  String get failConnect => 'Anrufe konnten nicht verbunden werden';
  @override
  String get inCall => 'Laufender Anruf';
  @override
  String get transfer => 'Weiterleiten';
  @override
  String get addCall => 'Hinzufügen';
  @override
  String get hangUp => 'Beenden';

  @override
  String get settings => 'Einstellungen';
  @override
  String get style => 'Stil';
  @override
  String get theme => 'Design';
  @override
  String get themeSystem => 'Auto';
  @override
  String get themeLight => 'Hell';
  @override
  String get themeDark => 'Dunkel';
  @override
  String get themeAlwaysDark => 'Dieser Stil ist immer dunkel';
  @override
  String get language => 'Sprache';
  @override
  String get langSystem => 'Auto';
  @override
  String get account => 'Konto';
  @override
  String get signOut => 'Abmelden';
  @override
  String get demo => 'Demo';
  @override
  String get demoIncoming => 'Eingehenden Anruf zeigen';
  @override
  String get demoNote =>
      'Dies ist eine Demo ohne Telefonanlage: Die Anrufe sind nicht echt, Kontakte und Anrufliste sind Beispiele.';
  @override
  String get tryDemo => 'Ohne Server testen';
  @override
  String get insecureServer =>
      'Eine ws://-Adresse ist nicht verschlüsselt: Andere im Netz sehen, wer wen anruft, und können versuchen, das Passwort zu erraten. Verwenden Sie wss://, wenn Ihr Server es unterstützt.';
  @override
  String get setupFilled =>
      'Daten aus einem Link übernommen. Prüfen Sie die Serveradresse und tippen Sie auf „Anmelden“.';
  @override
  String get setupSignedIn => 'Sie sind bereits angemeldet. Melden Sie sich zuerst ab, um den Link zu verwenden.';
  @override
  String get pasteSetup => 'Einrichtungslink einfügen';
  @override
  String get noSetupInClipboard => 'Kein Einrichtungslink in der Zwischenablage';
  @override
  String get scanHint => 'Kamera auf den QR-Code Ihres Administrators richten';
  @override
  String get scanNotSetup => 'Dieser QR-Code enthält keinen SADO-Einrichtungslink';
  @override
  String get scanNoCamera =>
      'Kein Zugriff auf die Kamera. Erlauben Sie ihn in den Telefoneinstellungen oder scannen Sie den Code mit der Kamera-App.';
  @override
  String get signingIn => 'Verbindung wird hergestellt…';
  @override
  String get errAuth => 'Falsche Nebenstelle oder falsches Passwort';
  @override
  String get errNetwork => 'Der Server antwortet nicht. Prüfen Sie die Adresse und Ihre Verbindung';
  @override
  String get errOther => 'Anmeldung fehlgeschlagen';
  @override
  String linkConnecting(String number) => '$number · verbinden…';
  @override
  String linkOffline(String number) => '$number · offline';
  @override
  String linkAuth(String number) => '$number · Anmeldefehler';
  @override
  String seconds(int n) => '$n Sek.';
  @override
  String get historyEmpty => 'Hier erscheinen Ihre Anrufe';
  @override
  String get contactsLater =>
      'Ihre Kollegen erscheinen hier, sobald die App sie vom Server laden kann. Rufen Sie bis dahin über die Tastatur an.';
  @override
  String get failBusy => 'Besetzt';
  @override
  String get failRejected => 'Anruf abgelehnt';
  @override
  String get failNoAnswer => 'Keine Antwort';
  @override
  String get failUnavailable => 'Nicht erreichbar';
  @override
  String get failMic => 'Kein Zugriff auf das Mikrofon. Erlauben Sie ihn in den Telefoneinstellungen';
  @override
  String get failOffline => 'Keine Verbindung zur Telefonanlage';
  @override
  String get failOther => 'Anruf fehlgeschlagen';

  @override
  String get swipeUpToAnswer => "Nach oben: annehmen";
  @override
  String get swipeDownToDecline => "Nach unten: ablehnen";
  @override
  String get slideToAnswer => "Zum Annehmen schieben";
  @override
  String get answerBy => "Anrufe annehmen";
  @override
  String get answerButtons => "Tasten";
  @override
  String get answerSwipe => "Hoch oder runter wischen";
  @override
  String get answerSlider => "Nach rechts schieben";
  @override
  String get iconSet => "Symbole";
  @override
  String get iconsOutlined => "Kontur";
  @override
  String get iconsFilled => "Gefüllt";
  @override
  String get iconsRounded => "Abgerundet";

  @override
  String get background => "Anrufe im Hintergrund";
  @override
  String get backgroundOn => "Empfangen";
  @override
  String get backgroundOff => "Nicht empfangen";
  @override
  String get backgroundNote =>
      "Die App bleibt auch minimiert verbunden: Eine dezente Benachrichtigung bleibt in der Leiste, und der Akku wird etwas schneller leer.";
  @override
  String get pushWake => 'Bei Anruf wecken (experimentell)';
  @override
  String get pushWakeNote =>
      'Die App bleibt nicht dauerhaft verbunden: Bei einem Anruf weckt die Telefonanlage das Telefon per Push-Benachrichtigung über Google. Das spart Akku, der Anruf wird einige Sekunden später verbunden. Nur einschalten, wenn Ihr Administrator bestätigt hat, dass die Telefonanlage das unterstützt – sonst kommen Anrufe im Hintergrund nicht an.';
  @override
  String get systemCalls => 'Systemanrufe (experimentell)';
  @override
  String get systemCallsNote =>
      'Das Telefon erfährt von SADO-Anrufen: Headset-Tasten, Auto und Uhr funktionieren, und ein normaler Mobilfunkanruf hält das Gespräch, statt den Ton zu unterbrechen. Der Modus ist neu – schalten Sie ihn aus, wenn der Ton Probleme macht.';
  @override
  String get batteryAsk => "Akku-Einschränkung aufheben";
  @override
  String get batteryOk => "Akku-Einschränkung aufgehoben";
  @override
  String get autostartAsk => "Hintergrundaktivität erlauben";
  @override
  String get autostartNote =>
      "Smartphones von Xiaomi, Samsung, Huawei, Oppo und Vivo beenden Apps selbstständig, und eingehende Anrufe kommen nicht mehr an. Erlauben Sie SADO in der geöffneten Liste den Autostart oder die Ausführung ohne Einschränkungen.";
  @override
  String get notifAsk => "Benachrichtigungen erlauben";
  @override
  String get notifNote =>
      "Ohne Benachrichtigungen klingelt ein eingehender Anruf nicht und wird nicht angezeigt, solange die App im Hintergrund ist.";
  @override
  String get missedCallTitle => "Verpasster Anruf";
  @override
  String missedCallsTitle(int count) => "Verpasste Anrufe: $count";
  @override
  String get fullScreenAsk => "Anrufbildschirm über dem Sperrbildschirm erlauben";
  @override
  String get fullScreenNote => "Sonst erscheint ein eingehender Anruf bei gesperrtem Telefon nur als Benachrichtigung.";
  @override
  String get tabHome => "Start";
  @override
  String get tabKeypad => "Tastatur";
  @override
  String get today => "Heute";
  @override
  String get yesterdayTitle => "Gestern";
  @override
  String get earlier => "Früher";
  @override
  String get answerAuto => "Wie im Stil";
  @override
  String get appIcon => "App-Symbol";

  @override
  String get about => "Über die App";
  @override
  String versionLabel(String version) => "Version $version";
  @override
  String get checkUpdates => "Nach Updates suchen";
  @override
  String get updateNote => "Die Prüfung kontaktiert GitHub und läuft nur, wenn Sie darauf tippen.";
  @override
  String get upToDate => "Sie haben die neueste Version";
  @override
  String updateAvailable(String version) => "Version $version ist verfügbar";
  @override
  String get openDownload => "Downloadseite öffnen";
  @override
  String get updateFailed => "Prüfung fehlgeschlagen. Versuchen Sie es später erneut.";

  @override
  String get answerPill => "Zur Seite wischen";
  @override
  String get newContact => "Neuer Kontakt";
  @override
  String get editContact => "Kontakt bearbeiten";
  @override
  String get contactName => "Name";
  @override
  String get save => "Speichern";
  @override
  String get delete => "Löschen";
  @override
  String get cancel => "Abbrechen";
  @override
  String get noContacts => "Noch keine Kontakte";
  @override
  String get showPhoneContacts => "Telefonkontakte anzeigen";
  @override
  String get fromPhone => "Vom Telefon";
  @override
  String get myContacts => 'Meine Kontakte';
  @override
  String get phoneContactsTitle => "Telefonkontakte";
  @override
  String get saveToContacts => "In Kontakten speichern";
  @override
  String get transferTitle => "Anruf weiterleiten";
  @override
  String get transferHint => "Weiterleiten an Nummer";
  @override
  String get dnd => "Nicht stören";
  @override
  String get dndOn => "An";
  @override
  String get dndOff => "Aus";
  @override
  String get dndNote =>
      "Eingehende Anrufe klingeln nicht, der Anrufer hört das Besetztzeichen. Verpasste Anrufe bleiben in der Anrufliste.";
  @override
  String get ringtone => "Klingelton";
  @override
  String get ringtoneDefault => "Telefonstandard";
  @override
  String get ringVibration => "Beim Klingeln vibrieren";
  @override
  String get redialHint => "Erneut auf Anrufen tippen, um zu wählen";
  @override
  String dndStatus(String number) => "$number · nicht stören";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Smaragd',
    SadoStyleId.night => 'Nacht',
    SadoStyleId.air => 'Luft',
    SadoStyleId.sunset => 'Abendrot',
    SadoStyleId.cupertino => 'Cupertino',
    SadoStyleId.material => 'Material',
  };
}
