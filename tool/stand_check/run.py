"""Проверка движка звонков SADO на настоящей АТС — без телефона.

Что делает: собирает проверочную страницу (tool/stand_check/main.dart), открывает её в Chrome
с поддельным микрофоном и ждёт итогов. Страница запускает настоящий движок приложения и просит
этот скрипт «позвонить с АТС» — скрипт выполняет команду в консоли Asterisk.

Проверяется обмен с АТС (регистрация, звонки, удержание, второй звонок, перевод с консультацией,
статусы), а не звук и не код Android.

Нужны: Flutter, Chrome, доступ к консоли Asterisk и тестовый номер. Настройки — переменными окружения:

  SADO_STAND_WS         адрес WebSocket АТС, например ws://127.0.0.1:8088/ws
  SADO_STAND_NUMBER     тестовый номер, например 1003
  SADO_STAND_PASSWORD   его пароль (или SADO_STAND_PASSWORD_FILE — файл с паролем)
  SADO_STAND_DOMAIN     домен SIP, если отличается от адреса подключения (необязательно)
  SADO_STAND_ECHO       номер, который сам отвечает (эхо-тест); по умолчанию *43
  SADO_STAND_CONTEXT    контекст плана набора, из которого звонят внутренние номера; по умолчанию internal
  SADO_STAND_ASTERISK   как вызвать консоль Asterisk; по умолчанию «asterisk -rx»
                        (например: «wsl.exe -u root asterisk -rx» или «ssh pbx asterisk -rx»)
  SADO_STAND_CHROME     путь к Chrome, если он не найден сам
  SADO_STAND_PUSH_HINT  поставьте 1, если АТС показывает коллегам «спящий» номер с адресом push как свободный
                        (тогда проверяется и это: статус номера во сне и после выключения режима)

Запуск из корня проекта:  python tool/stand_check/run.py

Пароль попадает в собранную страницу (папка build/stand_check) — после прогона скрипт её удаляет.

Про библиотеку sip_ua: её версия 1.1.0 не собирается для браузера (одна строка в веб-транспорте).
На время сборки страницы скрипт подставляет исправленную копию через pubspec_overrides.yaml
и затем убирает подстановку. Зависимости самого приложения при этом не меняются.
Скрипт слушает только 127.0.0.1 и выполняет только перечисленные ниже команды.
"""

import http.server
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILD = os.path.join(ROOT, 'build', 'stand_check')
SIP_UA_COPY = os.path.join(ROOT, 'build', 'stand_check_sip_ua')
OVERRIDES = os.path.join(ROOT, 'pubspec_overrides.yaml')
LIMIT_SECONDS = 420


def env(name, default=None):
    value = os.environ.get(name, default)
    if value is None or value == '':
        sys.exit('Не задана переменная окружения %s (см. описание в начале файла).' % name)
    return value


def password():
    path = os.environ.get('SADO_STAND_PASSWORD_FILE')
    if path:
        with open(path, encoding='utf-8') as f:
            return f.read().strip()
    return env('SADO_STAND_PASSWORD')


NUMBER = env('SADO_STAND_NUMBER')
CONTEXT = os.environ.get('SADO_STAND_CONTEXT', 'internal')
ASTERISK = shlex.split(os.environ.get('SADO_STAND_ASTERISK', 'asterisk -rx'), posix=os.name != 'nt')


def asterisk(command):
    """Выполняет одну команду консоли Asterisk и возвращает её вывод."""
    try:
        out = subprocess.run(ASTERISK + [command], capture_output=True, timeout=30).stdout
    except (OSError, subprocess.TimeoutExpired) as error:
        return 'ОШИБКА: %s' % error
    return out.replace(b'\x00', b'').decode('utf-8', 'replace')


def channels(ours):
    """Имена каналов нашего теста: [ours] — каналы самого номера, иначе — стороны «собеседников»."""
    names = []
    for line in asterisk('core show channels concise').splitlines():
        name = line.split('!')[0]
        if ours and name.startswith('PJSIP/%s-' % NUMBER):
            names.append(name)
        # «Собеседник» — вторая половина Local-канала (;2) или канал исходящего вызова к нам без моста.
        if not ours and name.startswith('Local/%s@' % NUMBER):
            names.append(name)
    return names


