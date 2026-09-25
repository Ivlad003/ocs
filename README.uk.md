# ocs

[English](README.md) · **Українська**

Запуск кількох `opencode web` на різних портах і публікація їх у власному
Tailscale-тайнеті. Один скрипт, без залежностей.

```
ocs [тека]            запустити поточну теку (або вказану), вибрати порт
ocs pick              вибір теки з навігацією (старт — поточна тека)
ocs ls                що працює зараз
ocs stop <порт|all>   зупинити інстанс
ocs term [шрифт]      веб-термінал ttyd (типово 25, порт 7681)
ocs expose <порт>     прокинути будь-який локальний порт у tailnet
ocs funnel <порт>     опублікувати локальний порт в інтернет (Funnel)
ocs off <порт>        прибрати прокинутий порт
ocs reset             зупинити ВСЕ, зняти правила tailscale serve, очистити реєстр
ocs help              довідка
```

```bash
ocs                   # дашборд для поточної теки — без пікера
ocs ~/projects/demo   # дашборд для вказаної теки
ocs pick              # браузер від поточної теки: номер — углиб, . — вибрати, .. — угору
ocs term 30           # термінал поруч, шрифт 30 — URL + QR
ocs term 30 7690      # те саме на своєму порту
ocs expose 8080       # опублікувати сторонній сервіс — URL + QR
ocs funnel 4096       # опублікувати порт 4096 для всього інтернету
ocs stop all          # погасити все, що запускав ocs
```

Як виглядає запуск:

```
$ ocs
Тека: /home/kosmodev/Documents/pet_project
Порт [4096]: ⏎
→ https://machine.tailnet.ts.net:4096
  код: Xj3kqPZtLm…
  лінк: https://machine.tailnet.ts.net:4096/connect#eyJ1cmxzIjpb…
  █▀▀▀▀▀█ ▀█▀█ █▀▀▀▀▀█ …   ← QR того самого лінка (якщо є qrencode)
```

Рядок `лінк:` відкриває дашборд уже залогіненим — opencode v2 завжди генерує
пароль сервера, а `ocs` вшиває його в лінк `/connect#…` (той самий формат,
що використовує `opencode pair`). QR-код кодує цей самий лінк.

## Вимоги

