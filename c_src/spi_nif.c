// SPDX-FileCopyrightText: 2018 Frank Hunleth, Mark Sebald
//
// SPDX-License-Identifier: Apache-2.0

#include "spi_nif.h"

// SPI NIF Private data
struct SpiNifPriv {
    ErlNifResourceType *spi_nif_res_type;
};

// SPI NIF Resource.
struct SpiNifRes {
    int fd;
    struct SpiConfig config;
};

static ERL_NIF_TERM atom_ok;
static ERL_NIF_TERM atom_error;
static ERL_NIF_TERM atom_true;
static ERL_NIF_TERM atom_false;
static ERL_NIF_TERM atom_mode;
static ERL_NIF_TERM atom_bits_per_word;
static ERL_NIF_TERM atom_speed_hz;
static ERL_NIF_TERM atom_delay_us;
static ERL_NIF_TERM atom_lsb_first;
static ERL_NIF_TERM atom_sw_lsb_first;

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

    atom_ok = enif_make_atom(env, "ok");
    atom_error = enif_make_atom(env, "error");
    atom_true = enif_make_atom(env, "true");
    atom_false = enif_make_atom(env, "false");
    atom_mode = enif_make_atom(env, "mode");
    atom_bits_per_word = enif_make_atom(env, "bits_per_word");
    atom_speed_hz = enif_make_atom(env, "speed_hz");
    atom_delay_us = enif_make_atom(env, "delay_us");
    atom_lsb_first = enif_make_atom(env, "lsb_first");
    atom_sw_lsb_first = enif_make_atom(env, "sw_lsb_first");

    *priv_data = priv;
    return 0;
}

static void spi_unload(ErlNifEnv *env, void *priv_data)
{
    debug("spi_unload");
    enif_free(priv_data);
}

static inline ERL_NIF_TERM make_boolean(int value)
{
    return value ? atom_true : atom_false;
}

static inline int get_boolean(ErlNifEnv* env, ERL_NIF_TERM term, int *out)
{
    *out = (term != atom_false);
    return 1;
}

static ERL_NIF_TERM spi_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct SpiNifPriv *priv = enif_priv_data(env);
    ErlNifBinary path;
    struct SpiConfig config;
    memset(&config, 0, sizeof(config));

    debug("spi_open");
    if (!enif_inspect_binary(env, argv[0], &path) ||
            !enif_get_uint(env, argv[1], &config.mode) ||
            !enif_get_uint(env, argv[2], &config.bits_per_word) ||
            !enif_get_uint(env, argv[3], &config.speed_hz) ||
            !enif_get_uint(env, argv[4], &config.delay_us) ||
            !get_boolean(env, argv[5], &config.lsb_first))
        return enif_make_badarg(env);

    char devpath[32];
    snprintf(devpath, sizeof(devpath), "/dev/%.*s", (int) path.size, path.data);

    char error_str[128];
    int fd = hal_spi_open(devpath, &config, error_str);
    if (fd < 0) {
        return enif_make_tuple2(env, atom_error,
                                enif_make_atom(env, error_str));
    }

    struct SpiNifRes *spi_nif_res = enif_alloc_resource(priv->spi_nif_res_type, sizeof(struct SpiNifRes));
    spi_nif_res->fd = fd;
    spi_nif_res->config = config;
    ERL_NIF_TERM res_term = enif_make_resource(env, spi_nif_res);

    // Elixir side owns the resource. Safe for NIF side to release it.
    enif_release_resource(spi_nif_res);

    return enif_make_tuple2(env, atom_ok, res_term);
}

