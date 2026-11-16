part of 'strings.dart';

/// Итальянский.
class _It extends S {
  const _It();

  @override
  String get tagline => 'Il telefono della tua azienda';
  @override
  String get server => 'Server';
  @override
  String get number => 'Interno';
  @override
  String get password => 'Password';
  @override
  String get signIn => 'Accedi';
  @override
  String get signInQr => 'Accedi con codice QR';
  @override
  String get qrHint =>
      "Inquadra con la fotocamera il codice QR ricevuto dall'amministratore: SADO si aprirà con il modulo di accesso già compilato.";
  @override
  String get soon => 'Prossimamente';
  @override
  String get fieldRequired => 'Compila questo campo';

  @override
  String get tabDial => 'Tastiera';
  @override
  String get tabHistory => 'Recenti';
  @override
  String get tabContacts => 'Contatti';
  @override
  String get tabMore => 'Altro';

  @override
  String online(String number) => '$number · online';
  @override
  String get call => 'Chiama';
  @override
  String get calling => 'Chiamata…';

  @override
  String get history => 'Recenti';
  @override
  String get filterAll => 'Tutte';
  @override
  String get filterMissed => 'Perse';
  @override
  String get missed => 'persa';
  @override
  String minutes(int n) => '$n min';
  @override
  String get yesterday => 'ieri';

  @override
  String get contacts => 'Contatti';
  @override
  String get searchHint => 'Nome o numero';
  @override
  String get employees => 'Persone';
  @override
  String get departments => 'Reparti';
  @override
  String get statusFree => 'disponibile';
  @override
  String get statusBusy => 'al telefono';
  @override
  String get statusOffline => 'offline';
  @override
  String get group => 'gruppo';
  @override
  String get nothingFound => 'Nessun risultato';

  @override
  String get incomingCall => 'Chiamata in arrivo';
  @override
  String get unknownCaller => 'Numero sconosciuto';
  @override
  String get decline => 'Rifiuta';
  @override
  String get accept => 'Accetta';
  @override
  String get answerVerb => 'Rispondi';
  @override
  String get replyText => 'Rispondi con SMS';
  @override
  String get silent => 'Silenzia';
  @override
  String get secureHd => 'Chiamata protetta · HD';
  @override
  String get mic => 'Muto';
  @override
  String get keypad => 'Tastiera';
  @override
  String get speaker => 'Altoparlante';
  @override
  String get soundOutput => 'Uscita audio';
  @override
  String get outputEarpiece => 'Telefono';
  @override
  String get outputBluetooth => 'Bluetooth';
  @override
  String get outputWired => 'Cuffie';
  @override
  String get hold => 'Attesa';
  @override
  String get onHold => 'In attesa';
  @override
  String get secondCall => 'Seconda chiamata';
  @override
  String get swapCalls => 'Scambia';
  @override
  String get talkFirst => 'Parla prima';
  @override
  String get connectCalls => 'Collega';
  @override
  String get failConnect => 'Impossibile collegare le chiamate';
  @override
  String get inCall => 'Chiamata in corso';
  @override
  String get transfer => 'Trasferisci';
  @override
  String get addCall => 'Aggiungi';
  @override
  String get hangUp => 'Termina';

  @override
  String get settings => 'Impostazioni';
  @override
  String get style => 'Stile';
  @override
  String get theme => 'Tema';
  @override
  String get themeSystem => 'Auto';
  @override
  String get themeLight => 'Chiaro';
  @override
  String get themeDark => 'Scuro';
  @override
  String get themeAlwaysDark => 'Questo stile è sempre scuro';
  @override
  String get language => 'Lingua';
  @override
  String get langSystem => 'Auto';
  @override
  String get account => 'Account';
  @override
  String get signOut => 'Esci';
  @override
  String get demo => 'Demo';
  @override
  String get demoIncoming => 'Mostra una chiamata in arrivo';
  @override
  String get demoNote =>
      'Questa è una demo senza centralino: le chiamate non sono reali, contatti e cronologia sono esempi.';
  @override
  String get tryDemo => 'Prova senza server';
  @override
  String get insecureServer =>
      "Un indirizzo ws:// non è cifrato: altri sulla rete possono vedere chi chiama chi e tentare di indovinare la password. Usa wss:// se il tuo server lo supporta.";
  @override
  String get setupFilled => 'Dati ricevuti da un link. Controlla l’indirizzo del server e tocca «Accedi».';
  @override
  String get setupSignedIn => "Hai già effettuato l'accesso. Per usare il link, esci prima.";
  @override
  String get pasteSetup => 'Incolla link di configurazione';
  @override
  String get noSetupInClipboard => 'Nessun link di configurazione negli appunti';
  @override
  String get signingIn => 'Connessione…';
  @override
  String get errAuth => 'Interno o password errati';
  @override
  String get errNetwork => "Il server non risponde. Controlla l'indirizzo e la connessione";
  @override
  String get errOther => 'Accesso non riuscito';
  @override
  String linkConnecting(String number) => '$number · connessione…';
  @override
  String linkOffline(String number) => '$number · offline';
  @override
  String linkAuth(String number) => '$number · errore di accesso';
  @override
  String seconds(int n) => '$n sec';
  @override
  String get historyEmpty => 'Qui compariranno le tue chiamate';
  @override
  String get contactsLater =>
      "I tuoi colleghi compariranno qui quando l'app potrà caricarli dal server. Per ora chiama dalla tastiera.";
  @override
  String get failBusy => 'Occupato';
  @override
  String get failRejected => 'Chiamata rifiutata';
  @override
  String get failNoAnswer => 'Nessuna risposta';
  @override
  String get failUnavailable => 'Non raggiungibile';
  @override
  String get failMic => 'Nessun accesso al microfono. Consentilo nelle impostazioni del telefono';
  @override
  String get failOffline => 'Nessuna connessione al centralino';
  @override
  String get failOther => 'Chiamata non riuscita';