| Інструмент | Потрібен для | Сайт |
|---|---|---|
| Tailscale | всього | [tailscale.com](https://tailscale.com) |
| opencode | `ocs` (дашборди) | [opencode.ai](https://opencode.ai) |
| ttyd | лише `ocs term` | [доки ttyd](https://tsl0922.github.io/ttyd/) |
| qrencode | QR-код при запуску (необов'язково) | [libqrencode](https://fukuchi.org/works/qrencode/) |

Якщо чогось бракує, скрипт сам надрукує команди встановлення під твою
систему замість голого `command not found`.

### macOS

```bash
brew install --cask tailscale
brew install ttyd                              # лише для `ocs term`
brew install qrencode                          # необов'язково — QR-код при запуску
curl -fsSL https://opencode.ai/install | bash  # або: npm i -g opencode-ai
tailscale up
```

### Linux

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo apt install ttyd                          # лише для `ocs term`
sudo apt install qrencode                      # необов'язково — QR-код при запуску
curl -fsSL https://opencode.ai/install | bash
sudo tailscale up
```

### Windows

PowerShell запускати **від імені адміністратора** — інакше `tailscale serve`
не працюватиме.

```powershell
winget install tailscale.tailscale
winget install OpenJS.NodeJS.LTS
npm install -g opencode-ai
tailscale up

# лише для `ocs term` — спершу scoop, якщо його немає
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
irm get.scoop.sh | iex
scoop install ttyd
scoop install qrencode                          # необов'язково — QR-код при запуску
```

Глобальні npm-пакети лягають у `%APPDATA%\npm`, тож перезапусти термінал,
якщо `opencode` не видно. Якщо `tailscale` не в `PATH`, він тут:
`C:\Program Files\Tailscale\tailscale.exe`.

### Одноразовий крок для всіх систем

Увімкнути HTTPS для тайнету, інакше `tailscale serve --https` приймає
конфіг, але сертифікат не видається:

[login.tailscale.com/admin/dns](https://login.tailscale.com/admin/dns) →
MagicDNS увімкнути → **Enable HTTPS**

Скрипти використовують синтаксис Tailscale CLI 1.52+ (`tailscale serve` /
`tailscale funnel`), тож оновлюй клієнт. Для `ocs funnel` є ще один
одноразовий крок — атрибут `funnel` у тайнеті, див.
[Публікація в інтернет (funnel)](#публікація-в-інтернет-funnel).

## Встановлення

### Однією командою

```bash
curl -fsSL https://raw.githubusercontent.com/Ivlad003/ocs/main/install.sh | sh
```

Кладе `ocs` у `~/.local/bin` (інша тека — `OCS_INSTALL_DIR`, гілка/тег —
`OCS_REF`) і підкаже, якщо цієї теки немає в `PATH`. Повторний запуск —
оновлення. Windows (PowerShell 7):

```powershell
irm https://raw.githubusercontent.com/Ivlad003/ocs/main/install.ps1 | iex
```

Кладе `ocs.ps1` у `~\.ocs-bin` і додає теку в `PATH` користувача.

### З клону — символьне посилання


Репозиторій лишається джерелом правди, `git pull` одразу оновлює команду.

```bash
git clone <URL> ~/Documents/pet_project/ocs
chmod +x ~/Documents/pet_project/ocs/ocs
sudo ln -sf ~/Documents/pet_project/ocs/ocs /usr/local/bin/ocs
```

### З клону — власна тека в PATH, без sudo

```bash
mkdir -p ~/bin
ln -sf ~/Documents/pet_project/ocs/ocs ~/bin/ocs
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Перевірка

```bash
which ocs     # має показати шлях
ocs help
```

## Налаштування

Змінними оточення, файлу конфіга немає:

| Змінна | Типово | Що робить |
|---|---|---|
| `OCS_ROOT` | `~/Documents` | межа навігації `ocs pick`, якщо його запущено всередині; `ocs <ім'я>` шукає теки тут |
| `OCS_AUTO` | `1` | автономний режим: агент не питає дозволів (`0` — питати як зазвичай) |

Автономний режим — серверний аналог `opencode --auto` (у `serve` / `web`
такого прапорця немає): ocs ставить `OPENCODE_PERMISSION='{"*":"allow","external_directory":"ask"}'`,
тож дозволено все, крім явно забороненого у твоєму конфігу, а доступ до файлів
поза текою проєкту все одно з питанням. `OCS_AUTO=0 ocs` лишає твій конфіг
дозволів як є.

Зручно закріпити в `~/.zshrc`:

```bash
export OCS_ROOT=~/Documents/pet_project
```

## Як це працює

1. `HOME` для процесу opencode підміняється на теку проєкту — пікер «Open
   project» у веб-інтерфейсі анкориться до `$HOME` і тому не показує решту
   диска. `XDG_CONFIG_HOME` і `XDG_DATA_HOME` лишаються справжніми, щоб
   opencode не загубив свій конфіг і сесії.
2. Сервер слухає тільки `127.0.0.1` — назовні порт не світиться.
3. `tailscale serve --bg --https=<порт> localhost:<порт>` публікує його
   всередині тайнету з валідним TLS-сертифікатом; публікація в інтернет —
   свідома, лише через `ocs funnel` (`tailscale funnel`, див. нижче).
4. Реєстр запущеного лежить у `~/.ocs`, логи — у `.ocs.log` усередині теки
   кожного проєкту.
5. opencode v2 завжди генерує пароль сервера. `ocs` показує його при запуску
   як `код: …`, плюс лінк в один клік (`/connect#…`, той самий формат, що в
   `opencode pair`), який логінить браузер автоматично — і QR-код із нього,
   якщо встановлено `qrencode`. Пароль також зберігається у `.ocs.log` проєкту.

## Публікація в інтернет (funnel)

`tailscale serve` публікує всередині тайнету, а `ocs funnel` — на весь
інтернет через
[Tailscale Funnel](https://tailscale.com/docs/reference/tailscale-cli/funnel):

```bash
ocs funnel 4096      # спитає funnel-порт, типово 443
```

- Funnel-порти обмежені трьома: **443, 8443 і 10000** — `ocs` спитає, який
  використати (типово `443`). На порту 443 URL буде без порту.
- Одноразово: тайнет має видати атрибут `funnel`
  ([login.tailscale.com/admin/acls](https://login.tailscale.com/admin/acls) →
  `nodeAttrs: [{"target": ["*"], "attr": ["funnel"]}]`) і мати ввімкнений
  HTTPS. `ocs funnel` перевіряє обидва і друкує інструкції, замість того щоб
  зависнути в інтерактивному воркфлоу `tailscale funnel`.
- Зняти публікацію: `ocs off <funnel-порт>` (наприклад `ocs off 443`).
  Funnel-публікації не потрапляють до реєстру — як і `expose`.
- Інстанси opencode зберігають свій пароль сервера, але все, що ти публікуєш
  через funnel, бачить увесь інтернет: публікуй так лише те, що виклав би
  публічно в будь-якому разі.

## Веб-термінал поруч

Щоб мати ще й звичайний shell у браузері:

```bash
brew install ttyd
ocs term        # шрифт 25, порт 7681
ocs term 30     # шрифт 30
ocs stop 7681   # зупинити
```

Під капотом:

```bash
ttyd -i lo0 -p 7681 -W -t fontSize=25 -t lineHeight=1.2 -t scrollback=5000 \
  tmux new -A -s term
tailscale serve --bg --https=7681 localhost:7681
```

`-W` обов'язковий (без нього термінал read-only), `-i lo0` теж, якщо порт
уже опублікований — інакше конфлікт із tailscaled за той самий порт.

Без пароля свідомо: `-c user:pass` ламає websocket-апгрейд, бо браузер не
передає Basic Auth у WebSocket-handshake. Периметр тут — тайнет.

## Windows

`ocs.ps1` — порт на PowerShell, команди ті самі:

```powershell
.\ocs.ps1 term 30
.\ocs.ps1 ls
```

Глобальною командою робиться функцією в профілі (`notepad $PROFILE`):

```powershell
function ocs { & "$HOME\Documents\pet_project\ocs\ocs.ps1" @args }
```

Особливості Windows:

- потрібен PowerShell 7 (`pwsh`); якщо скрипти заблоковані —
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
- `tailscale serve` вимагає **адмінських прав** — запускай PowerShell від
  імені адміністратора, інакше публікація впаде
- підміняються і `HOME`, і `USERPROFILE` — на Windows пікер проєктів іде
  саме за другим
- `ocs term` працює: ttyd має нативну підтримку Windows з версії 1.7.0
  (ConPTY, Windows 10+), ставиться через `scoop install ttyd`. Запускає
  `pwsh` замість `tmux`, тож сесія не переживає перезавантаження вкладки —
  довгі задачі краще запускати відчепленими процесами
  (`Start-Process -WindowStyle Hidden`) або через Task Scheduler
- на Windows ttyd біндиться на `0.0.0.0` і не має аналога `-i lo0`, тому
  `ocs term` публікує термінал на **іншому** порту, ніж слухає ttyd

## Мінімальна альтернатива

Якщо скрипт зайвий — те саме двома функціями в `~/.zshrc`:

```bash
oc() {
  local p=${1:-4096}
  tailscale serve --bg --https=$p localhost:$p
  HOME=$PWD XDG_CONFIG_HOME=~/.config XDG_DATA_HOME=~/.local/share \
    opencode web --hostname 127.0.0.1 --port $p
}
ocoff() { tailscale serve --https=${1:-4096} off; }
```

## Обмеження

Підміна `HOME` і правила `permission` в `opencode.json` — це **guardrails, не
пісочниця**. Інструмент `bash` усередині агента може вийти за межі проєкту.
Якщо потрібна справжня ізоляція — запускати opencode в контейнері з
примонтованою лише текою проєкту.
