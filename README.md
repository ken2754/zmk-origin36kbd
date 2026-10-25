# Origin36 - ZMK Firmware

Firmware repository for the **Origin36**, a 36-key hand-wired split mechanical keyboard (direct GPIO matrix) powered by the SuperMini nRF52840 (TENSTAR, a.k.a. the "red board").

> [!NOTE]
> The MCU board used in this project is the **SuperMini nRF52840 by TENSTAR** (a.k.a. the **"red board"** / 13-pin × 2-row version with GPIO silkscreen). It is easily and inexpensively available on AliExpress, making it an ideal choice for budget-friendly wireless split keyboard builds.

---

## Features

- **18 keys per side × 2 = 36 keys total** (3×5+3 ergonomic split layout, similar to Corne 36 / Minidox)
- **Direct GPIO Wiring**: No switching diodes required. Fully wired using only 18 outer through-hole pins
- **Symmetrical Pinout**: Identical wiring rules and pin labels for both left and right halves, minimizing assembly mistakes
- **True BLE Wireless Split**: Left side operates as Central (host connection), right side operates as Peripheral with automatic pairing
- **Power Optimization**: Low-power deep sleep (after 15 minutes of inactivity) and battery level reporting

---

## Repository Structure

```text
zmk-origin36/
├── .github/workflows/
│   └── build.yml               # GitHub Actions CI workflow
├── config/
│   ├── boards/shields/origin36/
│   │   ├── Kconfig.shield      # Shield enable definition
│   │   ├── Kconfig.defconfig   # Default configs (Left half as Central)
│   │   ├── origin36.zmk.yml    # ZMK shield metadata
│   │   ├── origin36.dtsi       # Shared direct GPIO matrix & transform
│   │   ├── origin36_left.overlay   # Left half overlay
│   │   ├── origin36_right.overlay  # Right half overlay (col-offset 18)
│   │   └── origin36.keymap     # 36-key keymap definition
│   └── origin36.conf           # BLE transmit power and sleep settings
├── build.yaml                  # Targets for GitHub Actions build
├── setup.sh                    # Local build environment setup script (Docker)
├── build.sh                    # Local firmware build script (Docker)
├── WIRING_GUIDE.md             # Detailed hand-wiring & pinout guide
└── README.md
```

---

## Pinout Summary

For detailed wiring diagrams and step-by-step assembly instructions, refer to [WIRING_GUIDE.md](file:///home/ken/git/zmk-origin36/WIRING_GUIDE.md).

- **Switch Common Terminal**: Daisy-chain one pin of each switch to the MCU **GND** pin.
- **Switch Individual Terminal**: Connect the other pin directly to the corresponding MCU silkscreen pin.

| Position / Finger | Left Key | Right Key | Silkscreen Pin |
|:---|:---:|:---:|:---:|
| Top Row (Outer → Inner) | Q, W, E, R, T | P, O, I, U, Y | **006, 008, 017, 020, 022** |
| Home Row (Outer → Inner) | A, S, D, F, G | ;, L, K, J, H | **024, 100, 011, 104, 106** |
| Bottom Row (Outer → Inner) | Z, X, C, V, B | /, ., ,, M, N | **031, 029, 002, 115, 113** |
| Thumbs (Outer → Mid → Inner) | Thumb 0, 1, 2 | Thumb 2, 1, 0 | **009, 010, 111** |

---

## Building Firmware

### 1. Building Locally with Docker

You can build the firmware locally using Docker without polluting your host environment:

#### Prerequisites
- Docker installed and the daemon running.

#### Initial Setup
Run the setup script to initialize ZMK (`v0.3.0` / Zephyr 3.5) dependencies in the workspace:

```bash
./setup.sh
```
*Note: West workspaces (`.west/`, `zmk/`, `zephyr/`, etc.) will be downloaded inside this directory and are ignored by `.gitignore`.*

#### Build Commands
Use `./build.sh` to compile firmware images:

```bash
# Build both left, right, and settings reset firmwares (default)
./build.sh

# Build a specific target
./build.sh left    # Left half (origin36_left)
./build.sh right   # Right half (origin36_right)
./build.sh reset   # Settings reset (settings_reset)

# Perform a pristine rebuild (cleans cache)
./build.sh left -p

# Clean build artifacts (build/ and firmware/)
./build.sh clean

# Display help
./build.sh -h
```

Compiled `.uf2` binaries are automatically placed in the `firmware/` directory.

---

### 2. Building with GitHub Actions

1. Fork or push this repository to your GitHub account.
2. Go to the **Actions** tab on your GitHub repository.
3. Select the **Build ZMK firmware** workflow on the left sidebar, and click **Run workflow** to manually trigger a build.
4. Once completed, download `firmware.zip` from the **Artifacts** section of the workflow run summary.
5. Extracted zip contains:
   - `origin36_left-nice_nano_v2-zmk.uf2` (Left half)
   - `origin36_right-nice_nano_v2-zmk.uf2` (Right half)
   - `settings_reset-nice_nano_v2-zmk.uf2` (Bluetooth pairing reset)

---

## Flashing Instructions

1. Connect the MCU (SuperMini nRF52840) to your computer with a USB-C data cable.
2. Quickly press the reset button twice (double-tap **RST** to **GND**) to enter the bootloader.
3. A mass storage device (e.g. named `NICENANO`) will mount on your computer.
4. Drag and drop `origin36_left-nice_nano_v2-zmk.uf2` onto the left controller.
5. Repeat for the right controller with `origin36_right-nice_nano_v2-zmk.uf2`.
6. The controller automatically reboots after flashing completes.

### Pairing Reset Procedure
If the split halves fail to communicate via Bluetooth:
1. Flash `settings_reset-nice_nano_v2-zmk.uf2` to **both** controllers to erase bonding and network metadata.
2. Re-flash the corresponding firmware (`left` / `right`) to each half.
# zmk-origin36kbd
