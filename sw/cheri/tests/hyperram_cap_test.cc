#define CHERIOT_NO_AMBIENT_MALLOC
#define CHERIOT_NO_NEW_DELETE
#define CHERIOT_PLATFORM_CUSTOM_UART

#include "../../common/defs.h"

#include <cheri.hh>
#include <stdint.h>

using namespace CHERI;

/**
 * C++ entry point for the loader.  This is called from assembly, with the
 * read-write root in the first argument.
 */
[[noreturn]] extern "C" void rom_loader_entry(void *rwRoot)
{
  Capability<void> hyperram_raw{rwRoot};
	hyperram_raw.address() = HYPERRAM_ADDRESS;
	hyperram_raw.bounds()  = HYPERRAM_BOUNDS;

	Capability<volatile uint32_t> hyperram_area = hyperram_raw.cast<volatile uint32_t>();

	Capability<Capability<volatile uint32_t>> hyperram_cap_area = hyperram_raw.cast<Capability<volatile uint32_t>>();
  hyperram_cap_area[0] = hyperram_area;

  asm volatile("": : :"memory");

  Capability<volatile uint32_t> hyperram_area2 = hyperram_cap_area[0];
  hyperram_area2[0] = 0xDEADBEEF;

  asm volatile("": : :"memory");
  hyperram_area2 = hyperram_cap_area[0];
  hyperram_area2[0] = 0xDEADBEEF;
}
