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

int hal_spi_open(const char *device,
                 const struct SpiConfig *config,
                 char *error_str)
{
    *error_str = '\0';
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
