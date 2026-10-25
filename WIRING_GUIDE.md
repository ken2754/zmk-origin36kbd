# Origin36 Hand-Wiring & Pinout Guide

A complete guide for hand-wiring the Origin36, an 18-key per half (36-key total) split mechanical keyboard with direct GPIO matrix pinout, using the SuperMini nRF52840 (TENSTAR, a.k.a. the "red board" with outer GPIO silkscreen, 13 pins × 2 rows).

> [!NOTE]
> The controller used in this build is the SuperMini nRF52840 produced by TENSTAR (commonly known as the **"red board"**). It features silkscreen markings matching Nordic GPIO numbers directly on its outer 13×2 pins, and is widely, easily, and affordably available on AliExpress.

---

## 1. Specifications

- **Key Count**: 36 keys total (Split: 18 keys per side = 3 rows × 5 columns + 3 thumb keys)
- **Wiring Method**: Direct GPIO wiring (`zmk,kscan-gpio-direct`)
  - **No diodes required**: Connect one switch terminal directly to an MCU GPIO pin, and the other to common GND.
  - Uses internal pull-up resistors (`GPIO_ACTIVE_LOW | GPIO_PULL_UP`).
- **MCU**: SuperMini nRF52840 (Red PCB / 13-pin × 2-row outer pinout model by TENSTAR).
- **MCU Orientation**: Both left and right halves are mounted **component side (chips & silkscreen) facing UP**, with the **USB-C port pointing AWAY from you (top)**.

---

## 2. MCU Pinout Diagram (Top View / Component Side Facing Up)

```text
                      [ USB-C Port ]
                +--------------------------+
  (Battery -)   | [B-]                [B+] | (Battery + / via Power Switch)
  (P0.06 / D 1) | 006                  RAW | (USB 5V charging input line)
  (P0.08 / D 0) | 008                  GND | (GND)
          (GND) | GND                  RST | (Reset switch)
          (GND) | GND                  VCC | (3.3V Output)
  (P0.17 / D 2) | 017                  031 | (P0.31 / D21)
  (P0.20 / D 3) | 020                  029 | (P0.29 / D20)
  (P0.22 / D 4) | 022                  002 | (P0.02 / D19)
  (P0.24 / D 5) | 024                  115 | (P1.15 / D18)
  (P1.00 / D 6) | 100                  113 | (P1.13 / D15)
  (P0.11 / D 7) | 011                  111 | (P1.11 / D14)
  (P1.04 / D 8) | 104                  010 | (P0.10 / D16)
  (P1.06 / D 9) | 106                  009 | (P0.09 / D10)
                +--------------------------+
```

- **Exactly 18 GPIO pins exist on the outer through-hole rows** (10 pins on the left column + 8 pins on the right column).
- **No need to solder tricky SMD test pads or inner pads** on the back of the board.
- Battery connection terminals (`B-`, `B+`) are broken out as standard outer through-hole pins at the very top, ensuring clean and straightforward hand-soldering.

---

## 3. Pin Assignment Table (Symmetrical Design)

To eliminate wiring mistakes, **both the left and right halves use identical silkscreen pins corresponding to the same finger positions**.
Simply solder wires matching the 3-digit GPIO number printed on the board silkscreen.

### Left Half & Right Half

| Key Position (Finger) | Left Key | Right Key | Silkscreen Pin | ZMK Devicetree Node | Pro Micro Alias |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Top Pinky** | **Q** | **P** | **006** | `&gpio0 6` | `&pro_micro 1` (TX) |
| **Top Ring** | **W** | **O** | **008** | `&gpio0 8` | `&pro_micro 0` (RX) |
| **Top Middle** | **E** | **I** | **017** | `&gpio0 17` | `&pro_micro 2` |
| **Top Index** | **R** | **U** | **020** | `&gpio0 20` | `&pro_micro 3` |
| **Top Inner Index** | **T** | **Y** | **022** | `&gpio0 22` | `&pro_micro 4` |
| **Home Pinky** | **A** | **;** | **024** | `&gpio0 24` | `&pro_micro 5` |
| **Home Ring** | **S** | **L** | **100** | `&gpio1 0` | `&pro_micro 6` |
| **Home Middle** | **D** | **K** | **011** | `&gpio0 11` | `&pro_micro 7` |
| **Home Index** | **F** | **J** | **104** | `&gpio1 4` | `&pro_micro 8` |
| **Home Inner Index** | **G** | **H** | **106** | `&gpio1 6` | `&pro_micro 9` |
| **Bottom Pinky** | **Z** | **/** | **031** | `&gpio0 31` | `&pro_micro 21` |
| **Bottom Ring** | **X** | **.** | **029** | `&gpio0 29` | `&pro_micro 20` |
| **Bottom Middle** | **C** | **,** | **002** | `&gpio0 2` | `&pro_micro 19` |
| **Bottom Index** | **V** | **M** | **115** | `&gpio1 15` | `&pro_micro 18` |
| **Bottom Inner Index** | **B** | **N** | **113** | `&gpio1 13` | `&pro_micro 15` |
| **Thumb Outer** | **Thumb 0** | **Thumb 2** | **009** | `&gpio0 9` | `&pro_micro 10` |
| **Thumb Mid** | **Thumb 1** | **Thumb 1** | **010** | `&gpio0 10` | `&pro_micro 16` |
| **Thumb Inner** | **Thumb 2** | **Thumb 0** | **111** | `&gpio1 11` | `&pro_micro 14` |

- **Thumb Key Physical Ordering**:
  - Left Hand Thumbs (left to right): `[Outer: Pin 009]` → `[Mid: Pin 010]` → `[Inner: Pin 111]`
  - Right Hand Thumbs (left to right): `[Inner: Pin 111]` → `[Mid: Pin 010]` → `[Outer: Pin 009]`

---

## 4. Hand-Wiring Steps

1. **Common GND Line (Ground Rail)**:
   - Daisy-chain **one of the two pins** of each switch across all 18 keys using bus wire or hookup wire.
   - Solder this shared line to one of the MCU **GND** pins (pin 3 on the right row, or pin 4 / 5 on the left row).
2. **Individual GPIO Lines**:
   - Solder a wire from the **remaining pin** of each switch to the corresponding MCU through-hole pin listed in the table above.
   - Diodes are **not** needed (direct connection).
3. **Reset Switch (Tactile Pushbutton)**:
   - Connect a momentary pushbutton between the MCU **RST** pin and a **GND** pin.
   - **Double-tapping** this switch resets the MCU into the UF2 bootloader mode, mounting as a USB storage drive (`NICENANO`, etc.) for flashing firmware.
4. **Power Slide Switch & LiPo Battery**:
   - Use a standard 3.7V Lithium-ion polymer (LiPo) battery.
   - Connect to the **B-** and **B+** through-hole pins located at the top outer perimeter of the board (next to the USB-C jack).
   - **B-**: Solder the battery's negative terminal (black wire) directly to `B-`.
   - **B+**: Solder the battery's positive terminal (red wire) to `B+` in series with a miniature slide switch (acts as the hardware power switch).
     - Wiring path: `[Battery Red Wire (+)]` → `[Slide Switch Pin 1]` / `[Slide Switch Pin 2]` → `[MCU B+ Pin]`.
   - > [!TIP]
     > Check with a multimeter that `B-` and MCU `GND` are electrically continuous (0 Ω) before turning on power for the first time.
