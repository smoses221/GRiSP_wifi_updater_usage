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

## The raw instructions
```erlang
===> Instructions to update GRiSP2 software on the board with grisp_updater:
     NOTE: the software running on the board MUST run grisp_updater by adding the grisp_updater_grisp2 dependency.
    - Unpack the software update package in some local directory:
        $ mkdir -p releases/GRiSP_wifi_updater_test/0.2.0
        $ tar -C releases/GRiSP_wifi_updater_test/0.2.0 -xvf _grisp/update/grisp2.GRiSP_wifi_updater_test.0.2.0.tar
    - Start a local HTTP server to serve the package:
        $ http-server ./releases -p 8000
    - Open a serial console to the GRiSP board:
        $ screen /dev/ttyUSB1 115200
    - On the GRiSP2 console, start the update process:
        $ grisp_updater:update(<<"http://192.168.129.88:8000/GRiSP_wifi_updater_test/0.2.0">>).
    - Reset the GRiSP2 board using the onboard reset button.
    - Validate the new software version on the GRiSP2 console:
        $ grisp_updater:validate().
```
These are transform to make commands which do all of this automatically.

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

Nodes are named `board@<hostname>` (`-sname board` in `grisp.ini.mustache`, the
hostname is `grisp-` + the board serial); the cookie is `grisp`:

```sh
erl -sname dev -setcookie grisp -remsh board@grisp-001024
```

## Manual deploy to SD card

```sh
rebar3 grisp deploy
```

## Using this in another project

Replace `myapp` below with your application name.

**1. Copy the tooling** into the project root:

```sh
cp Makefile <project>/
mkdir -p <project>/scripts && cp scripts/grisp_fleet.escript <project>/scripts/
echo "releases" >> <project>/.gitignore
```

**2. Edit the top of the `Makefile`:** set `APP := myapp`, and adjust
`BOARDS` and `HOST_IP` if needed. `APP` is used both as the app name
(`src/$(APP).app.src`) and as the release name.

**3. `rebar.config`:** add the dependency, and make the release name and
version match the app (same name as `APP`, same version as `{vsn, ...}` in the
`.app.src`, or `make bump` stops with `rebar.config not updated`):

```erlang
{deps, [
    grisp,
    grisp_updater_grisp2,
    ...
]}.

{relx, [
    {release, {myapp, "0.1.0"}, [{epmd, none}, myapp]}
]}.
```

**4. `src/myapp.app.src`:** add `grisp_updater_grisp2` to `applications`:

```erlang
{applications, [kernel, stdlib, grisp, grisp_updater_grisp2]},
```

**5. `config/sys.config`:** add these two sections (the file must end with a `.`):

```erlang
[
    {grisp_updater, [
        {system, {grisp_updater_grisp2, #{}}},
        {sources, [
            {grisp_updater_tarball, #{}},
            {grisp_updater_http, #{backend => {grisp_updater_grisp2, #{}}}}
        ]}
    ]},
    {grisp_cryptoauth, [
        {tls_use_client_certificate, false},
        {tls_verify, verify_none}
    ]}
].
```

**6. `grisp/grisp2/common/deploy/files/grisp.ini.mustache`:** copy it from this
project, or make sure the `args` line contains `-sname board -setcookie grisp`
(they must match `NODE` and `COOKIE` in the `Makefile`). Keep only the
`.mustache` version of this file.

**7. Custom Erlang build only:** if `rebar.config` has a `{build, [{toolchain, ...}]}`
entry, rebuild Erlang so it includes the `grisp_cryptoauth` NIF, otherwise the
board crashes at boot with `grisp_cryptoauth_drv: 'file not found'`:

```sh
rebar3 grisp build
```

**8. First install** (the board must end up running from eMMC):

```sh
rebar3 grisp deploy   # to the SD card, then boot the board from it
make pack push        # writes the eMMC
# remove the SD card, press the reset button
make validate
```

From then on, use `make release`, `make info` and `make validate`.

If the boards are still running a version with another node name, pass it
once: `make release NODE=<old name>`.

Made by JL
