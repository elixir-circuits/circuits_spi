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

// SPI NIF Private data
struct SpiNifPriv {
    ErlNifResourceType *spi_nif_res_type;
    ERL_NIF_TERM atom_ok;
    ERL_NIF_TERM atom_error;
};

// SPI NIF Resource.
struct SpiNifRes {
    int fd;
    struct SpiConfig config;
};

static void spi_dtor(ErlNifEnv *env, void *obj)
{
    struct SpiNifRes *res = (struct SpiNifRes *) obj;

    debug("spi_dtor");
    if (res->fd >= 0) {
        hal_spi_close(res->fd);
        res->fd = -1;
    }
}

static int spi_load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info)
{
#ifdef DEBUG
#ifdef LOG_PATH
    log_location = fopen(LOG_PATH, "w");
#endif
#endif
    debug("spi_load");

    struct SpiNifPriv *priv = enif_alloc(sizeof(struct SpiNifPriv));
    if (!priv) {
        error("Can't allocate spi priv");
        return 1;
    }

    priv->spi_nif_res_type = enif_open_resource_type(env, NULL, "spi_nif_res_type", spi_dtor, ERL_NIF_RT_CREATE, NULL);
    if (priv->spi_nif_res_type == NULL) {
        error("open SPI NIF resource type failed");
        return 1;
    }

    priv->atom_ok = enif_make_atom(env, "ok");
    priv->atom_error = enif_make_atom(env, "error");

    *priv_data = priv;
    return 0;
}

static void spi_unload(ErlNifEnv *env, void *priv_data)
{
    debug("spi_unload");
    enif_free(priv_data);
}

static ERL_NIF_TERM spi_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct SpiNifPriv *priv = enif_priv_data(env);
    char device[16];
    char error_str[128];

    struct SpiConfig config;
    int fd;

    debug("spi_open");
    if (!enif_get_string(env, argv[0], device, sizeof(device), ERL_NIF_LATIN1))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[1], &config.mode))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[2], &config.bits_per_word))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[3], &config.speed_hz))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[4], &config.delay_us))
        return enif_make_badarg(env);

    fd = hal_spi_open(device, &config, error_str);
    if (fd < 0) {
        return enif_make_tuple2(env, priv->atom_error,
                                enif_make_atom(env, error_str));
    }

    struct SpiNifRes *spi_nif_res = enif_alloc_resource(priv->spi_nif_res_type, sizeof(struct SpiNifRes));
    spi_nif_res->fd = fd;
    spi_nif_res->config = config;
    ERL_NIF_TERM res_term = enif_make_resource(env, spi_nif_res);

    // Elixir side owns the resource. Safe for NIF side to release it.
    enif_release_resource(spi_nif_res);

    return enif_make_tuple2(env, priv->atom_ok, res_term);
}


static ERL_NIF_TERM spi_transfer(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct SpiNifPriv *priv = enif_priv_data(env);
    struct SpiNifRes *res;
    ErlNifBinary bin_write;
    ERL_NIF_TERM bin_read;
    unsigned char *raw_bin_read;

    debug("spi_transfer");
    if (!enif_get_resource(env, argv[0], priv->spi_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[1], &bin_write))
        return enif_make_badarg(env);

    raw_bin_read = enif_make_new_binary(env, bin_write.size, &bin_read);
    if (!raw_bin_read)
        return enif_make_tuple2(env, priv->atom_error,
                                enif_make_atom(env, "alloc_failed"));

    if (hal_spi_transfer(res->fd, &res->config, bin_write.data, raw_bin_read, bin_write.size) < 0)
        return enif_make_tuple2(env, priv->atom_error,
                                enif_make_atom(env, "transfer_failed"));

    return enif_make_tuple2(env, priv->atom_ok, bin_read);
}


static ERL_NIF_TERM spi_close(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct SpiNifPriv *priv = enif_priv_data(env);
    struct SpiNifRes *res;
    debug("spi_close");

    if (!enif_get_resource(env, argv[0], priv->spi_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (res->fd >= 0) {
        hal_spi_close(res->fd);
        res->fd = -1;
    }

    return priv->atom_ok;
}

static ERL_NIF_TERM spi_info(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    return hal_info(env);
}

static ERL_NIF_TERM spi_max_transfer_size(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    return hal_max_transfer_size(env);
}

static ErlNifFunc nif_funcs[] =
{
    {"open", 5, spi_open, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"transfer", 2, spi_transfer, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"close", 1, spi_close, 0},
    {"info", 0, spi_info, 0},
    {"max_transfer_size", 0, spi_max_transfer_size, ERL_NIF_DIRTY_JOB_IO_BOUND}
};

ERL_NIF_INIT(Elixir.Circuits.SPI.Nif, nif_funcs, spi_load, NULL, NULL, spi_unload)
