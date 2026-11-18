"""Описание приложения для каталогов (F-Droid, IzzyOnDroid) в принятом там виде — папка fastlane/metadata/android.

Тексты лежат здесь же, в словаре LISTING: так их удобно править и сверять между языками. Скрипт раскладывает
их по файлам, копирует снимки экрана и проверяет ограничения каталогов (длина названия, краткого описания
и списка изменений).

Запуск из корня проекта:  python tool/make_store_listing.py
Снимки берутся из build/shots — сначала их нужно снять:
  flutter test --dart-define=SADO_SHOTS=true test/screenshots_test.dart
"""

import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'fastlane', 'metadata', 'android')
SHOTS = os.path.join(ROOT, 'build', 'shots')
LINK = 'https://github.com/dark-knight-soul/sado-softphone'

# Снимки экрана в порядке показа (общие для всех языков — подписи на них английские).
SCREENSHOTS = ['dial-emerald', 'emerald-call', 'night-incoming', 'material-home', 'cupertino-call', 'emerald-settings']

# Ограничения каталогов.
MAX_TITLE, MAX_SHORT, MAX_FULL, MAX_CHANGELOG = 50, 80, 4000, 500

LISTING = {
    'en-US': dict(
        title='SADO: SIP softphone',
        short='Open-source softphone for your company PBX: SIP over WebSocket, WebRTC audio',
        full='''SADO is a free, open-source softphone for Android that connects to your own PBX: Asterisk, FreePBX, FreeSWITCH, Kamailio and other servers that offer SIP over WebSocket with WebRTC audio.

CALLS
• Incoming and outgoing calls with HD audio (Opus, G.722)
• Hold, mute, speaker, Bluetooth and wired headsets, DTMF keypad
• Call waiting: answer a second call and switch between the two
• Blind and attended transfer
• Do not disturb, missed-call notifications, your own ringtone
• tel: and sip: links open the dialer

MADE FOR THE OFFICE
• Stays reachable in the background and after a reboot
• Colleague status next to your contacts when the PBX provides it
• Sign in by scanning a QR code from your administrator
• Your own contacts and, optionally, the phone's address book

YOURS TO STYLE
• Six interface styles with light and dark themes
• Eight home-screen icons, several ways to answer a call
• Nine languages: English, Deutsch, Español, Français, Italiano, Português, Türkçe, Русский, Oʻzbek

PRIVATE BY DESIGN
• No ads, no analytics, no accounts: the app talks only to your PBX
• No Google services required
• The password is kept in the Android Keystore; history and contacts never leave the phone

WHAT YOUR PBX NEEDS
SIP over WebSocket (wss:// recommended), WebRTC media (ICE, DTLS-SRTP), Opus, G.722 or G.711. Classic SIP over UDP or TCP is not supported. The phone must be able to reach the PBX directly.

Source code, setup guide and issue tracker: %s''' % LINK,
    ),
    'ru-RU': dict(
        title='SADO: SIP-софтфон',
        short='Открытый софтфон для АТС вашей компании: SIP поверх WebSocket, звук WebRTC',
        full='''SADO — бесплатный софтфон с открытым кодом для Android. Он подключается к вашей собственной АТС: Asterisk, FreePBX, FreeSWITCH, Kamailio и другим серверам, которые поддерживают SIP поверх WebSocket и звук WebRTC.

ЗВОНКИ
• Входящие и исходящие звонки с качественным звуком (Opus, G.722)
• Удержание, выключение микрофона, динамик, Bluetooth и проводная гарнитура, донабор цифр
• Второй звонок: ответить и переключаться между двумя разговорами
• Перевод звонка — сразу или после разговора с коллегой
• «Не беспокоить», уведомления о пропущенных, своя мелодия
• Ссылки tel: и sip: открывают набор номера

ДЛЯ РАБОТЫ В ОФИСЕ
• Остаётся на связи в фоне и после перезагрузки телефона
• Статус коллеги рядом с контактом, если АТС его отдаёт
• Вход по QR-коду от администратора
• Своя записная книжка и, по желанию, контакты телефона

ОФОРМЛЕНИЕ НА ВЫБОР
• Шесть стилей интерфейса со светлой и тёмной темой
• Восемь значков для рабочего стола, несколько способов ответить на звонок
• Девять языков: русский, узбекский, английский, немецкий, испанский, французский, итальянский, португальский, турецкий

ПРИВАТНОСТЬ
• Без рекламы, аналитики и учётных записей: приложение общается только с вашей АТС
• Сервисы Google не нужны
• Пароль хранится в защищённом хранилище Android; история и контакты не покидают телефон

ЧТО НУЖНО ОТ АТС
SIP поверх WebSocket (лучше wss://), звук WebRTC (ICE, DTLS-SRTP), кодеки Opus, G.722 или G.711. Обычный SIP по UDP или TCP не поддерживается. Телефон должен видеть АТС напрямую.

Исходный код, инструкция по настройке и обратная связь: %s''' % LINK,
    ),
    'uz': dict(
        title='SADO: SIP-softfon',
        short='Kompaniyangiz ATSi uchun ochiq kodli softfon: WebSocket orqali SIP, WebRTC',
        full='''SADO — Android uchun bepul, ochiq kodli softfon. U oʻzingizning ATSingizga ulanadi: Asterisk, FreePBX, FreeSWITCH, Kamailio hamda WebSocket orqali SIP va WebRTC ovozini qoʻllab-quvvatlaydigan boshqa serverlar.

QOʻNGʻIROQLAR
• Sifatli ovozli kiruvchi va chiquvchi qoʻngʻiroqlar (Opus, G.722)
• Ushlab turish, mikrofonni oʻchirish, dinamik, Bluetooth va simli garnitura, raqam terish
• Ikkinchi qoʻngʻiroq: javob berish va ikki suhbat orasida almashish
• Qoʻngʻiroqni oʻtkazish — darhol yoki hamkasb bilan gaplashgandan keyin
• «Bezovta qilinmasin», javobsiz qoʻngʻiroqlar haqida bildirishnoma, oʻz ohangingiz
• tel: va sip: havolalari raqam terishni ochadi

OFISDA ISHLASH UCHUN
• Fonda va telefon qayta yoqilgandan keyin ham aloqada qoladi
• ATS bersa, kontakt yonida hamkasbning holati koʻrinadi
• Administrator bergan QR-kod orqali kirish
• Oʻz kontaktlaringiz va xohlasangiz, telefon kontaktlari

KOʻRINISHNI TANLANG
• Yorugʻ va qorongʻi mavzuli oltita interfeys uslubi
• Ish stoli uchun sakkizta belgi, qoʻngʻiroqqa javob berishning bir necha usuli
• Toʻqqizta til: oʻzbek, rus, ingliz, nemis, ispan, fransuz, italyan, portugal, turk

MAXFIYLIK
• Reklama, tahlil va hisob yozuvlarisiz: ilova faqat sizning ATSingiz bilan bogʻlanadi
• Google xizmatlari kerak emas
• Parol Android himoyalangan xotirasida saqlanadi; tarix va kontaktlar telefondan chiqmaydi

ATSDAN NIMA KERAK
WebSocket orqali SIP (wss:// tavsiya etiladi), WebRTC ovozi (ICE, DTLS-SRTP), Opus, G.722 yoki G.711 kodeklari. UDP yoki TCP orqali oddiy SIP qoʻllab-quvvatlanmaydi. Telefon ATSga toʻgʻridan-toʻgʻri ulana olishi kerak.

Manba kodi, sozlash yoʻriqnomasi va fikr-mulohazalar: %s''' % LINK,
    ),
    'de-DE': dict(
        title='SADO: SIP-Softphone',
        short='Open-Source-Softphone für Ihre Telefonanlage: SIP über WebSocket, WebRTC-Audio',
        full='''SADO ist ein kostenloses Open-Source-Softphone für Android, das sich mit Ihrer eigenen Telefonanlage verbindet: Asterisk, FreePBX, FreeSWITCH, Kamailio und andere Server, die SIP über WebSocket mit WebRTC-Audio anbieten.

ANRUFE
• Ein- und ausgehende Anrufe in HD-Qualität (Opus, G.722)
• Halten, Stummschalten, Lautsprecher, Bluetooth- und Kabel-Headsets, Tastatur für Nachwahl
• Anklopfen: zweiten Anruf annehmen und zwischen beiden wechseln
• Weiterleiten – direkt oder nach Rückfrage
• „Nicht stören“, Hinweis auf verpasste Anrufe, eigener Klingelton
• tel:- und sip:-Links öffnen die Wähltastatur

FÜR DAS BÜRO
• Bleibt im Hintergrund und nach einem Neustart erreichbar
• Status der Kollegen neben den Kontakten, wenn die Telefonanlage ihn liefert
• Anmeldung per QR-Code vom Administrator
• Eigene Kontakte und auf Wunsch das Adressbuch des Telefons

NACH IHREM GESCHMACK
• Sechs Oberflächenstile mit hellem und dunklem Design
• Acht App-Symbole, mehrere Arten, einen Anruf anzunehmen
• Neun Sprachen: Deutsch, English, Español, Français, Italiano, Português, Türkçe, Русский, Oʻzbek

PRIVATSPHÄRE
• Keine Werbung, keine Analyse, keine Konten: Die App spricht nur mit Ihrer Telefonanlage
• Keine Google-Dienste erforderlich
• Das Passwort liegt im Android Keystore; Anrufliste und Kontakte verlassen das Telefon nicht

WAS IHRE TELEFONANLAGE BRAUCHT
SIP über WebSocket (wss:// empfohlen), WebRTC-Medien (ICE, DTLS-SRTP), Opus, G.722 oder G.711. Klassisches SIP über UDP oder TCP wird nicht unterstützt. Das Telefon muss die Telefonanlage direkt erreichen können.

Quellcode, Einrichtungsanleitung und Fehlermeldungen: %s''' % LINK,
    ),
    'es-ES': dict(
        title='SADO: softphone SIP',
        short='Softphone de código abierto para tu centralita: SIP sobre WebSocket y WebRTC',
        full='''SADO es un softphone gratuito y de código abierto para Android que se conecta a tu propia centralita: Asterisk, FreePBX, FreeSWITCH, Kamailio y otros servidores que ofrecen SIP sobre WebSocket con audio WebRTC.

LLAMADAS
• Llamadas entrantes y salientes con audio HD (Opus, G.722)
• Retener, silenciar, altavoz, auriculares Bluetooth y con cable, teclado DTMF
• Llamada en espera: responde a una segunda llamada y cambia entre las dos
• Transferencia directa o tras consultar con tu compañero
• No molestar, aviso de llamadas perdidas, tu propio tono
• Los enlaces tel: y sip: abren el teclado

PENSADO PARA LA OFICINA
• Sigue disponible en segundo plano y tras reiniciar el teléfono
• Estado de tus compañeros junto a los contactos, si la centralita lo ofrece
• Inicio de sesión escaneando un código QR de tu administrador
• Tus propios contactos y, si quieres, la agenda del teléfono

A TU GUSTO
• Seis estilos de interfaz con tema claro y oscuro
• Ocho iconos para la pantalla de inicio y varias formas de responder
• Nueve idiomas: Español, English, Deutsch, Français, Italiano, Português, Türkçe, Русский, Oʻzbek

PRIVACIDAD
• Sin anuncios, sin analíticas, sin cuentas: la app solo habla con tu centralita
• No necesita servicios de Google
• La contraseña se guarda en el almacén seguro de Android; el historial y los contactos no salen del teléfono

QUÉ NECESITA TU CENTRALITA
SIP sobre WebSocket (se recomienda wss://), audio WebRTC (ICE, DTLS-SRTP), Opus, G.722 o G.711. No se admite el SIP clásico sobre UDP o TCP. El teléfono debe poder llegar directamente a la centralita.

Código fuente, guía de configuración e incidencias: %s''' % LINK,
    ),
    'fr-FR': dict(
        title='SADO : softphone SIP',
        short='Softphone libre pour votre standard : SIP sur WebSocket, audio WebRTC',
        full='''SADO est un softphone gratuit et open source pour Android qui se connecte à votre propre standard téléphonique : Asterisk, FreePBX, FreeSWITCH, Kamailio et les autres serveurs proposant SIP sur WebSocket avec l'audio WebRTC.

APPELS
• Appels entrants et sortants en audio HD (Opus, G.722)
• Mise en attente, micro coupé, haut-parleur, casques Bluetooth et filaires, clavier DTMF
• Double appel : répondez à un second appel et passez de l'un à l'autre
• Transfert direct ou après consultation
• Ne pas déranger, notification d'appels manqués, votre propre sonnerie
• Les liens tel: et sip: ouvrent le clavier

PENSÉ POUR LE BUREAU
• Reste joignable en arrière-plan et après un redémarrage
• Statut de vos collègues à côté des contacts, si le standard le fournit
• Connexion en scannant un QR code fourni par votre administrateur
• Vos propres contacts et, si vous le souhaitez, le carnet d'adresses du téléphone

À VOTRE GOÛT
• Six styles d'interface avec thèmes clair et sombre
• Huit icônes pour l'écran d'accueil, plusieurs façons de répondre
• Neuf langues : Français, English, Deutsch, Español, Italiano, Português, Türkçe, Русский, Oʻzbek

VIE PRIVÉE
• Ni publicité, ni statistiques, ni compte : l'application ne parle qu'à votre standard
• Aucun service Google requis
• Le mot de passe est conservé dans le Keystore Android ; l'historique et les contacts ne quittent pas le téléphone

CE QU'IL FAUT À VOTRE STANDARD
SIP sur WebSocket (wss:// recommandé), média WebRTC (ICE, DTLS-SRTP), Opus, G.722 ou G.711. Le SIP classique sur UDP ou TCP n'est pas pris en charge. Le téléphone doit pouvoir joindre le standard directement.

Code source, guide d'installation et signalement de problèmes : %s''' % LINK,
    ),
    'it-IT': dict(
        title='SADO: softphone SIP',
        short='Softphone open source per il tuo centralino: SIP su WebSocket, audio WebRTC',
        full='''SADO è un softphone gratuito e open source per Android che si collega al tuo centralino: Asterisk, FreePBX, FreeSWITCH, Kamailio e altri server che offrono SIP su WebSocket con audio WebRTC.

CHIAMATE
• Chiamate in entrata e in uscita con audio HD (Opus, G.722)
• Attesa, microfono muto, altoparlante, cuffie Bluetooth e con cavo, tastiera DTMF
• Avviso di chiamata: rispondi a una seconda chiamata e passa dall'una all'altra
• Trasferimento diretto o dopo aver parlato con il collega
• Non disturbare, notifica delle chiamate perse, la tua suoneria
• I link tel: e sip: aprono la tastiera

PENSATO PER L'UFFICIO
• Resta raggiungibile in background e dopo il riavvio
• Stato dei colleghi accanto ai contatti, se il centralino lo fornisce
• Accesso inquadrando un codice QR ricevuto dall'amministratore
• I tuoi contatti e, se vuoi, la rubrica del telefono

A MODO TUO
• Sei stili di interfaccia con tema chiaro e scuro
• Otto icone per la schermata Home, diversi modi per rispondere
• Nove lingue: Italiano, English, Deutsch, Español, Français, Português, Türkçe, Русский, Oʻzbek

RISERVATEZZA
• Niente pubblicità, niente statistiche, niente account: l'app parla solo con il tuo centralino
• Non servono i servizi Google
• La password è custodita nel Keystore di Android; cronologia e contatti non lasciano il telefono

COSA SERVE AL CENTRALINO
SIP su WebSocket (consigliato wss://), audio WebRTC (ICE, DTLS-SRTP), Opus, G.722 o G.711. Il SIP classico su UDP o TCP non è supportato. Il telefono deve poter raggiungere direttamente il centralino.

Codice sorgente, guida alla configurazione e segnalazioni: %s''' % LINK,
    ),
    'pt-BR': dict(
        title='SADO: softphone SIP',
        short='Softphone de código aberto para o PABX da sua empresa: SIP sobre WebSocket',
        full='''SADO é um softphone gratuito e de código aberto para Android que se conecta ao seu próprio PABX: Asterisk, FreePBX, FreeSWITCH, Kamailio e outros servidores que oferecem SIP sobre WebSocket com áudio WebRTC.

CHAMADAS
• Chamadas recebidas e efetuadas com áudio HD (Opus, G.722)
• Espera, mudo, viva-voz, fones Bluetooth e com fio, teclado DTMF
• Chamada em espera: atenda uma segunda chamada e alterne entre as duas
• Transferência direta ou depois de falar com o colega
• Não perturbe, aviso de chamadas perdidas, seu próprio toque
• Links tel: e sip: abrem o teclado

FEITO PARA O ESCRITÓRIO
• Continua disponível em segundo plano e após reiniciar o celular
• Status dos colegas ao lado dos contatos, quando o PABX informa
• Login lendo um QR code do seu administrador
• Seus próprios contatos e, se quiser, a agenda do celular

DO SEU JEITO
• Seis estilos de interface com tema claro e escuro
• Oito ícones para a tela inicial, várias formas de atender
• Nove idiomas: Português, English, Deutsch, Español, Français, Italiano, Türkçe, Русский, Oʻzbek

PRIVACIDADE
• Sem anúncios, sem análises, sem contas: o app conversa apenas com o seu PABX
• Não precisa dos serviços do Google
• A senha fica no Keystore do Android; o histórico e os contatos não saem do celular

O QUE O SEU PABX PRECISA
SIP sobre WebSocket (wss:// recomendado), mídia WebRTC (ICE, DTLS-SRTP), Opus, G.722 ou G.711. O SIP clássico sobre UDP ou TCP não é compatível. O celular precisa alcançar o PABX diretamente.

Código-fonte, guia de configuração e relatos de problemas: %s''' % LINK,
    ),
    'tr-TR': dict(
        title='SADO: SIP softphone',
        short='Şirket santraliniz için açık kaynak softphone: WebSocket üzerinden SIP, WebRTC',
        full='''SADO, Android için ücretsiz ve açık kaynaklı bir softphone'dur. Kendi santralinize bağlanır: Asterisk, FreePBX, FreeSWITCH, Kamailio ve WebSocket üzerinden SIP ile WebRTC sesini destekleyen diğer sunucular.

ARAMALAR
• HD sesle gelen ve giden aramalar (Opus, G.722)
• Bekletme, sessize alma, hoparlör, Bluetooth ve kablolu kulaklık, DTMF tuşları
• Arama bekletme: ikinci aramayı cevaplayın ve ikisi arasında geçiş yapın
• Doğrudan veya danışarak aktarma
• Rahatsız etmeyin, cevapsız arama bildirimi, kendi zil sesiniz
• tel: ve sip: bağlantıları tuş takımını açar

OFİS İÇİN TASARLANDI
• Arka planda ve telefon yeniden başlatıldıktan sonra ulaşılabilir kalır
• Santral bildiriyorsa, kişilerin yanında iş arkadaşlarınızın durumu
• Yöneticinizin verdiği QR kodu okutarak giriş
• Kendi kişileriniz ve isterseniz telefon rehberi

SİZE GÖRE
• Açık ve koyu temalı altı arayüz stili
• Ana ekran için sekiz simge, aramayı cevaplamanın birkaç yolu
• Dokuz dil: Türkçe, English, Deutsch, Español, Français, Italiano, Português, Русский, Oʻzbek

GİZLİLİK
• Reklam yok, analiz yok, hesap yok: uygulama yalnızca santralinizle konuşur
• Google hizmetleri gerekmez
• Şifre Android Keystore'da saklanır; geçmiş ve kişiler telefondan çıkmaz

SANTRALİNİZDE NE OLMALI
WebSocket üzerinden SIP (wss:// önerilir), WebRTC ses (ICE, DTLS-SRTP), Opus, G.722 veya G.711. UDP veya TCP üzerinden klasik SIP desteklenmez. Telefon santrale doğrudan ulaşabilmelidir.

Kaynak kodu, kurulum kılavuzu ve sorun bildirimi: %s''' % LINK,
    ),
}

