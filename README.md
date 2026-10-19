# OpenWrt Network LED

A lightweight, modular network status monitor with RGB LED indication for OpenWrt.

OpenWrt Network LED monitors network connectivity through independent checks and uses configurable rules to determine the current network state and LED color.

Designed for headless routers and wireless repeaters where a single RGB LED provides useful feedback about connection status.

## Features

- Modular network connectivity checks
- Configurable check intervals and thresholds
- Priority-based state resolution
- RGB LED indication using Linux sysfs
- Static LED colors without animations
- UCI configuration
- Integration with OpenWrt `procd`
- Automatic service startup and restart
- Extensible architecture for additional checks and output devices
- Lightweight implementation using POSIX shell and BusyBox `ash`

## Supported Hardware

Initially developed and tested on:

| Component | Environment |
|---|---|
| Device | Google WiFi (Gale) |
| Operating system | OpenWrt 25.12.2 |
| Platform | Qualcomm IPQ40xx |
| RGB controller | LP5523 |
| LED interface | `/sys/class/leds/` |
| Shell | BusyBox `ash` |

Other OpenWrt devices may work if they expose compatible LED brightness interfaces.

Hardware compatibility beyond Google WiFi Gale has not yet been verified.

## Architecture

The application consists of four main components:

```text
                 ┌───────────────────────┐
                 │       Runner          │
                 │  Scheduling & State   │
                 └───────────┬───────────┘
                             │
               ┌─────────────▼─────────────┐
               │          Checks           │
               ├───────────────────────────┤
               │ Travelmate                │
               │ Wi-Fi Association         │
               │ DHCP / IPv4               │
               │ Internet Connectivity     │
               └─────────────┬─────────────┘
                             │
                 ┌───────────▼───────────┐
                 │       Resolver        │
                 │  Rules & Priorities   │
                 └───────────┬───────────┘
                             │
                 ┌───────────▼───────────┐
                 │       RGB Output      │
                 │    Linux LED sysfs    │
                 └───────────────────────┘
```

### Runner

The Runner executes enabled checks according to their configured intervals.

It manages:

- Check execution
- Success and failure thresholds
- Runtime state persistence
- Scheduling using monotonic uptime
- State information for the Resolver

Runtime state is stored under:

```text
/tmp/network-led/checks/
```

### Checks

Each check is implemented as an independent shell module.

Check results use the following exit codes:

| Exit code | State | Description |
|---|---|---|
| `0` | `ok` | Check succeeded |
| `1` | `fail` | Check failed |
| `2` | `pending` | Check is waiting for completion |
| `3` | `unknown` | State cannot be determined |

#### Travelmate

Monitors the connection status reported by the Travelmate service.

#### Wi-Fi

Checks whether a wireless station is associated with an access point using `iw`.

#### DHCP

Verifies the WWAN interface state and IPv4 configuration through OpenWrt network services.

#### Internet

Checks external connectivity using ICMP requests.

The check supports multiple targets, configurable intervals, and success/failure thresholds.

### Resolver

The Resolver determines the effective network state using configurable rules.

Rules are evaluated according to priority and may combine multiple check conditions.

The resulting state determines the LED color.

### RGB Output

The RGB output controls individual red, green, and blue LED channels through Linux sysfs.

Supported colors:

| Color | Typical meaning |
|---|---|
| White | Initializing |
| Orange | Searching for Wi-Fi |
| Blue | Establishing connection |
| Purple | Connected without internet |
| Green | Online |
| Red | Error |
| Off | LED disabled |

Colors are configurable through state-resolution rules.

The current implementation uses static colors only. Blinking, pulsing, and other animations are intentionally not supported.

## Project Structure

```text
openwrt-network-led/
├── README.md
├── install.sh
├── config/
│   └── network-led
├── init.d/
│   └── network-led
├── sbin/
│   └── network-led
└── lib/
    ├── checks/
    │   ├── dhcp.sh
    │   ├── internet.sh
    │   ├── travelmate.sh
    │   └── wifi.sh
    ├── core/
    │   ├── check.sh
    │   ├── resolver.sh
    │   └── runner.sh
    └── outputs/
        └── rgb.sh
```

## Requirements

