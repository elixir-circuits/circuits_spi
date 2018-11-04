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

    priv->spi_nif_res_type = enif_open_resource_type(env, NULL, "spi_nif_res_type", NULL, ERL_NIF_RT_CREATE, NULL);
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
    struct SpiNifPriv *priv = enif_priv_data(env);

    enif_free(priv);
}


static ERL_NIF_TERM spi_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct SpiNifPriv *priv = enif_priv_data(env);
    char devpath[64] = "/dev/";
    char device[16];
    unsigned int mode;
    unsigned int bits_per_word;
    unsigned int speed_hz;
    unsigned int delay_us;
    char error_str[128];

    if (!enif_get_string(env, argv[0], device, sizeof(device), ERL_NIF_LATIN1))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[1], &mode))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[2], &bits_per_word))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[3], &speed_hz))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[4], &delay_us))
        return enif_make_badarg(env);

    strcat(devpath, device);
    int fd = open(devpath, O_RDWR);
    if (fd < 0)
        return enif_make_tuple2(env, priv->atom_error,
                                enif_make_atom(env, "access_denied"));

    // Set these to check for bad values given by the user. They get
    // set again on each transfer.
    if (ioctl(fd, SPI_IOC_WR_MODE, &mode) < 0) {
        sprintf(error_str, "ioctl(SPI_IOC_WR_MODE_%d)", mode);
        return enif_make_tuple2(env, priv->atom_error,
                                enif_make_atom(env, error_str));
    }

    if (ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits_per_word) < 0) {
        sprintf(error_str, "ioctl(SPI_IOC_WR_BITS_PER_WORD_%d)", bits_per_word);
        return enif_make_tuple2(env, priv->atom_error,
                                enif_make_atom(env, error_str));
    }

    if (ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed_hz) < 0) {
        sprintf(error_str, "ioctl(SPI_IOC_WR_MAX_SPEED_HZ_%d)", speed_hz);
        return enif_make_tuple2(env, priv->atom_error,
                                enif_make_atom(env, error_str));
    }

    struct SpiNifRes *spi_nif_res = enif_alloc_resource(priv->spi_nif_res_type, sizeof(struct SpiNifRes));

    spi_nif_res->fd = fd;
    spi_nif_res->transfer.bits_per_word = bits_per_word;
    spi_nif_res->transfer.speed_hz = speed_hz;
    spi_nif_res->transfer.delay_usecs = delay_us;
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
    ErlNifBinary bin_read;
    uint8_t read_data[SPI_TRANSFER_MAX];

    if (!enif_get_resource(env, argv[0], priv->spi_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[1], &bin_write))
        return enif_make_badarg(env);

    struct spi_ioc_transfer tfer = res->transfer;

    // The Linux header spidev.h expects pointers to be in 64-bit integers (__u64),
    // but pointers on Raspberry Pi are only 32 bits.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpointer-to-int-cast"
    tfer.tx_buf = (__u64) bin_write.data;
    tfer.rx_buf = (__u64) read_data;
#pragma GCC diagnostic pop
    tfer.len = bin_write.size;

    if (ioctl(res->fd, SPI_IOC_MESSAGE(1), &tfer) < 1)
        return enif_make_tuple2(env, priv->atom_error,
                                enif_make_atom(env, "transfer_failed"));

    bin_read.data = read_data;
    bin_read.size = bin_write.size;
    return enif_make_tuple2(env, priv->atom_ok, enif_make_binary(env, &bin_read));
}


static ERL_NIF_TERM spi_close(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct SpiNifPriv *priv = enif_priv_data(env);
    struct SpiNifRes *res;

    if (!enif_get_resource(env, argv[0], priv->spi_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    res->fd = -1;

    return priv->atom_ok;
}

static ErlNifFunc nif_funcs[] =
{
    {"open", 5, spi_open, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"transfer", 2, spi_transfer, 0},
    {"close", 1, spi_close, 0}
};

ERL_NIF_INIT(Elixir.Circuits.SPI.Nif, nif_funcs, spi_load, NULL, NULL, spi_unload)