def contact():
    """Адреса регистрации нашего номера — строки «contact : …» из описания его записи на АТС."""
    lines = []
    for line in asterisk('pjsip show aor %s' % NUMBER).splitlines():
        name, _, value = line.partition(':')
        if name.strip() == 'contact' and value.strip():
            lines.append(value.strip())
    return '\n'.join(lines)


def hint():
    """Строка о нашем номере из списка подсказок состояния («State:Idle», «State:Unavailable» и т. п.)."""
    for line in asterisk('core show hints').splitlines():
        if line.startswith('%s@' % NUMBER):
            return ' '.join(line.split())
    return ''


def hangup_mine():
    for name in channels(True) + channels(False):
        asterisk('channel request hangup %s' % name)
    return 'ok'


# Команды, которые может попросить страница. Ничего другого скрипт не выполняет.
COMMANDS = {
    # Позвонить на наш номер; ответившего соединить с эхо-тестом. «Собеседник» — канал Local на АТС.
    'ring': lambda: asterisk('channel originate Local/%s@%s application Echo' % (NUMBER, CONTEXT)),
    'ring-bridged': lambda: asterisk('channel originate Local/%s@%s application Echo' % (NUMBER, CONTEXT)),
    'channels': lambda: '\n'.join(channels(False)),
    'channels-ours': lambda: '\n'.join(channels(True)),
    'hangup-mine': hangup_mine,
    # Адрес, под которым наш номер сейчас зарегистрирован на АТС (пусто — регистрации нет).
    'contact': lambda: contact(),
    # Как АТС сейчас показывает наш номер подписчикам на статус (строка из списка подсказок).
    'hint': lambda: hint(),
}

