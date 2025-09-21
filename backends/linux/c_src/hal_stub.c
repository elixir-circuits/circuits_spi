// SPDX-FileCopyrightText: 2018 Frank Hunleth
// SPDX-FileCopyrightText: 2021 Cocoa Xu
//
// SPDX-License-Identifier: Apache-2.0

#include "spi_nif.h"
#include <string.h>
#include <sys/types.h>

ERL_NIF_TERM hal_info(ErlNifEnv *env)
{
    ERL_NIF_TERM info = enif_make_new_map(env);
    enif_make_map_put(env, info, enif_make_atom(env, "name"), enif_make_atom(env, "stub"), &info);
    return info;
}

ERL_NIF_TERM hal_max_transfer_size(ErlNifEnv *env)
{
    // Use Linux's default maximum transfer size
    return enif_make_uint64(env, 4096);
}

int hal_spi_open(const char *device_path,
                 struct SpiConfig *config,
                 char *error_str)
{
    *error_str = '\0';

    // If reversing the bits, then request that it's done in software
    config->sw_lsb_first = config->lsb_first;

    return 0;
}

void hal_spi_close(int fd)
{
}

int hal_spi_transfer(int fd,
                     const struct SpiConfig *config,
                     const uint8_t *to_write,
                     uint8_t *to_read,
                     size_t len)
{
    // Loop back.
    memcpy(to_read, to_write, len);

    return 0;
}