# Что нового по версиям: код версии — это versionCode APK для arm64 (2000 + номер сборки из pubspec.yaml).
CHANGELOGS = {
    '2008': {
        'en-US': '''• Company directory: colleagues from your PBX appear in Contacts, grouped by department
• Conference: "Merge" joins your two calls into one room
• Recording on demand: a "Record" button in a call asks the PBX to record it
All three appear only when your PBX offers them; with other PBXes nothing changes''',
        'ru-RU': '''• Справочник сотрудников: коллеги с вашей АТС появляются в «Контактах», по отделам
• Конференция: «Объединить» соединяет два ваших разговора в один
• Запись по кнопке: кнопка «Записать» в разговоре просит АТС записать его
Всё это появляется, только если ваша АТС это умеет; с другими АТС ничего не меняется''',
    },
    '2007': {
        'en-US': '''• QR scanner: works on devices that only have a front camera, uses less memory, and no longer reports a failed start as a missing camera permission
• Reconnecting to the PBX right after a disconnect is more reliable
• Fixes for the experimental "Wake on call" mode (builds with Google push only)''',
        'ru-RU': '''• Сканер QR-кода: работает на устройствах только с передней камерой, расходует меньше памяти и не выдаёт сбой запуска за отказ в доступе к камере
• Повторное подключение к АТС сразу после отключения стало надёжнее
• Исправления пробного режима «Будить по звонку» (только в сборках с push от Google)''',
    },
    '2006': {
        'en-US': '''• The download is half the size: about 17 MB instead of 34
• Ending a call is more reliable
• The call engine is now checked against a real PBX before each release: calls, hold, call waiting, both kinds of transfer
• Experimental "Wake on call" mode for builds with Google push; it is not part of the regular APKs''',
        'ru-RU': '''• Файл для скачивания стал вдвое меньше: около 17 МБ вместо 34
• Завершение звонка стало надёжнее
• Движок звонков теперь проверяется на настоящей АТС перед каждым выпуском: звонки, удержание, второй звонок, оба вида перевода
• Пробный режим «Будить по звонку» для сборок с push от Google; в обычные APK он не входит''',
    },
    '2005': {
        'en-US': '''• QR scanner on the sign-in screen: point the camera at the code from your administrator and the form is filled in
• Colleague status next to your contacts (available, on a call, offline) when the PBX provides it
• New permission: Camera, asked only when you open the scanner''',
        'ru-RU': '''• Сканер QR-кода на экране входа: наведите камеру на код от администратора — форма заполнится
• Статус коллеги рядом с контактом (свободен, разговаривает, не в сети), если АТС его отдаёт
• Новое разрешение: камера, спрашивается только при открытии сканера''',
    },
}


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text.strip() + '\n')