results = []
done = threading.Event()


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BUILD, **kwargs)

    def log_message(self, *args):
        pass

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get('Content-Length') or 0)).decode('utf-8', 'replace')
        reply = ''
        if self.path.startswith('/cmd/'):
            command = COMMANDS.get(self.path[len('/cmd/'):])
            if command is None:
                self.send_error(404)
                return
            reply = command()
        elif self.path == '/report':
            try:
                item = json.loads(body)
                kind, text = str(item.get('kind')), str(item.get('text'))
            except ValueError:
                kind, text = 'FAIL', 'непонятное сообщение страницы'
            results.append((kind, text))
            print('%s  %s' % ({'PASS': '[ok]  ', 'FAIL': '[СБОЙ]', 'DONE': '[итог]'}.get(kind, kind), text), flush=True)
            if kind == 'DONE':
                done.set()
        else:
            self.send_error(404)
            return
        data = reply.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def find_chrome():
    explicit = os.environ.get('SADO_STAND_CHROME')
    if explicit:
        return explicit
    candidates = [
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    for name in ('google-chrome', 'chromium', 'chromium-browser', 'chrome'):
        found = shutil.which(name)
        if found:
            return found
    sys.exit('Chrome не найден — укажите путь в SADO_STAND_CHROME.')


def flutter():
    return shutil.which('flutter') or sys.exit('Flutter не найден в PATH.')


def pub_get():
    run = subprocess.run([flutter(), 'pub', 'get'], cwd=ROOT, capture_output=True, text=True,
                         encoding='utf-8', errors='replace')
    if run.returncode != 0:
        sys.exit('flutter pub get не удался:\n' + (run.stdout + run.stderr)[-2000:])


def patch_sip_ua():
    """Подставляет копию sip_ua с исправленным веб-транспортом (только на время сборки страницы)."""
    if os.path.exists(OVERRIDES):
        sys.exit('В проекте уже есть pubspec_overrides.yaml — не трогаю его. Уберите файл и запустите снова.')
    with open(os.path.join(ROOT, '.dart_tool', 'package_config.json'), encoding='utf-8') as f:
        packages = json.load(f)['packages']
    uri = next(p['rootUri'] for p in packages if p['name'] == 'sip_ua')
    if not uri.startswith('file:///'):
        sys.exit('Не нашёл установленную sip_ua: ' + uri)
    source = uri[len('file:///'):] if os.name == 'nt' else uri[len('file://'):]
    shutil.rmtree(SIP_UA_COPY, ignore_errors=True)
    shutil.copytree(source, SIP_UA_COPY)
    path = os.path.join(SIP_UA_COPY, 'lib', 'src', 'transports', 'websocket_web_impl.dart')
    with open(path, encoding='utf-8') as f:
        code = f.read()
    broken = "WebSocket(_url, 'sip')"
    if broken in code:
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(code.replace(broken, "WebSocket(_url, 'sip'.toJS)"))
    with open(OVERRIDES, 'w', encoding='utf-8', newline='\n') as f:
        f.write('# Временный файл проверки на стенде (tool/stand_check/run.py). Можно удалить.\n'
                'dependency_overrides:\n  sip_ua:\n    path: build/stand_check_sip_ua\n')
    pub_get()


def unpatch_sip_ua():
    if os.path.exists(OVERRIDES):
        os.remove(OVERRIDES)
        pub_get()
    shutil.rmtree(SIP_UA_COPY, ignore_errors=True)


def build():
    defines = {
        'SADO_STAND_WS': env('SADO_STAND_WS'),
        'SADO_STAND_NUMBER': NUMBER,
        'SADO_STAND_PASSWORD': password(),
        'SADO_STAND_DOMAIN': os.environ.get('SADO_STAND_DOMAIN', ''),
        'SADO_STAND_ECHO': os.environ.get('SADO_STAND_ECHO', '*43'),
        'SADO_STAND_PUSH_HINT': os.environ.get('SADO_STAND_PUSH_HINT', ''),
    }
    # Пароль передаём сборке файлом, а не в командной строке; файл сразу удаляем.
    handle, path = tempfile.mkstemp(suffix='.json')
    try:
        with os.fdopen(handle, 'w', encoding='utf-8') as f:
            json.dump(defines, f)
        print('Собираю проверочную страницу…', flush=True)
        patch_sip_ua()
        run = subprocess.run(
            [flutter(), 'build', 'web', '--profile', '-t', 'tool/stand_check/main.dart', '-o', BUILD,
             '--dart-define-from-file=' + path, '--no-wasm-dry-run'],
            cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace',
        )
        if run.returncode != 0:
            sys.exit('Сборка не удалась:\n' + (run.stdout + run.stderr)[-3000:])
    finally:
        os.remove(path)
        unpatch_sip_ua()


def main():
    build()
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    profile = tempfile.mkdtemp(prefix='sado-stand-chrome-')
    browser = subprocess.Popen([
        find_chrome(), '--headless=new', '--no-first-run', '--disable-gpu',
        '--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream',
        '--autoplay-policy=no-user-gesture-required', '--user-data-dir=' + profile,
        'http://127.0.0.1:%d/' % server.server_address[1],
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print('Страница открыта, идут проверки…', flush=True)
    try:
        finished = done.wait(LIMIT_SECONDS)
    finally:
        browser.terminate()
        try:
            browser.wait(10)
        except subprocess.TimeoutExpired:
            browser.kill()
        server.shutdown()
        hangup_mine()
        time.sleep(1)
        shutil.rmtree(profile, ignore_errors=True)
        # В собранной странице лежит пароль тестового номера — не оставляем её на диске.
        shutil.rmtree(BUILD, ignore_errors=True)
    if not finished:
        print('[СБОЙ] страница не сообщила об итогах за %d с' % LIMIT_SECONDS)
        return 1
    return 1 if any(kind == 'FAIL' for kind, _ in results) else 0


if __name__ == '__main__':
    # Вывод по-русски должен читаться и в консоли Windows, и в файле.
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    sys.exit(main())