- OpenWrt with `procd`
- POSIX-compatible shell (BusyBox `ash`)
- UCI configuration utilities
- `ubus`
- `iw`
- `ping`
- `logger`
- `timeout`
- Compatible Linux sysfs LED interface

Travelmate is required only when using the Travelmate check.

On OpenWrt 25.12.x, install the timeout utility if it is missing:

```sh
apk add coreutils-timeout
```

On older OpenWrt versions using `opkg`, package names and availability may differ.

## Installation

Clone the repository onto your OpenWrt device:

```sh
git clone https://github.com/p0is0n/openwrt-network-led.git
cd openwrt-network-led
```

Run the installer:

```sh
sh install.sh
```

The installer:

1. Checks the runtime environment and required commands.
2. Validates the source files.
3. Stops the existing service if present.
4. Installs the executable, modules, and init script.
5. Preserves an existing UCI configuration.
6. Enables and starts the service.

**Note:** Git must be available on the device to use the clone command. Alternatively, download the repository on another computer and copy it to the router.

### Installed Paths

| Path | Purpose |
|---|---|
| `/etc/config/network-led` | UCI configuration |
| `/etc/init.d/network-led` | OpenWrt service |
| `/usr/sbin/network-led` | Main executable |
| `/usr/lib/network-led/core/` | Core modules |
| `/usr/lib/network-led/checks/` | Network checks |
| `/usr/lib/network-led/outputs/` | LED output drivers |

## Configuration

Configuration is stored in:

```text
/etc/config/network-led
```

The project uses OpenWrt UCI syntax.

The following examples illustrate the configuration structure. Use the repository configuration as the reference for supported fields and rules.

### General Settings

```text
config settings 'main'
    option enabled '1'
    option tick_interval '1'
    option log_level 'info'
```

### RGB Channels

```text
config led 'rgb'
    option red 'LED0_Red'
    option green 'LED0_Green'
    option blue 'LED0_Blue'
    option brightness '90'
```

LED channel names depend on the device.

Available channels can be inspected with:

```sh
ls /sys/class/leds/
```

### Connectivity Checks

Check intervals and thresholds are configured through UCI.

The default configuration uses approximately:

| Check | Interval |
|---|---|
| Travelmate | 3 seconds |
| Wi-Fi | 3 seconds |
| DHCP | 3 seconds |
| Internet | 15 seconds |

The Internet check supports configurable ICMP targets and thresholds to reduce unnecessary state changes during temporary packet loss.

### Rules

Rules combine check states to determine the effective network state and corresponding LED color.

Typical mappings include:

```text
Initializing  -> White
Searching     -> Orange
Connecting    -> Blue
Offline       -> Purple
Online        -> Green
Error         -> Red
```

Rule definitions and priorities are maintained in the UCI configuration.

## Usage

### Service Management

Start:

```sh
/etc/init.d/network-led start
```

Stop:

```sh
/etc/init.d/network-led stop
```

Restart:

```sh
/etc/init.d/network-led restart
```

Enable automatic startup:

```sh
/etc/init.d/network-led enable
```

Check service status:

```sh
/etc/init.d/network-led status
```

### Command-Line Interface

Display current state:

```sh
network-led status
```

Execute an individual check:

```sh
network-led check internet
```

Run the main process manually:

```sh
network-led run
```

Normally, the process should be managed by `procd`.

### Logs

View recent messages:

```sh
logread -e network-led
```

The application logs lifecycle events, LED color changes, and operational errors.

## Extending the Project

The modular design allows additional checks without modifying the RGB output implementation.

Potential extensions include:

- WireGuard tunnel status
- VPN connectivity
- DNS availability
- Gateway reachability
- Ethernet link status
- Custom service health checks

New checks should follow the existing shell-module conventions and return the standard check exit codes.

After registering the check in the Runner and configuring the corresponding rules, the Resolver can incorporate its result into the overall network state.

Additional LED output implementations may also be introduced through the output abstraction.

## Contributing

Contributions, bug reports, and suggestions are welcome.

When reporting an issue, please include the OpenWrt version, device model, relevant configuration (with sensitive information removed), and `network-led` logs.

## License

A license has not yet been added to the repository. MIT is the proposed license; add a `LICENSE` file before declaring the project MIT-licensed.
