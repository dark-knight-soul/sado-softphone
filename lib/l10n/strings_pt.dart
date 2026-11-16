part of 'strings.dart';

/// Португальский (бразильский).
class _Pt extends S {
  const _Pt();

  @override
  String get tagline => 'O telefone da sua empresa';
  @override
  String get server => 'Servidor';
  @override
  String get number => 'Ramal';
  @override
  String get password => 'Senha';
  @override
  String get signIn => 'Entrar';
  @override
  String get signInQr => 'Entrar com QR code';
  @override
  String get qrHint =>
      'Aponte a câmera do celular para o QR code do seu administrador: o SADO vai abrir com o login já preenchido.';
  @override
  String get soon => 'Em breve';
  @override
  String get fieldRequired => 'Preencha este campo';

  @override
  String get tabDial => 'Teclado';
  @override
  String get tabHistory => 'Recentes';
  @override
  String get tabContacts => 'Contatos';
  @override
  String get tabMore => 'Mais';

  @override
  String online(String number) => '$number · on-line';
  @override
  String get call => 'Ligar';
  @override
  String get calling => 'Chamando…';

  @override
  String get history => 'Recentes';
  @override
  String get filterAll => 'Todas';
  @override
  String get filterMissed => 'Perdidas';
  @override
  String get missed => 'perdida';
  @override
  String minutes(int n) => '$n min';
  @override
  String get yesterday => 'ontem';

  @override
  String get contacts => 'Contatos';
  @override
  String get searchHint => 'Nome ou número';
  @override
  String get employees => 'Pessoas';
  @override
  String get departments => 'Departamentos';
  @override
  String get statusFree => 'disponível';
  @override
  String get statusBusy => 'em ligação';
  @override
  String get statusOffline => 'off-line';
  @override
  String get group => 'grupo';
  @override
  String get nothingFound => 'Ninguém encontrado';

  @override
  String get incomingCall => 'Chamada recebida';
  @override
  String get unknownCaller => 'Número desconhecido';
  @override
  String get decline => 'Recusar';
  @override
  String get accept => 'Aceitar';
  @override
  String get answerVerb => 'Atender';
  @override
  String get replyText => 'Responder com texto';
  @override
  String get silent => 'Silenciar';
  @override
  String get secureHd => 'Chamada segura · HD';
  @override
  String get mic => 'Mudo';
  @override
  String get keypad => 'Teclado';
  @override
  String get speaker => 'Viva-voz';
  @override
  String get soundOutput => 'Saída de áudio';
  @override
  String get outputEarpiece => 'Telefone';
  @override
  String get outputBluetooth => 'Bluetooth';
  @override
  String get outputWired => 'Fones de ouvido';
  @override
  String get hold => 'Espera';
  @override
  String get onHold => 'Em espera';
  @override
  String get secondCall => 'Segunda chamada';
  @override
  String get swapCalls => 'Alternar';
  @override
  String get talkFirst => 'Falar antes';
  @override
  String get connectCalls => 'Conectar';
  @override
  String get failConnect => 'Não foi possível conectar as chamadas';
  @override
  String get inCall => 'Chamada em andamento';
  @override
  String get transfer => 'Transferir';
  @override
  String get addCall => 'Adicionar';
  @override
  String get hangUp => 'Encerrar';

  @override
  String get settings => 'Configurações';
  @override
  String get style => 'Estilo';
  @override
  String get theme => 'Tema';
  @override
  String get themeSystem => 'Auto';
  @override
  String get themeLight => 'Claro';
  @override
  String get themeDark => 'Escuro';
  @override
  String get themeAlwaysDark => 'Este estilo é sempre escuro';
  @override
  String get language => 'Idioma';
  @override
  String get langSystem => 'Auto';
  @override
  String get account => 'Conta';
  @override
  String get signOut => 'Sair';
  @override
  String get demo => 'Demonstração';
  @override
  String get demoIncoming => 'Mostrar uma chamada recebida';
  @override
  String get demoNote =>
      'Esta é uma demonstração sem PABX: as chamadas não são reais, os contatos e o histórico são exemplos.';
  @override
  String get tryDemo => 'Testar sem servidor';
  @override
  String get insecureServer =>
      'Um endereço ws:// não é criptografado: outras pessoas na rede podem ver quem liga para quem e tentar adivinhar a senha. Use wss:// se o seu servidor oferecer suporte.';
  @override
  String get setupFilled => 'Dados recebidos de um link. Confira o endereço do servidor e toque em “Entrar”.';
  @override
  String get setupSignedIn => 'Você já está conectado. Para usar o link, saia primeiro.';
  @override
  String get pasteSetup => 'Colar link de configuração';
  @override
  String get noSetupInClipboard => 'Nenhum link de configuração na área de transferência';
  @override
  String get scanHint => 'Aponte a câmera para o QR code do seu administrador';
  @override
  String get scanNotSetup => 'Este QR code não contém um link de configuração do SADO';
  @override
  String get scanNoCamera =>
      'Sem acesso à câmera. Permita nas configurações do celular ou aponte a câmera do celular para o código.';
  @override
  String get signingIn => 'Conectando…';
  @override
  String get errAuth => 'Ramal ou senha incorretos';
  @override
  String get errNetwork => 'O servidor não responde. Confira o endereço e sua conexão';
  @override
  String get errOther => 'Não foi possível entrar';
  @override
  String linkConnecting(String number) => '$number · conectando…';
  @override
  String linkOffline(String number) => '$number · sem conexão';
  @override
  String linkAuth(String number) => '$number · erro de login';
  @override
  String seconds(int n) => '$n s';
  @override
  String get historyEmpty => 'Suas chamadas vão aparecer aqui';
  @override
  String get contactsLater =>
      'Seus colegas vão aparecer aqui quando o app puder carregá-los do servidor. Por enquanto, ligue pelo teclado.';
  @override
  String get failBusy => 'Ocupado';
  @override
  String get failRejected => 'Chamada recusada';
  @override
  String get failNoAnswer => 'Sem resposta';
  @override
  String get failUnavailable => 'Indisponível';
  @override
  String get failMic => 'Sem acesso ao microfone. Permita nas configurações do celular';
  @override
  String get failOffline => 'Sem conexão com o PABX';
  @override
  String get failOther => 'A chamada falhou';

