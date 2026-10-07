# GRiSP_wifi_updater_test

Test application for over-the-air updates of GRiSP 2 boards using
[grisp_updater](https://hex.pm/packages/grisp_updater). LED 2 blinks in the
color set by `led_color` (in `config/sys.config` and the `.app.src`), so you
can see which version a board is running.

## How updates work

A GRiSP 2 board's eMMC has two system slots (0 and 1). An update is written to
the slot that is not running, then:

1. **Reboot:** the board boots the new slot *once*, on trial.
2. **Validate:** the new slot becomes the permanent one.

If the board reboots before validation, it rolls back to the previous slot.
A new update is refused while the running version is not validated
(`boot_system_not_validated`).

## Requirements

- Boards and this machine on the same network (`HOST_IP`, default
  `10.42.0.1`), with `grisp/default/common/deploy/files/wpa_supplicant.conf` set for that
  network.
- Boards running a version of this app (it includes `grisp_updater_grisp2`)
  from eMMC. For the first install, deploy to an SD card, run one update, then
  remove the SD card: a board always boots from an inserted SD card.

## Commands

| Command         | What it does                                                              |
|-----------------|---------------------------------------------------------------------------|
| `make release`  | `bump` + `pack` + `push` + `reboot`: the full update in one command        |
| `make bump`     | Increments the last digit of the version in the `.app.src` and `rebar.config` |
| `make pack`     | Builds the update package and unpacks it into `releases/<app>/<version>/`  |
| `make push`     | Serves `releases/` over HTTP on port 8000 and installs the current version on every board |
| `make reboot`   | Reboots the boards into the new version (on trial)                         |
| `make info`     | Shows each board's app version and slots (`boot`, `valid`, `next`)         |
| `make validate` | Keeps the running version permanently                                      |

Boards that are offline are skipped. A command fails only if a board that
answered reported an error, or if no board answered at all.

## Typical update

```sh
# 1. Change the code or led_color
make release      # build, install and reboot
make info         # after ~30 s: check the new version runs, boot != valid
make validate     # keep it (or `make reboot` again to roll back)
```

## Options

Override any of these on the command line, e.g. `make push BOARDS="grisp-001024"`:

| Variable  | Default                                  |
|-----------|------------------------------------------|
| `BOARDS`  | `grisp-001316 grisp-001300 grisp-002075 grisp-001021 grisp-001024` |
| `HOST_IP` | `10.42.0.1` (address the boards download from) |
| `PORT`    | `8000`                                   |

## Remote shell

The node name is case-sensitive and must be quoted; the cookie is `grisp`:

```sh
erl -sname dev -setcookie grisp -remsh 'GRiSP_wifi_updater_test@grisp-001024'
```

## Manual deploy to SD card

```sh
rebar3 grisp deploy
```

Made by JL
