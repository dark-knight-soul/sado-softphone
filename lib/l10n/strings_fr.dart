part of 'strings.dart';

/// Французский.
class _Fr extends S {
  const _Fr();

  @override
  String get tagline => 'Le téléphone de votre entreprise';
  @override
  String get server => 'Serveur';
  @override
  String get number => 'Poste';
  @override
  String get password => 'Mot de passe';
  @override
  String get signIn => 'Se connecter';
  @override
  String get signInQr => 'Se connecter par QR code';
  @override
  String get qrHint =>
      "Pointez l'appareil photo vers le QR code fourni par votre administrateur : SADO s'ouvrira avec le formulaire de connexion déjà rempli.";
  @override
  String get soon => 'Bientôt disponible';
  @override
  String get fieldRequired => 'Remplissez ce champ';

  @override
  String get tabDial => 'Clavier';
  @override
  String get tabHistory => 'Récents';
  @override
  String get tabContacts => 'Contacts';
  @override
  String get tabMore => 'Plus';

  @override
  String online(String number) => '$number · en ligne';
  @override
  String get call => 'Appeler';
  @override
  String get calling => 'Appel…';

  @override
  String get history => 'Récents';
  @override
  String get filterAll => 'Tous';
  @override
  String get filterMissed => 'Manqués';
  @override
  String get missed => 'manqué';
  @override
  String minutes(int n) => '$n min';
  @override
  String get yesterday => 'hier';

  @override
  String get contacts => 'Contacts';
  @override
  String get searchHint => 'Nom ou numéro';
  @override
  String get employees => 'Personnes';
  @override
  String get departments => 'Services';
  @override
  String get statusFree => 'disponible';
  @override
  String get statusBusy => 'en appel';
  @override
  String get statusOffline => 'hors ligne';
  @override
  String get group => 'groupe';
  @override
  String get nothingFound => 'Aucun résultat';

  @override
  String get incomingCall => 'Appel entrant';
  @override
  String get unknownCaller => 'Numéro inconnu';
  @override
  String get decline => 'Refuser';
  @override
  String get accept => 'Accepter';
  @override
  String get answerVerb => 'Répondre';
  @override
  String get replyText => 'Répondre par SMS';
  @override
  String get silent => 'Silence';
  @override
  String get secureHd => 'Appel sécurisé · HD';
  @override
  String get mic => 'Muet';
  @override
  String get keypad => 'Clavier';
  @override
  String get speaker => 'Haut-parleur';
  @override
  String get soundOutput => 'Sortie audio';
  @override
  String get outputEarpiece => 'Téléphone';
  @override
  String get outputBluetooth => 'Bluetooth';
  @override
  String get outputWired => 'Écouteurs';
  @override
  String get hold => 'Attente';
  @override
  String get onHold => 'En attente';
  @override
  String get secondCall => 'Second appel';
  @override
  String get swapCalls => 'Permuter';
  @override
  String get talkFirst => "Parler d'abord";
  @override
  String get connectCalls => 'Relier';
  @override
  String get failConnect => 'Impossible de relier les appels';
  @override
  String get inCall => 'Appel en cours';
  @override
  String get transfer => 'Transférer';
  @override
  String get addCall => 'Ajouter';
  @override
  String get hangUp => 'Raccrocher';

  @override
  String get settings => 'Paramètres';
  @override
  String get style => 'Style';
  @override
  String get theme => 'Thème';
  @override
  String get themeSystem => 'Auto';
  @override
  String get themeLight => 'Clair';
  @override
  String get themeDark => 'Sombre';
  @override
  String get themeAlwaysDark => 'Ce style est toujours sombre';
  @override
  String get language => 'Langue';
  @override
  String get langSystem => 'Auto';
  @override
  String get account => 'Compte';
  @override
  String get signOut => 'Déconnexion';
  @override
  String get demo => 'Démo';
  @override
  String get demoIncoming => 'Afficher un appel entrant';
  @override
  String get demoNote =>
      "Ceci est une démo sans standard téléphonique : les appels ne sont pas réels, les contacts et l'historique sont des exemples.";
  @override
  String get tryDemo => 'Essayer sans serveur';
  @override
  String get insecureServer =>
      "Une adresse ws:// n'est pas chiffrée : d'autres personnes sur le réseau peuvent voir qui appelle qui et tenter de deviner le mot de passe. Utilisez wss:// si votre serveur le permet.";
  @override
  String get setupFilled =>
      "Informations reçues par un lien. Vérifiez l'adresse du serveur et appuyez sur « Se connecter ».";
  @override
  String get setupSignedIn => 'Vous êtes déjà connecté. Pour utiliser le lien, déconnectez-vous d’abord.';
  @override
  String get pasteSetup => 'Coller le lien de configuration';
  @override
  String get noSetupInClipboard => 'Aucun lien de configuration dans le presse-papiers';
  @override
  String get scanHint => "Pointez l'appareil photo vers le QR code de votre administrateur";
  @override
  String get scanNotSetup => 'Ce QR code ne contient pas de lien de configuration SADO';
  @override
  String get scanNoCamera =>
      "Pas d'accès à l'appareil photo. Autorisez-le dans les paramètres du téléphone ou scannez le code avec l'appareil photo du téléphone.";
  @override
  String get signingIn => 'Connexion…';
  @override
  String get errAuth => 'Poste ou mot de passe incorrect';
  @override
  String get errNetwork => "Le serveur ne répond pas. Vérifiez l'adresse et votre connexion";
  @override
  String get errOther => 'Connexion impossible';
  @override
  String linkConnecting(String number) => '$number · connexion…';
  @override
  String linkOffline(String number) => '$number · hors ligne';
  @override
  String linkAuth(String number) => '$number · erreur de connexion';
  @override
  String seconds(int n) => '$n s';
  @override
  String get historyEmpty => 'Vos appels apparaîtront ici';
  @override
  String get contactsLater =>
      "Vos collègues apparaîtront ici dès que l'application pourra les charger depuis le serveur. En attendant, appelez depuis le clavier.";
  @override
  String get failBusy => 'Occupé';
  @override
  String get failRejected => 'Appel refusé';
  @override
  String get failNoAnswer => 'Pas de réponse';
  @override
  String get failUnavailable => 'Indisponible';
  @override
  String get failMic => "Pas d'accès au micro. Autorisez-le dans les paramètres du téléphone";
  @override
  String get failOffline => 'Pas de connexion au standard';
  @override
  String get failOther => "Échec de l'appel";