  @override
  String get swipeUpToAnswer => "Deslize para cima para atender";
  @override
  String get swipeDownToDecline => "Deslize para baixo para recusar";
  @override
  String get slideToAnswer => "Deslize para atender";
  @override
  String get answerBy => "Atender chamadas";
  @override
  String get answerButtons => "Botões";
  @override
  String get answerSwipe => "Deslizar para cima ou baixo";
  @override
  String get answerSlider => "Deslizar para a direita";
  @override
  String get iconSet => "Ícones";
  @override
  String get iconsOutlined => "Contorno";
  @override
  String get iconsFilled => "Sólidos";
  @override
  String get iconsRounded => "Redondos";

  @override
  String get background => "Chamadas em segundo plano";
  @override
  String get backgroundOn => "Receber";
  @override
  String get backgroundOff => "Não receber";
  @override
  String get backgroundNote =>
      "O app continua conectado quando minimizado: uma notificação silenciosa fica na barra e a bateria descarrega um pouco mais rápido.";
  @override
  String get batteryAsk => "Remover restrição de bateria";
  @override
  String get batteryOk => "Restrição de bateria removida";
  @override
  String get autostartAsk => "Permitir atividade em segundo plano";
  @override
  String get autostartNote =>
      "Celulares Xiaomi, Samsung, Huawei, Oppo e Vivo fecham apps por conta própria, e as chamadas recebidas deixam de chegar. Na lista que abrir, permita que o SADO inicie automaticamente ou funcione sem restrições.";
  @override
  String get notifAsk => "Permitir notificações";
  @override
  String get notifNote =>
      "Sem notificações, uma chamada recebida não vai tocar nem aparecer enquanto o app estiver em segundo plano.";
  @override
  String get missedCallTitle => "Chamada perdida";
  @override
  String missedCallsTitle(int count) => "Chamadas perdidas: $count";
  @override
  String get fullScreenAsk => "Permitir a tela de chamada sobre a tela de bloqueio";
  @override
  String get fullScreenNote => "Sem isso, uma chamada recebida com o celular bloqueado aparece só como notificação.";
  @override
  String get tabHome => "Início";
  @override
  String get tabKeypad => "Teclado";
  @override
  String get today => "Hoje";
  @override
  String get yesterdayTitle => "Ontem";
  @override
  String get earlier => "Anteriores";
  @override
  String get answerAuto => "Conforme o estilo";
  @override
  String get appIcon => "Ícone na tela inicial";

  @override
  String get about => "Sobre";
  @override
  String versionLabel(String version) => "Versão $version";
  @override
  String get checkUpdates => "Verificar atualizações";
  @override
  String get updateNote => "A verificação acessa o GitHub e só é feita quando você toca.";
  @override
  String get upToDate => "Você tem a versão mais recente";
  @override
  String updateAvailable(String version) => "Versão $version disponível";
  @override
  String get openDownload => "Abrir página de download";
  @override
  String get updateFailed => "Não foi possível verificar. Tente mais tarde.";

  @override
  String get answerPill => "Deslizar para os lados";
  @override
  String get newContact => "Novo contato";
  @override
  String get editContact => "Editar contato";
  @override
  String get contactName => "Nome";
  @override
  String get save => "Salvar";
  @override
  String get delete => "Excluir";
  @override
  String get cancel => "Cancelar";
  @override
  String get noContacts => "Nenhum contato ainda";
  @override
  String get showPhoneContacts => "Mostrar contatos do celular";
  @override
  String get fromPhone => "Do celular";
  @override
  String get phoneContactsTitle => "Contatos do celular";
  @override
  String get saveToContacts => "Salvar nos contatos";
  @override
  String get transferTitle => "Transferir chamada";
  @override
  String get transferHint => "Número de destino";
  @override
  String get dnd => "Não perturbe";
  @override
  String get dndOn => "Ativado";
  @override
  String get dndOff => "Desativado";
  @override
  String get dndNote =>
      "As chamadas recebidas não tocam e quem liga ouve sinal de ocupado. As perdidas ficam em Recentes.";
  @override
  String get ringtone => "Toque";
  @override
  String get ringtoneDefault => "Padrão do celular";
  @override
  String get ringVibration => "Vibrar ao tocar";
  @override
  String get redialHint => "Toque em ligar de novo para discar";
  @override
  String dndStatus(String number) => "$number · não perturbe";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Esmeralda',
    SadoStyleId.night => 'Noite',
    SadoStyleId.air => 'Ar',
    SadoStyleId.sunset => 'Pôr do sol',
    SadoStyleId.cupertino => 'Cupertino',
    SadoStyleId.material => 'Material',
  };
}
