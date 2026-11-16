part of 'strings.dart';

/// Испанский.
class _Es extends S {
  const _Es();

  @override
  String get tagline => 'El teléfono de tu empresa';
  @override
  String get server => 'Servidor';
  @override
  String get number => 'Extensión';
  @override
  String get password => 'Contraseña';
  @override
  String get signIn => 'Iniciar sesión';
  @override
  String get signInQr => 'Entrar con código QR';
  @override
  String get qrHint =>
      'Apunta la cámara del teléfono al código QR de tu administrador: SADO se abrirá con los datos de acceso ya rellenados.';
  @override
  String get soon => 'Próximamente';
  @override
  String get fieldRequired => 'Rellena este campo';

  @override
  String get tabDial => 'Teclado';
  @override
  String get tabHistory => 'Recientes';
  @override
  String get tabContacts => 'Contactos';
  @override
  String get tabMore => 'Más';

  @override
  String online(String number) => '$number · conectado';
  @override
  String get call => 'Llamar';
  @override
  String get calling => 'Llamando…';

  @override
  String get history => 'Recientes';
  @override
  String get filterAll => 'Todas';
  @override
  String get filterMissed => 'Perdidas';
  @override
  String get missed => 'perdida';
  @override
  String minutes(int n) => '$n min';
  @override
  String get yesterday => 'ayer';

  @override
  String get contacts => 'Contactos';
  @override
  String get searchHint => 'Nombre o número';
  @override
  String get employees => 'Personas';
  @override
  String get departments => 'Departamentos';
  @override
  String get statusFree => 'disponible';
  @override
  String get statusBusy => 'en llamada';
  @override
  String get statusOffline => 'desconectado';
  @override
  String get group => 'grupo';
  @override
  String get nothingFound => 'No se encontró a nadie';

  @override
  String get incomingCall => 'Llamada entrante';
  @override
  String get unknownCaller => 'Número desconocido';
  @override
  String get decline => 'Rechazar';
  @override
  String get accept => 'Aceptar';
  @override
  String get answerVerb => 'Responder';
  @override
  String get replyText => 'Responder con texto';
  @override
  String get silent => 'Silenciar';
  @override
  String get secureHd => 'Llamada segura · HD';
  @override
  String get mic => 'Silenciar';
  @override
  String get keypad => 'Teclado';
  @override
  String get speaker => 'Altavoz';
  @override
  String get soundOutput => 'Salida de audio';
  @override
  String get outputEarpiece => 'Teléfono';
  @override
  String get outputBluetooth => 'Bluetooth';
  @override
  String get outputWired => 'Auriculares';
  @override
  String get hold => 'Retener';
  @override
  String get onHold => 'En espera';
  @override
  String get secondCall => 'Segunda llamada';
  @override
  String get swapCalls => 'Cambiar';
  @override
  String get talkFirst => 'Consultar antes';
  @override
  String get connectCalls => 'Unir';
  @override
  String get failConnect => 'No se pudieron unir las llamadas';
  @override
  String get inCall => 'Llamada en curso';
  @override
  String get transfer => 'Transferir';
  @override
  String get addCall => 'Añadir';
  @override
  String get hangUp => 'Colgar';

  @override
  String get settings => 'Ajustes';
  @override
  String get style => 'Estilo';
  @override
  String get theme => 'Tema';
  @override
  String get themeSystem => 'Auto';
  @override
  String get themeLight => 'Claro';
  @override
  String get themeDark => 'Oscuro';
  @override
  String get themeAlwaysDark => 'Este estilo siempre es oscuro';
  @override
  String get language => 'Idioma';
  @override
  String get langSystem => 'Auto';
  @override
  String get account => 'Cuenta';
  @override
  String get signOut => 'Salir';
  @override
  String get demo => 'Demo';
  @override
  String get demoIncoming => 'Mostrar una llamada entrante';
  @override
  String get demoNote =>
      'Esto es una demo sin centralita: las llamadas no son reales y los contactos y el historial son de ejemplo.';
  @override
  String get tryDemo => 'Probar sin servidor';
  @override
  String get insecureServer =>
      'Una dirección ws:// no está cifrada: otros en la red pueden ver quién llama a quién e intentar adivinar la contraseña. Usa wss:// si tu servidor lo admite.';
  @override
  String get setupFilled =>
      'Datos recibidos desde un enlace. Revisa la dirección del servidor y toca «Iniciar sesión».';
  @override
  String get setupSignedIn => 'Ya has iniciado sesión. Para usar el enlace, cierra sesión primero.';
  @override
  String get pasteSetup => 'Pegar enlace de configuración';
  @override
  String get noSetupInClipboard => 'No hay ningún enlace de configuración en el portapapeles';
  @override
  String get signingIn => 'Conectando…';
  @override
  String get errAuth => 'Extensión o contraseña incorrecta';
  @override
  String get errNetwork => 'El servidor no responde. Revisa la dirección y tu conexión';
  @override
  String get errOther => 'No se pudo iniciar sesión';
  @override
  String linkConnecting(String number) => '$number · conectando…';
  @override
  String linkOffline(String number) => '$number · sin conexión';
  @override
  String linkAuth(String number) => '$number · error de acceso';
  @override
  String seconds(int n) => '$n s';
  @override
  String get historyEmpty => 'Tus llamadas aparecerán aquí';
  @override
  String get contactsLater =>
      'Tus compañeros aparecerán aquí cuando la app pueda cargarlos desde el servidor. Mientras tanto, llama desde el teclado.';
  @override
  String get failBusy => 'Ocupado';
  @override
  String get failRejected => 'Llamada rechazada';
  @override
  String get failNoAnswer => 'No contesta';
  @override
  String get failUnavailable => 'No disponible';
  @override
  String get failMic => 'Sin acceso al micrófono. Permítelo en los ajustes del teléfono';
  @override
  String get failOffline => 'Sin conexión con la centralita';
  @override
  String get failOther => 'La llamada falló';

