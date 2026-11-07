# SPDX-License-Identifier: MIT

if(CONFIG_SOFT_OFF_WAKE_GUARD)
  zephyr_library()
  zephyr_library_sources(src/soft_off_wake_guard.c)
  zephyr_ld_options(-Wl,--wrap=zmk_pm_soft_off)
endif()
