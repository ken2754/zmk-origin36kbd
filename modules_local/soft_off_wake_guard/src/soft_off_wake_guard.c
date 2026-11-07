/*
 * Soft off wake guard
 *
 * nRF52 wakes from System OFF (ZMK soft off) as soon as the wake pin becomes
 * active, which resets and boots the MCU. This runs early during boot, before
 * ZMK's kscan / BLE are initialized, and requires the wake key to be held for
 * CONFIG_SOFT_OFF_WAKE_GUARD_HOLD_MS. If it is released earlier, the MCU is
 * put straight back into System OFF with the same pin armed as wake source.
 *
 * SPDX-License-Identifier: MIT
 */

#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/init.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/sys/poweroff.h>

#include <hal/nrf_power.h>

LOG_MODULE_REGISTER(soft_off_wake_guard, CONFIG_LOG_DEFAULT_LEVEL);

#define WAKE_KEY_NODE DT_NODELABEL(soft_off_wake_key)

static const struct gpio_dt_spec wake_key = GPIO_DT_SPEC_GET(WAKE_KEY_NODE, gpios);

/* Sample every 5 ms; 4 consecutive "released" samples (20 ms) = released. */
#define POLL_US 5000U
#define RELEASE_DEBOUNCE_SAMPLES 4U

/*
 * Magic value stored in NRF_POWER->GPREGRET2 (register index 1) right before
 * entering soft off via zmk_pm_soft_off(). This distinguishes an explicit
 * soft off from an inactivity deep sleep (which also uses sys_poweroff()).
 */
#define SOFT_OFF_GPREGRET_REG   1U
#define SOFT_OFF_GPREGRET_MAGIC 0x93U

extern int __real_zmk_pm_soft_off(void);

int __wrap_zmk_pm_soft_off(void) {
    nrf_power_gpregret_set(NRF_POWER, SOFT_OFF_GPREGRET_REG, SOFT_OFF_GPREGRET_MAGIC);
    int ret = __real_zmk_pm_soft_off();
    /* Only reached if soft off failed and returned instead of powering off. */
    nrf_power_gpregret_set(NRF_POWER, SOFT_OFF_GPREGRET_REG, 0);
    return ret;
}

static bool wake_key_pressed(void) { return gpio_pin_get_dt(&wake_key) > 0; }

/*
 * Returns true if the key stays pressed for `ms` milliseconds,
 * false as soon as a (debounced) release is detected.
 */
static bool wake_key_held_for(uint32_t ms) {
    uint32_t released = 0;

    for (uint32_t elapsed_us = 0; elapsed_us < ms * 1000U; elapsed_us += POLL_US) {
        released = wake_key_pressed() ? 0 : released + 1;
        if (released >= RELEASE_DEBOUNCE_SAMPLES) {
            return false;
        }
        k_busy_wait(POLL_US);
    }

    return true;
}

static void return_to_soft_off(void) {
    /* Wait until the key is stably released so we don't wake up immediately again. */
    while (wake_key_held_for(50)) {
    }

    /* On nRF, a level interrupt is implemented with GPIO SENSE -> wakes from System OFF. */
    int ret = gpio_pin_interrupt_configure_dt(&wake_key, GPIO_INT_LEVEL_ACTIVE);
    if (ret < 0) {
        LOG_ERR("Failed to arm wake key (%d), continuing boot", ret);
        return;
    }

    /* Preserve the soft-off marker for the next wakeup attempt. */
    nrf_power_gpregret_set(NRF_POWER, SOFT_OFF_GPREGRET_REG, SOFT_OFF_GPREGRET_MAGIC);
    sys_poweroff();
}

static int soft_off_wake_guard_init(void) {
    uint32_t reas = nrf_power_resetreas_get(NRF_POWER);
    uint32_t gpregret = nrf_power_gpregret_get(NRF_POWER, SOFT_OFF_GPREGRET_REG);

    /*
     * Clear both immediately so later normal resets or wakes from inactivity
     * deep sleep are not mistaken for soft-off wakes.
     */
    nrf_power_resetreas_clear(NRF_POWER, NRF_POWER_RESETREAS_OFF_MASK);
    nrf_power_gpregret_set(NRF_POWER, SOFT_OFF_GPREGRET_REG, 0);

    bool woke_from_soft_off = (gpregret == SOFT_OFF_GPREGRET_MAGIC) &&
                              (((reas & NRF_POWER_RESETREAS_OFF_MASK) != 0) || (reas == 0));
    if (!woke_from_soft_off) {
        return 0;
    }

    if (!gpio_is_ready_dt(&wake_key) || gpio_pin_configure_dt(&wake_key, GPIO_INPUT) < 0) {
        /* Fail safe: boot normally. */
        return 0;
    }
    k_busy_wait(100); /* let the pull-up settle */

    if (!wake_key_held_for(CONFIG_SOFT_OFF_WAKE_GUARD_HOLD_MS)) {
        return_to_soft_off();
        /* Only reached if arming the wake key failed. */
    } else {
        /* Wake confirmed: wait for release so the held key isn't typed after boot. */
        for (uint32_t elapsed_us = 0;
             elapsed_us < CONFIG_SOFT_OFF_WAKE_GUARD_RELEASE_WAIT_MS * 1000U && wake_key_pressed();
             elapsed_us += POLL_US) {
            k_busy_wait(POLL_US);
        }
    }

    /* Hand the pin back; kscan0 configures it during its own init. */
    gpio_pin_configure_dt(&wake_key, GPIO_DISCONNECTED);
    return 0;
}

/* After GPIO drivers (PRE_KERNEL_1), before ZMK kscan / BLE initialization. */
SYS_INIT(soft_off_wake_guard_init, POST_KERNEL, 0);
