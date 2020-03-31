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

#include "mp_uuid.h"
#include "msgpuck.h"
#include "mp_extension_types.h"
#include "lib/uuid/tt_uuid.h"

inline uint32_t
mp_sizeof_uuid()
{
	return mp_sizeof_ext(sizeof(struct tt_uuid));
}

struct tt_uuid *
uuid_unpack(const char **data, uint32_t len, struct tt_uuid *uuid)
{
	if (len != sizeof(*uuid))
		return NULL;
	memcpy(uuid, *data, sizeof(*uuid));
	if (tt_uuid_validate(uuid) != 0)
		return NULL;
	*data += sizeof(*uuid);
	return uuid;
}

struct tt_uuid *
mp_decode_uuid(const char **data, struct tt_uuid *uuid)
{
	if (mp_typeof(**data) != MP_EXT)
		return NULL;
	int8_t type;
	const char *const svp = *data;

	uint32_t len = mp_decode_extl(data, &type);
	if (type != MP_UUID || uuid_unpack(data, len, uuid) == NULL) {
		*data = svp;
		return NULL;
	}
	return uuid;
}

char *
mp_encode_uuid(char *data, const struct tt_uuid *uuid)
{
	return mp_encode_ext(data, MP_UUID, (char *)uuid, sizeof(*uuid));
}
