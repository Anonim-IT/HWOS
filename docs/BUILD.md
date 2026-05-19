# Сборка HWOS из исходников

## Требования

- Arch Linux (или производная)
- `base-devel`, `git`, `archiso`

```bash
sudo pacman -S base-devel git archiso
```

## Клонирование

```bash
git clone https://github.com/Anonim-IT/HWOS.git
cd HWOS
```

## Сборка пакетов

Все пакеты собираются через `makepkg`:

```bash
# Сборка всех пакетов (в порядке зависимостей)
./custom-repo/hwos-repo-build-all.sh
```

Или по одному:

```bash
cd packages/hwos-configs && makepkg -s
cd packages/hwos-scripts && makepkg -s
cd packages/hwos-theme && makepkg -s
cd packages/hacker-shell && makepkg -s
cd packages/hwins && makepkg -s
cd packages/hwos-installer && makepkg -s
cd packages/hackerrub && makepkg -s
cd packages/hwos-kernel && makepkg -s
```

Порядок сборки важен из-за зависимостей:
1. `hwos-configs`
2. `hwos-scripts`
3. `hwos-theme`
4. `hacker-shell`
5. `hwins`
6. `hwos-installer`
7. `hackerrub`
8. `hwos-kernel`

## Сборка ISO

```bash
sudo ./scripts/build-iso.sh
```

ISO появится в `archiso/out/`.

## Локальный репозиторий

Собранные пакеты автоматически добавляются в локальный репозиторий.
Путь по умолчанию: `/var/lib/hwos/repo/x86_64/`

Для использования репозитория добавьте в `/etc/pacman.conf`:

```ini
[hwos]
SigLevel = Optional TrustAll
Server = file:///var/lib/hwos/repo/x86_64
```
