#ifndef TARANTOOL_LIB_CORE_MP_UUID_INCLUDED
#define TARANTOOL_LIB_CORE_MP_UUID_INCLUDED
/*
 * Copyright 2020, Tarantool AUTHORS, please see AUTHORS file.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 * 1. Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * <COPYRIGHT HOLDER> OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif /* defined(__cplusplus) */

struct tt_uuid;

/**
 * \brief Return the number of bytes an encoded uuid value takes.
 */
uint32_t
mp_sizeof_uuid();

/**
 * Copy a uuid value from a buffer. Can be used in a combination
 * with mp_decode_extl() instead of mp_decode_uuid() when multiple
 * extension types are possible.
 *
 * \param data A buffer.
 * \param len Length returned by mp_decode_extl, has to be equal
 *            to sizeof(struct tt_uuid), otherwise an error is
 *            returned.
 * \param[out] uuid Uuid to be decoded.
 * \return A pointer to the decoded uuid.
 *         NULL in case of an error.
 * \post *data = *data + sizeof(struct tt_uuid).
 */
struct tt_uuid *
uuid_unpack(const char **data, uint32_t len, struct tt_uuid *uuid);

/**
 * \brief Decode a uuid from MsgPack \a data.
 * \param data A buffer.
 * \param[out] uuid Uuid to be decoded.
 * \return A pointer to the decoded uuid.
 *         NULL in case of an error.
 * \post *data = *data + mp_sizeof_uuid().
 */
struct tt_uuid *
mp_decode_uuid(const char **data, struct tt_uuid *uuid);

/**
 * \brief Encode a uuid.
 * \param data A buffer.
 * \param uuid A uuid to encode.
 *
 * \return \a data + mp_sizeof_uuid()
 */
char *
mp_encode_uuid(char *data, const struct tt_uuid *uuid);

#if defined(__cplusplus)
} /* extern "C" */
#endif /* defined(__cplusplus) */

#endif /* TARANTOOL_LIB_CORE_MP_UUID_INCLUDED */