  @override
  String get swipeUpToAnswer => "Desliza hacia arriba para responder";
  @override
  String get swipeDownToDecline => "Desliza hacia abajo para rechazar";
  @override
  String get slideToAnswer => "Desliza para responder";
  @override
  String get answerBy => "Responder llamadas";
  @override
  String get answerButtons => "Botones";
  @override
  String get answerSwipe => "Deslizar arriba o abajo";
  @override
  String get answerSlider => "Deslizar a la derecha";
  @override
  String get iconSet => "Iconos";
  @override
  String get iconsOutlined => "Contorno";
  @override
  String get iconsFilled => "Sólidos";
  @override
  String get iconsRounded => "Redondos";

  @override
  String get background => "Llamadas en segundo plano";
  @override
  String get backgroundOn => "Recibir";
  @override
  String get backgroundOff => "No recibir";
  @override
  String get backgroundNote =>
      "La app sigue conectada aunque esté minimizada: una notificación silenciosa queda en el panel y la batería se gasta algo más rápido.";
  @override
  String get batteryAsk => "Quitar restricción de batería";
  @override
  String get batteryOk => "Restricción de batería quitada";
  @override
  String get autostartAsk => "Permitir actividad en segundo plano";
  @override
  String get autostartNote =>
      "Los teléfonos Xiaomi, Samsung, Huawei, Oppo y Vivo cierran las apps por su cuenta y las llamadas entrantes dejan de llegar. En la lista que se abre, permite a SADO el inicio automático o funcionar sin restricciones.";
  @override
  String get notifAsk => "Permitir notificaciones";
  @override
  String get notifNote =>
      "Sin notificaciones, una llamada entrante no sonará ni se mostrará mientras la app esté en segundo plano.";
  @override
  String get missedCallTitle => "Llamada perdida";
  @override
  String missedCallsTitle(int count) => "Llamadas perdidas: $count";
  @override
  String get fullScreenAsk => "Permitir la pantalla de llamada sobre la pantalla de bloqueo";
  @override
  String get fullScreenNote =>
      "Sin esto, una llamada entrante con el teléfono bloqueado solo aparece como notificación.";
  @override
  String get tabHome => "Inicio";
  @override
  String get tabKeypad => "Teclado";
  @override
  String get today => "Hoy";
  @override
  String get yesterdayTitle => "Ayer";
  @override
  String get earlier => "Anteriores";
  @override
  String get answerAuto => "Según el estilo";
  @override
  String get appIcon => "Icono de la app";

  @override
  String get about => "Acerca de";
  @override
  String versionLabel(String version) => "Versión $version";
  @override
  String get checkUpdates => "Buscar actualizaciones";
  @override
  String get updateNote => "La búsqueda consulta GitHub y solo se hace cuando la tocas.";
  @override
  String get upToDate => "Tienes la última versión";
  @override
  String updateAvailable(String version) => "Versión $version disponible";
  @override
  String get openDownload => "Abrir página de descarga";
  @override
  String get updateFailed => "No se pudo comprobar. Inténtalo más tarde.";

  @override
  String get answerPill => "Deslizar a los lados";
  @override
  String get newContact => "Nuevo contacto";
  @override
  String get editContact => "Editar contacto";
  @override
  String get contactName => "Nombre";
  @override
  String get save => "Guardar";
  @override
  String get delete => "Eliminar";
  @override
  String get cancel => "Cancelar";
  @override
  String get noContacts => "Aún no hay contactos";
  @override
  String get showPhoneContacts => "Mostrar contactos del teléfono";
  @override
  String get fromPhone => "Del teléfono";
  @override
  String get phoneContactsTitle => "Contactos del teléfono";
  @override
  String get saveToContacts => "Guardar en contactos";
  @override
  String get transferTitle => "Transferir llamada";
  @override
  String get transferHint => "Número de destino";
  @override
  String get dnd => "No molestar";
  @override
  String get dndOn => "Activado";
  @override
  String get dndOff => "Desactivado";
  @override
  String get dndNote =>
      "Las llamadas entrantes no suenan y quien llama oye la señal de ocupado. Las perdidas quedan en Recientes.";
  @override
  String get ringtone => "Tono de llamada";
  @override
  String get ringtoneDefault => "El del teléfono";
  @override
  String get ringVibration => "Vibrar al sonar";
  @override
  String get redialHint => "Vuelve a tocar llamar para marcar";
  @override
  String dndStatus(String number) => "$number · no molestar";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Esmeralda',
    SadoStyleId.night => 'Noche',
    SadoStyleId.air => 'Aire',
    SadoStyleId.sunset => 'Atardecer',
    SadoStyleId.cupertino => 'Cupertino',
    SadoStyleId.material => 'Material',
  };
}