def main():
    problems = []
    for locale, item in LISTING.items():
        for name, limit in (('title', MAX_TITLE), ('short', MAX_SHORT), ('full', MAX_FULL)):
            if len(item[name]) > limit:
                problems.append('%s: %s длиннее %d знаков (%d)' % (locale, name, limit, len(item[name])))
    for code, texts in CHANGELOGS.items():
        for locale, text in texts.items():
            if len(text) > MAX_CHANGELOG:
                problems.append('%s: список изменений %s длиннее %d знаков (%d)' % (locale, code, MAX_CHANGELOG, len(text)))
    missing = [name for name in SCREENSHOTS if not os.path.exists(os.path.join(SHOTS, name + '.png'))]
    if missing:
        problems.append('нет снимков в build/shots: %s (сначала снимите их, см. начало файла)' % ', '.join(missing))
    if problems:
        sys.exit('Описание не разложено:\n  ' + '\n  '.join(problems))

    for locale, item in LISTING.items():
        base = os.path.join(OUT, locale)
        write(os.path.join(base, 'title.txt'), item['title'])
        write(os.path.join(base, 'short_description.txt'), item['short'])
        write(os.path.join(base, 'full_description.txt'), item['full'])
    for code, texts in CHANGELOGS.items():
        for locale, text in texts.items():
            write(os.path.join(OUT, locale, 'changelogs', code + '.txt'), text)

    images = os.path.join(OUT, 'en-US', 'images', 'phoneScreenshots')
    shutil.rmtree(images, ignore_errors=True)
    os.makedirs(images)
    for number, name in enumerate(SCREENSHOTS, start=1):
        shutil.copyfile(os.path.join(SHOTS, name + '.png'), os.path.join(images, '%d.png' % number))
    print('Готово: %d языков, %d снимков → %s' % (len(LISTING), len(SCREENSHOTS), os.path.relpath(OUT, ROOT)))


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    main()
