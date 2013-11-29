#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <openssl/sha.h>

/*
 * Copyright (c) 2013, CZ.NIC, z.s.p.o. (http://www.nic.cz/)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *    * Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *    * Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *    * Neither the name of the CZ.NIC nor the
 *      names of its contributors may be used to endorse or promote products
 *      derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL CZ.NIC BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Purpose of this program:
 * This is similar to cat in that it reads lines from standard input
 * and writes them to standard output. However, it remembers what was
 * already read last time (in provided cache file) and skips that.
 *
 * It is done by remembering the sha1 hash of the last line of output.
 */

/*
 * These two function read the whole input and produce array of strings.
 * The array is terminated by NULL.
 *
 * Note: we don't free the allocated memory here. As we terminate right
 * after writing the data out, there's no need.
 */
static const char *read_line() {
	size_t buf_size = 10;
	size_t pos = 0;
	char *result = malloc(buf_size + 1);
	while (fgets(result + pos, buf_size - pos, stdin)) {
		size_t len = strlen(result + pos);
		if (result[pos + len - 1] == '\n')
			return result;
		pos += len;
		result = realloc(result, (buf_size = buf_size * 2 + 10) + 1);
	}
	return pos ? result : NULL;
}

static const char *const *read_lines() {
	size_t size = 0, allocated = 0;
	const char **result = NULL;
	do {
		if (size == allocated)
			result = realloc(result, (allocated = 2 * allocated + 10) * sizeof *result);
	} while ((result[size ++] = read_line())); // Keep reading until you find NULL
	return result;
}

static const char *seen = NULL;

static void dump_lines(const char *const *lines) {
	while (*lines)
		fputs(seen = *lines ++, stdout);
}

static uint8_t last[SHA_DIGEST_LENGTH] = {0};

static void sha(const char *line, uint8_t *buffer) {
	SHA_CTX context;
	SHA1_Init(&context);
	SHA1_Update(&context, line, strlen(line));
	SHA1_Final(buffer, &context);
}

int main(int argc, const char *argv[]) {
	if (!argv[1]) {
		fprintf(stderr, "Need to know the cache file\n");
		return 1;
	}
	int cache = open(argv[1], O_RDONLY);
	if (cache == -1) {
		if (errno != ENOENT) {
			perror("Can't open the cache:");
			return 1;
		}
	} else {
		ssize_t result = read(cache, last, SHA_DIGEST_LENGTH);
		if (result == -1) {
			perror("Can't read the cache:");
			return 1;
		}
		if (result != SHA_DIGEST_LENGTH) {
			fputs("Corrupt cache\n", stderr);
			return 1;
		}
		close(cache);
	}
	const char *const *lines = read_lines();
	for (const char *const *current = lines; *current; current ++) {
		static uint8_t buffer[SHA_DIGEST_LENGTH];
		sha(*current, buffer);
		if (memcmp(buffer, last, SHA_DIGEST_LENGTH) == 0) {
			lines = current + 1;
			break;
		}
	}
	dump_lines(lines);
	if (seen)
		sha(seen, last);
	cache = open(argv[1], O_WRONLY | O_CREAT, S_IRUSR | S_IWUSR);
	if (cache == -1) {
		perror("Can't open cache for write:");
		return 1;
	}
	ssize_t result = write(cache, last, SHA_DIGEST_LENGTH);
	if (result == -1) {
		perror("Can't write the cache:");
		return 1;
	}
	if (result != SHA_DIGEST_LENGTH) {
		fputs("Short write to cache\n", stderr);
		return 1;
	}
	close(cache);
	return 0;
}