  @override
  String get swipeUpToAnswer => "Balayez vers le haut pour répondre";
  @override
  String get swipeDownToDecline => "Balayez vers le bas pour refuser";
  @override
  String get slideToAnswer => "Faites glisser pour répondre";
  @override
  String get answerBy => "Répondre aux appels";
  @override
  String get answerButtons => "Boutons";
  @override
  String get answerSwipe => "Balayer haut ou bas";
  @override
  String get answerSlider => "Glisser à droite";
  @override
  String get iconSet => "Icônes";
  @override
  String get iconsOutlined => "Contour";
  @override
  String get iconsFilled => "Pleines";
  @override
  String get iconsRounded => "Arrondies";

  @override
  String get background => "Appels en arrière-plan";
  @override
  String get backgroundOn => "Recevoir";
  @override
  String get backgroundOff => "Ne pas recevoir";
  @override
  String get backgroundNote =>
      "L'application reste connectée lorsqu'elle est réduite : une notification discrète reste affichée et la batterie se décharge un peu plus vite.";
  @override
  String get batteryAsk => "Lever la restriction de batterie";
  @override
  String get batteryOk => "Restriction de batterie levée";
  @override
  String get autostartAsk => "Autoriser l'activité en arrière-plan";
  @override
  String get autostartNote =>
      "Les téléphones Xiaomi, Samsung, Huawei, Oppo et Vivo ferment eux-mêmes les applications, et les appels entrants n'arrivent plus. Dans la liste qui s'ouvre, autorisez SADO à démarrer automatiquement ou à fonctionner sans restriction.";
  @override
  String get notifAsk => "Autoriser les notifications";
  @override
  String get notifNote =>
      "Sans notifications, un appel entrant ne sonnera pas et ne s'affichera pas tant que l'application est en arrière-plan.";
  @override
  String get missedCallTitle => "Appel manqué";
  @override
  String missedCallsTitle(int count) => "Appels manqués : $count";
  @override
  String get fullScreenAsk => "Autoriser l'écran d'appel sur l'écran de verrouillage";
  @override
  String get fullScreenNote =>
      "Sinon, un appel entrant sur un téléphone verrouillé n'apparaît que sous forme de notification.";
  @override
  String get tabHome => "Accueil";
  @override
  String get tabKeypad => "Clavier";
  @override
  String get today => "Aujourd'hui";
  @override
  String get yesterdayTitle => "Hier";
  @override
  String get earlier => "Plus tôt";
  @override
  String get answerAuto => "Selon le style";
  @override
  String get appIcon => "Icône de l'application";

  @override
  String get about => "À propos";
  @override
  String versionLabel(String version) => "Version $version";
  @override
  String get checkUpdates => "Rechercher des mises à jour";
  @override
  String get updateNote => "La vérification contacte GitHub et n'a lieu que lorsque vous appuyez.";
  @override
  String get upToDate => "Vous avez la dernière version";
  @override
  String updateAvailable(String version) => "La version $version est disponible";
  @override
  String get openDownload => "Ouvrir la page de téléchargement";
  @override
  String get updateFailed => "Vérification impossible. Réessayez plus tard.";

  @override
  String get answerPill => "Balayer sur le côté";
  @override
  String get newContact => "Nouveau contact";
  @override
  String get editContact => "Modifier le contact";
  @override
  String get contactName => "Nom";
  @override
  String get save => "Enregistrer";
  @override
  String get delete => "Supprimer";
  @override
  String get cancel => "Annuler";
  @override
  String get noContacts => "Aucun contact pour l'instant";
  @override
  String get showPhoneContacts => "Afficher les contacts du téléphone";
  @override
  String get fromPhone => "Du téléphone";
  @override
  String get phoneContactsTitle => "Contacts du téléphone";
  @override
  String get saveToContacts => "Ajouter aux contacts";
  @override
  String get transferTitle => "Transférer l'appel";
  @override
  String get transferHint => "Numéro de destination";
  @override
  String get dnd => "Ne pas déranger";
  @override
  String get dndOn => "Activé";
  @override
  String get dndOff => "Désactivé";
  @override
  String get dndNote =>
      "Les appels entrants ne sonnent pas et l'appelant entend une tonalité occupée. Les appels manqués restent dans Récents.";
  @override
  String get ringtone => "Sonnerie";
  @override
  String get ringtoneDefault => "Par défaut du téléphone";
  @override
  String get ringVibration => "Vibrer pendant la sonnerie";
  @override
  String get redialHint => "Appuyez de nouveau sur appeler pour composer";
  @override
  String dndStatus(String number) => "$number · ne pas déranger";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Émeraude',
    SadoStyleId.night => 'Nuit',
    SadoStyleId.air => 'Air',
    SadoStyleId.sunset => 'Crépuscule',
    SadoStyleId.cupertino => 'Cupertino',
    SadoStyleId.material => 'Material',
  };
}
