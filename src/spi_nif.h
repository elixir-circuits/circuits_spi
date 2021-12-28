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

//#define DEBUG

#ifdef DEBUG
#define log_location stderr
//#define LOG_PATH "/tmp/circuits_spi.log"
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

struct SpiConfig {
    unsigned int mode;
    unsigned int bits_per_word;
    unsigned int speed_hz;
    unsigned int delay_us;
};

/**
 * Return information about the HAL.
 *
 * This should return a map with the name of the HAL and any info that
 * would help debug issues with it.
 */
ERL_NIF_TERM hal_info(ErlNifEnv *env);

/**
 * Return max transfer size about the HAL.
 *
 * This should return an unsigned 64-bit int value that indicates the
 * maximum transfer size in bytes
 */
ERL_NIF_TERM hal_max_transfer_size(ErlNifEnv *env);

/**
 * Open an SPI device
 *
 * @param device the name of the SPI device
 *
 * @return <0 on error or a handle on success
 */
int hal_spi_open(const char *device,
                 const struct SpiConfig *config,
                 char *error_str);

/**
 * Free resources associated with an SPI device
 */
void hal_spi_close(int fd);

/**
 * Transfer data over SPI
 *
 * @param fd the file descriptor returned from hal_spi_open
 * @param config the SPI configuration to use
 * @param to_write
 * @param to_read
 * @param len
 * @return
 */
int hal_spi_transfer(int fd,
                     const struct SpiConfig *config,
                     const uint8_t *to_write,
                     uint8_t *to_read,
                     size_t len);

#endif // SPI_NIF_H
