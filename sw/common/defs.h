#pragma once

#define CPU_TIMER_HZ (30'000'000)
#define BAUD_RATE    (   115'200)

#define RGBLED_CTRL_ADDRESS (0x8000'9000)
#define RGBLED_CTRL_BOUNDS  (0x0000'0010)

#define GPIO_ADDRESS (0x8000'0000)
#define GPIO_BOUNDS  (0x0000'0020)

#define UART_ADDRESS (0x8010'0000)
#define UART_BOUNDS  (0x0000'0034)

#define SPI_ADDRESS  (0x8030'0000)
#define SPI_BOUNDS   (0x0000'0024)

#define HYPERRAM_ADDRESS (0x4000'0000)
#define HYPERRAM_BOUNDS  (0x0400'0000)

#define FLASH_CSN_GPIO_BIT 12