  @override
  String get swipeUpToAnswer => "Scorri in su per rispondere";
  @override
  String get swipeDownToDecline => "Scorri in giù per rifiutare";
  @override
  String get slideToAnswer => "Scorri per rispondere";
  @override
  String get answerBy => "Risposta alle chiamate";
  @override
  String get answerButtons => "Pulsanti";
  @override
  String get answerSwipe => "Scorri su o giù";
  @override
  String get answerSlider => "Scorri a destra";
  @override
  String get iconSet => "Icone";
  @override
  String get iconsOutlined => "Contorno";
  @override
  String get iconsFilled => "Piene";
  @override
  String get iconsRounded => "Arrotondate";

  @override
  String get background => "Chiamate in background";
  @override
  String get backgroundOn => "Ricevi";
  @override
  String get backgroundOff => "Non ricevere";
  @override
  String get backgroundNote =>
      "L'app resta connessa anche quando è ridotta a icona: una notifica silenziosa resta nell'area notifiche e la batteria si scarica un po' più in fretta.";
  @override
  String get batteryAsk => "Rimuovi limitazione batteria";
  @override
  String get batteryOk => "Limitazione batteria rimossa";
  @override
  String get autostartAsk => "Consenti attività in background";
  @override
  String get autostartNote =>
      "I telefoni Xiaomi, Samsung, Huawei, Oppo e Vivo chiudono le app da soli e le chiamate in arrivo non arrivano più. Nell'elenco che si apre, consenti a SADO l'avvio automatico o l'esecuzione senza limitazioni.";
  @override
  String get notifAsk => "Consenti notifiche";
  @override
  String get notifNote =>
      "Senza notifiche una chiamata in arrivo non squillerà e non verrà mostrata mentre l'app è in background.";
  @override
  String get missedCallTitle => "Chiamata persa";
  @override
  String missedCallsTitle(int count) => "Chiamate perse: $count";
  @override
  String get fullScreenAsk => "Consenti la schermata di chiamata sulla schermata di blocco";
  @override
  String get fullScreenNote =>
      "Altrimenti, con il telefono bloccato, una chiamata in arrivo appare solo come notifica.";
  @override
  String get tabHome => "Home";
  @override
  String get tabKeypad => "Tastiera";
  @override
  String get today => "Oggi";
  @override
  String get yesterdayTitle => "Ieri";
  @override
  String get earlier => "Prima";
  @override
  String get answerAuto => "Come lo stile";
  @override
  String get appIcon => "Icona nella schermata Home";

  @override
  String get about => "Informazioni";
  @override
  String versionLabel(String version) => "Versione $version";
  @override
  String get checkUpdates => "Cerca aggiornamenti";
  @override
  String get updateNote => "Il controllo contatta GitHub e parte solo quando lo tocchi.";
  @override
  String get upToDate => "Hai l'ultima versione";
  @override
  String updateAvailable(String version) => "È disponibile la versione $version";
  @override
  String get openDownload => "Apri la pagina di download";
  @override
  String get updateFailed => "Controllo non riuscito. Riprova più tardi.";

  @override
  String get answerPill => "Scorri di lato";
  @override
  String get newContact => "Nuovo contatto";
  @override
  String get editContact => "Modifica contatto";
  @override
  String get contactName => "Nome";
  @override
  String get save => "Salva";
  @override
  String get delete => "Elimina";
  @override
  String get cancel => "Annulla";
  @override
  String get noContacts => "Ancora nessun contatto";
  @override
  String get showPhoneContacts => "Mostra contatti del telefono";
  @override
  String get fromPhone => "Dal telefono";
  @override
  String get phoneContactsTitle => "Contatti del telefono";
  @override
  String get saveToContacts => "Salva nei contatti";
  @override
  String get transferTitle => "Trasferisci chiamata";
  @override
  String get transferHint => "Numero a cui trasferire";
  @override
  String get dnd => "Non disturbare";
  @override
  String get dndOn => "Attivato";
  @override
  String get dndOff => "Disattivato";
  @override
  String get dndNote =>
      "Le chiamate in arrivo non squillano e chi chiama sente il segnale di occupato. Le chiamate perse restano in Recenti.";
  @override
  String get ringtone => "Suoneria";
  @override
  String get ringtoneDefault => "Predefinita del telefono";
  @override
  String get ringVibration => "Vibra quando squilla";
  @override
  String get redialHint => "Tocca di nuovo chiama per comporre";
  @override
  String dndStatus(String number) => "$number · non disturbare";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Smeraldo',
    SadoStyleId.night => 'Notte',
    SadoStyleId.air => 'Aria',
    SadoStyleId.sunset => 'Tramonto',
    SadoStyleId.cupertino => 'Cupertino',
    SadoStyleId.material => 'Material',
  };
}
