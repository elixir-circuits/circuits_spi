#ifndef SPI_NIF_H
#define SPI_NIF_H


#include "erl_nif.h"

#include <err.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <linux/spi/spidev.h>

#ifndef _IOC_SIZE_BITS
// Include <asm/ioctl.h> manually on platforms that don't include it
// from <sys/ioctl.h>.
#include <asm/ioctl.h>
#endif

//#define DEBUG

#ifdef DEBUG
#define log_location stderr
//#define LOG_PATH "/tmp/elixir_circuits_spi.log"
#define debug(...) do { enif_fprintf(log_location, __VA_ARGS__); enif_fprintf(log_location, "\r\n"); fflush(log_location); } while(0)
#define error(...) do { debug(__VA_ARGS__); } while (0)
#define start_timing() ErlNifTime __start = enif_monotonic_time(ERL_NIF_USEC)
#define elapsed_microseconds() (enif_monotonic_time(ERL_NIF_USEC) - __start)
#else
#define debug(...)
#define error(...) do { enif_fprintf(stderr, __VA_ARGS__); enif_fprintf(stderr, "\n"); } while(0)
#define start_timing()
#define elapsed_microseconds() 0
#endif

// Max SPI transfer size that we support
#define SPI_TRANSFER_MAX 4096


// SPI NIF Resource.
struct SpiNifRes {
    int fd;
    struct spi_ioc_transfer transfer;
};


// SPI NIF Private data
struct SpiNifPriv {
    ErlNifResourceType *spi_nif_res_type;
    ERL_NIF_TERM atom_ok;
    ERL_NIF_TERM atom_error;
};

#endif // SPI_NIF_H