static ERL_NIF_TERM spi_config(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct SpiNifPriv *priv = enif_priv_data(env);
    struct SpiNifRes *res;

    debug("spi_get_config");

    if (!enif_get_resource(env, argv[0], priv->spi_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    ERL_NIF_TERM config = enif_make_new_map(env);
    enif_make_map_put(env, config, atom_mode, enif_make_uint(env, res->config.mode), &config);
    enif_make_map_put(env, config, atom_bits_per_word, enif_make_uint(env, res->config.bits_per_word), &config);
    enif_make_map_put(env, config, atom_speed_hz, enif_make_uint(env, res->config.speed_hz), &config);
    enif_make_map_put(env, config, atom_delay_us, enif_make_uint(env, res->config.delay_us), &config);
    enif_make_map_put(env, config, atom_lsb_first, make_boolean(res->config.lsb_first), &config);
    enif_make_map_put(env, config, atom_sw_lsb_first, make_boolean(res->config.sw_lsb_first), &config);

    return enif_make_tuple2(env, atom_ok, config);
}

static void reverse_bits(uint8_t *dest, const uint8_t *src, size_t len)
{
    static const uint8_t reverse[256] = {
        0x00, 0x80, 0x40, 0xc0, 0x20, 0xa0, 0x60, 0xe0, 0x10, 0x90, 0x50, 0xd0, 0x30, 0xb0, 0x70, 0xf0,
        0x08, 0x88, 0x48, 0xc8, 0x28, 0xa8, 0x68, 0xe8, 0x18, 0x98, 0x58, 0xd8, 0x38, 0xb8, 0x78, 0xf8,
        0x04, 0x84, 0x44, 0xc4, 0x24, 0xa4, 0x64, 0xe4, 0x14, 0x94, 0x54, 0xd4, 0x34, 0xb4, 0x74, 0xf4,
        0x0c, 0x8c, 0x4c, 0xcc, 0x2c, 0xac, 0x6c, 0xec, 0x1c, 0x9c, 0x5c, 0xdc, 0x3c, 0xbc, 0x7c, 0xfc,
        0x02, 0x82, 0x42, 0xc2, 0x22, 0xa2, 0x62, 0xe2, 0x12, 0x92, 0x52, 0xd2, 0x32, 0xb2, 0x72, 0xf2,
        0x0a, 0x8a, 0x4a, 0xca, 0x2a, 0xaa, 0x6a, 0xea, 0x1a, 0x9a, 0x5a, 0xda, 0x3a, 0xba, 0x7a, 0xfa,
        0x06, 0x86, 0x46, 0xc6, 0x26, 0xa6, 0x66, 0xe6, 0x16, 0x96, 0x56, 0xd6, 0x36, 0xb6, 0x76, 0xf6,
        0x0e, 0x8e, 0x4e, 0xce, 0x2e, 0xae, 0x6e, 0xee, 0x1e, 0x9e, 0x5e, 0xde, 0x3e, 0xbe, 0x7e, 0xfe,
        0x01, 0x81, 0x41, 0xc1, 0x21, 0xa1, 0x61, 0xe1, 0x11, 0x91, 0x51, 0xd1, 0x31, 0xb1, 0x71, 0xf1,
        0x09, 0x89, 0x49, 0xc9, 0x29, 0xa9, 0x69, 0xe9, 0x19, 0x99, 0x59, 0xd9, 0x39, 0xb9, 0x79, 0xf9,
        0x05, 0x85, 0x45, 0xc5, 0x25, 0xa5, 0x65, 0xe5, 0x15, 0x95, 0x55, 0xd5, 0x35, 0xb5, 0x75, 0xf5,
        0x0d, 0x8d, 0x4d, 0xcd, 0x2d, 0xad, 0x6d, 0xed, 0x1d, 0x9d, 0x5d, 0xdd, 0x3d, 0xbd, 0x7d, 0xfd,
        0x03, 0x83, 0x43, 0xc3, 0x23, 0xa3, 0x63, 0xe3, 0x13, 0x93, 0x53, 0xd3, 0x33, 0xb3, 0x73, 0xf3,
        0x0b, 0x8b, 0x4b, 0xcb, 0x2b, 0xab, 0x6b, 0xeb, 0x1b, 0x9b, 0x5b, 0xdb, 0x3b, 0xbb, 0x7b, 0xfb,
        0x07, 0x87, 0x47, 0xc7, 0x27, 0xa7, 0x67, 0xe7, 0x17, 0x97, 0x57, 0xd7, 0x37, 0xb7, 0x77, 0xf7,
        0x0f, 0x8f, 0x4f, 0xcf, 0x2f, 0xaf, 0x6f, 0xef, 0x1f, 0x9f, 0x5f, 0xdf, 0x3f, 0xbf, 0x7f, 0xff
    };

    size_t i;
    for (i = 0; i < len; i++) {
        dest[i] = reverse[src[i]];
    }
}

static ERL_NIF_TERM spi_transfer(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct SpiNifPriv *priv = enif_priv_data(env);
    struct SpiNifRes *res;
    ErlNifBinary bin_write;
    ERL_NIF_TERM bin_read;
    unsigned char *raw_bin_read;
    unsigned char *to_write;
    size_t transfer_size;

    debug("spi_transfer");
    if (!enif_get_resource(env, argv[0], priv->spi_nif_res_type, (void **)&res) ||
            !enif_inspect_iolist_as_binary(env, argv[1], &bin_write))
        return enif_make_badarg(env);

    transfer_size = bin_write.size;

    raw_bin_read = enif_make_new_binary(env, transfer_size, &bin_read);
    if (!raw_bin_read)
        return enif_make_tuple2(env, atom_error,
                                enif_make_atom(env, "alloc_failed"));

    if (res->config.sw_lsb_first) {
        to_write = enif_alloc(transfer_size);
        if (!to_write)
            return enif_make_tuple2(env, atom_error,
                                    enif_make_atom(env, "alloc_failed"));
        reverse_bits(to_write, bin_write.data, transfer_size);
    } else {
        to_write = bin_write.data;
    }

    if (hal_spi_transfer(res->fd, &res->config, to_write, raw_bin_read, transfer_size) < 0)
        return enif_make_tuple2(env, atom_error,
                                enif_make_atom(env, "transfer_failed"));

    if (res->config.sw_lsb_first) {
        reverse_bits(raw_bin_read, raw_bin_read, transfer_size);
        enif_free(to_write);
    }

    return enif_make_tuple2(env, atom_ok, bin_read);
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

    return atom_ok;
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
    {"open", 6, spi_open, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"config", 1, spi_config, 0},
    {"transfer", 2, spi_transfer, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"close", 1, spi_close, 0},
    {"info", 0, spi_info, 0},
    {"max_transfer_size", 0, spi_max_transfer_size, ERL_NIF_DIRTY_JOB_IO_BOUND}
};

ERL_NIF_INIT(Elixir.Circuits.SPI.Nif, nif_funcs, spi_load, NULL, NULL, spi_unload)
