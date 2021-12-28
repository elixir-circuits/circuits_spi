/*
 *  Copyright 2018 Frank Hunleth, Mark Sebald
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPI NIF implementation.
 */

#include "spi_nif.h"
#include <linux/spi/spidev.h>
#include <sys/types.h>
#include <inttypes.h>

#ifndef _IOC_SIZE_BITS
// Include <asm/ioctl.h> manually on platforms that don't include it
// from <sys/ioctl.h>.
#include <asm/ioctl.h>
#endif

ERL_NIF_TERM hal_info(ErlNifEnv *env)
{
    ERL_NIF_TERM info = enif_make_new_map(env);
    enif_make_map_put(env, info, enif_make_atom(env, "name"), enif_make_atom(env, "spidev"), &info);
    return info;
}

ERL_NIF_TERM hal_max_transfer_size(ErlNifEnv *env)
{
    uint64_t bufsiz = 0;

    // Linux put this information (if available) in /sys/module/spidev/parameters/bufsiz
    FILE *file = fopen("/sys/module/spidev/parameters/bufsiz","r");
    if (file != NULL) {
        if (fscanf(file, "%"PRIu64, &bufsiz) != 1) {
            bufsiz = 0;
        }
        fclose(file);
    }

    if (bufsiz == 0) {
        // if /sys/module/spidev/parameters/bufsiz is not available
        // then we return 4096, a safe minimum size
        bufsiz = 4096;
    }

    return enif_make_uint64(env, bufsiz);
}

int hal_spi_open(const char *device,
                 const struct SpiConfig *config,
                 char *error_str)
{
    char devpath[64] = "/dev/";

    strcat(devpath, device);
    int fd = open(devpath, O_RDWR);
    if (fd < 0) {
        strcpy(error_str, "access_denied");
        return -1;
    }

    // Set these to check for bad values given by the user. They get
    // set again on each transfer.
    uint8_t mode = (uint8_t) config->mode;
    if (ioctl(fd, SPI_IOC_WR_MODE, &mode) < 0) {
        strcpy(error_str, "invalid_mode");
        return -1;
    }

    uint8_t bits_per_word = (uint8_t) config->bits_per_word;
    if (ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits_per_word) < 0) {
        strcpy(error_str, "invalid_bits_per_word");
        return -1;
    }

    uint32_t speed_hz = config->speed_hz;
    if (ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed_hz) < 0) {
        strcpy(error_str, "invalid_speed");
        return -1;
    }

    return fd;
}


void hal_spi_close(int fd)
{
    close(fd);
}

int hal_spi_transfer(int fd,
                     const struct SpiConfig *config,
                     const uint8_t *to_write,
                     uint8_t *to_read,
                     size_t len)
{
    struct spi_ioc_transfer tfer;

    memset(&tfer, 0, sizeof(tfer));
    tfer.speed_hz = config->speed_hz;
    tfer.delay_usecs = (uint16_t ) config->delay_us;
    tfer.bits_per_word = (uint8_t) config->bits_per_word;

    // The Linux header spidev.h expects pointers to be in 64-bit integers (__u64),
    // but pointers on Raspberry Pi are only 32 bits.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpointer-to-int-cast"
    tfer.tx_buf = (__u64) to_write;
    tfer.rx_buf = (__u64) to_read;
#pragma GCC diagnostic pop
    tfer.len = (uint32_t) len;

    return ioctl(fd, SPI_IOC_MESSAGE(1), &tfer);
}
