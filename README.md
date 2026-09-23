# ocs

Запуск кількох `opencode web` на різних портах і публікація їх у власному
Tailscale-тайнеті. Один скрипт, без залежностей.

```
ocs                   вибрати теку зі списку, вибрати порт, запустити
ocs ls                що працює зараз
ocs stop <порт|all>   зупинити інстанс
ocs expose <порт>     прокинути будь-який локальний порт у tailnet
ocs off <порт>        прибрати прокинутий порт
ocs help              довідка
```

## Вимоги

- [opencode](https://opencode.ai) у `PATH`
- [Tailscale](https://tailscale.com) з увімкненим MagicDNS і HTTPS
  (адмінка → DNS → **Enable HTTPS**)

## Встановлення

### Варіант 1 — символьне посилання (рекомендований)

Репозиторій лишається джерелом правди, `git pull` одразу оновлює команду.

```bash
git clone <URL> ~/Documents/pet_project/ocs
chmod +x ~/Documents/pet_project/ocs/ocs
sudo ln -sf ~/Documents/pet_project/ocs/ocs /usr/local/bin/ocs
```

### Варіант 2 — власна тека в PATH, без sudo

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

Двома змінними оточення, файлу конфіга немає:

| Змінна | Типово | Що робить |
|---|---|---|
| `OCS_ROOT` | `~/Documents` | де шукати теки проєктів |
| `OCS_PASS` | порожньо | пароль на веб-інтерфейс opencode |

Зручно закріпити в `~/.zshrc`:

```bash
export OCS_ROOT=~/Documents/pet_project
export OCS_PASS='...'
```

## Як це працює

1. `HOME` для процесу opencode підміняється на теку проєкту — пікер «Open
   project» у веб-інтерфейсі анкориться до `$HOME` і тому не показує решту
   диска. `XDG_CONFIG_HOME` і `XDG_DATA_HOME` лишаються справжніми, щоб
   opencode не загубив свій конфіг і сесії.
2. Сервер слухає тільки `127.0.0.1` — назовні порт не світиться.
3. `tailscale serve --bg --https=<порт> localhost:<порт>` публікує його
   всередині тайнету з валідним TLS-сертифікатом.
4. Реєстр запущеного лежить у `~/.ocs`, логи — у `.ocs.log` усередині теки
   кожного проєкту.

## Веб-термінал поруч

Щоб мати ще й звичайний shell у браузері:

```bash
brew install ttyd
ttyd -p 7681 -c user:пароль -W tmux new -A -s main
ocs expose 7681
```

`-W` обов'язковий (без нього термінал read-only), `tmux new -A` тримає
сесію між перезавантаженнями вкладки. Деталі — `docs/DECISIONS.md`, №11.

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
примонтованою лише текою проєкту. Див. `docs/DECISIONS.md`, рішення №8.
