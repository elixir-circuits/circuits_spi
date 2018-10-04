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

#include <err.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <bits/stdint-uintn.h>

#include "erl_nif.h"

#ifndef _IOC_SIZE_BITS
// Include <asm/ioctl.h> manually on platforms that don't include it
// from <sys/ioctl.h>.
#include <asm/ioctl.h>
#endif
#include <linux/spi/spidev.h>


//#define DEBUG
#ifdef DEBUG
#define debug(...) do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\r\n"); } while(0)
#else
#define debug(...)
#endif

// Max SPI transfer size that we support
#define SPI_TRANSFER_MAX 4096

// struct to hold SPI channel information
// in a linked list
typedef struct {
    int fd;
    struct spi_ioc_transfer transfer;
    void *next;
} SpiInfo;

// Head of list of SPI channel information
SpiInfo *spi_info_head = NULL;

// Delete SPI channel information corresponding to the given file descriptor
static void del_spi_info(int fd)
{
    SpiInfo *prev_entry = NULL;
    SpiInfo *curr_entry = spi_info_head;

    while(curr_entry != NULL){
        if (curr_entry->fd == fd){
            if (prev_entry == NULL)
                spi_info_head = curr_entry->next;
            else
                prev_entry->next = curr_entry->next;

            free(curr_entry);
            return;
        }
        prev_entry = curr_entry;
        curr_entry = curr_entry->next;
    }
}

// Add to the list of SPI channel information
static void add_spi_info(SpiInfo *new_info)
{
    // if an existing entry has the same file descriptor
    // delete it
    del_spi_info(new_info->fd);

    // add the new info to the head of the list
    new_info->next = spi_info_head;
    spi_info_head = new_info;
}

// Get the SPI channel information corresponding to the given file descriptor
static SpiInfo* get_spi_info(int fd)
{
    SpiInfo *curr_entry = spi_info_head;

    while(curr_entry != NULL){
        if (curr_entry->fd == fd)
            return curr_entry;

        curr_entry = curr_entry->next;
    }
    return NULL;  // matching entry not found
}


/**
 * @brief        Initialize a SPI device
 *
 * @param        devpath Path to SPI device file
 * @param        mode    SPI mode
 * @param        bits_per_word    Number of bits
 * @param        speed_hz   Bus speed
 * @param        delay_usecs   Delay between transfers
 *
 * @return       1 if success, -1 if fails
 */
static int spi_init( const char *devpath,
                     uint8_t mode,
                     uint8_t bits_per_word,
                     uint32_t speed_hz,
                     uint16_t delay_usecs,
                     char *error_str)
{
    SpiInfo *spi;

    int fd = open(devpath, O_RDWR);
    if (fd < 0){
        sprintf(error_str, "opening_%s", devpath);
        return -1;
    }

    if (ioctl(fd, SPI_IOC_WR_MODE, &mode) < 0){
        sprintf(error_str, "ioctl(SPI_IOC_WR_MODE_%d)", mode);
        return -1;
    }

    // Set these to check for bad values given by the user. They get
    // set again on each transfer.
    if (ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits_per_word) < 0){
        sprintf(error_str, "ioctl(SPI_IOC_WR_BITS_PER_WORD_%d)", bits_per_word);
        return -1;
    }

    if (ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed_hz) < 0){
        sprintf(error_str, "ioctl(SPI_IOC_WR_MAX_SPEED_HZ_%d)", speed_hz);
        return -1;
    }
    
    // Successfully opened SPI channel, allocate memory to hold channel details
    // Add to list of SPI channels
    spi = (SpiInfo*) malloc(sizeof(SpiInfo));
    memset(spi, 0, sizeof(SpiInfo));

    spi->fd = fd;
    spi->transfer.bits_per_word = bits_per_word;
    spi->transfer.speed_hz = speed_hz;
    spi->transfer.delay_usecs = delay_usecs;

    add_spi_info(spi);

    error_str = "";
    return fd;
}


static ERL_NIF_TERM open_spi(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    char device[32];
    char devpath[64] = "/dev/";
    uint8_t mode;
    uint8_t bits_per_word;
    uint32_t speed_hz;
    uint16_t delay_us;
    char error_str[128];

    if (!enif_get_string(env, argv[0], (char*)&device, sizeof(device), ERL_NIF_LATIN1))
        return enif_make_badarg(env);
    strncat(devpath, device, sizeof(device));

    if (!enif_get_uint(env, argv[1], (unsigned int*) &mode))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[2], (unsigned int*) &bits_per_word))
        return enif_make_badarg(env);
    
    if (!enif_get_ulong(env, argv[3], (unsigned long*) &speed_hz))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[4], (unsigned int*) &delay_us))
        return enif_make_badarg(env);

    int fd = spi_init(devpath, mode, bits_per_word, speed_hz, delay_us, error_str);

    if (fd < 0)
        return enif_make_tuple2(env, enif_make_atom(env, "error"), 
                                     enif_make_atom(env, error_str));

    return enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_int(env, fd));
}


static ERL_NIF_TERM transfer_spi(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int fd;
    SpiInfo *spi;
    ErlNifBinary bin_write;
    ErlNifBinary bin_read;
    char read_data[SPI_TRANSFER_MAX];

    if (!enif_get_int(env, argv[0], &fd))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[1], &bin_write))
       return enif_make_badarg(env);

    spi = get_spi_info(fd);
    if (!spi)
        return enif_make_tuple2(env, enif_make_atom(env, "error"), 
                                     enif_make_atom(env, "invalid_file_descriptor"));

    struct spi_ioc_transfer tfer = spi->transfer;

    // The Linux header spidev.h expects pointers to be in 64-bit integers (__u64),
    // but pointers on Raspberry Pi are only 32 bits.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpointer-to-int-cast"
    tfer.tx_buf = (__u64) bin_write.data;
    tfer.rx_buf = (__u64) read_data;
#pragma GCC diagnostic pop
    tfer.len = bin_write.size;

    if (ioctl(fd, SPI_IOC_MESSAGE(1), &tfer) < 1)
        return enif_make_tuple2(env, enif_make_atom(env, "error"), 
                                     enif_make_atom(env, "transfer_failed"));

    bin_read.data = read_data;
    bin_read.size = bin_write.size;
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_binary(env, &bin_read));
}

static ERL_NIF_TERM close_spi(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int fd;
    if (!enif_get_int(env, argv[0], &fd))
        return enif_make_badarg(env);

    del_spi_info(fd);

    return enif_make_atom(env, "ok");
}

static ErlNifFunc nif_funcs[] =
{
    {"open", 5, open_spi, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"transfer", 2, transfer_spi, 0},
    {"close", 1, close_spi, 0}
};

ERL_NIF_INIT(Elixir.ElixirCircuits.SPI.Nif, nif_funcs, NULL, NULL, NULL, NULL);
