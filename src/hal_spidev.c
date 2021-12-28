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

ERL_NIF_TERM hal_max_buf_size(ErlNifEnv *env)
{
    static int cached = 0;
    static ERL_NIF_TERM max_buf_size;
    uint64_t bufsiz;

    // use cached max_buf_size
    if (cached != 0) {
        return max_buf_size;
    }

    // Linux put this information (if available) in /sys/module/spidev/parameters/bufsiz
    FILE *file = fopen("/sys/module/spidev/parameters/bufsiz","r");
    if (file != NULL) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-result"
        fscanf(file, "%"PRIu64, &bufsiz);
#pragma GCC diagnostic pop
        fclose(file);
        cached = 1;
    }

    if (bufsiz == 0) {
        // if /sys/module/spidev/parameters/bufsiz is not available
        // then we return :unknown
        max_buf_size = enif_make_atom(env, "unknown");
    } else {
        max_buf_size = enif_make_uint64(env, bufsiz);
    }

    return max_buf_size;
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
                     size_t len,
                     size_t chunk_size)
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

    size_t left = len;
    size_t offset = 0;
    while (left > 0) {
        size_t length = chunk_size < left ? chunk_size : left;

        tfer.tx_buf = ((__u64) to_write + offset);
        tfer.rx_buf = ((__u64) to_read + offset);

        tfer.len = (uint32_t) length;

        int ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tfer);
        if (ret < 0) {
            return ret;
        } else {
            left -= length;
            offset += length;
        }
    }

#pragma GCC diagnostic pop

    return 0;
}
