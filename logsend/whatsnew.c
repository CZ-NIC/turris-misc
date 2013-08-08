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

const char *read_line() {
	size_t buf_size = 10;
	size_t pos = 0;
	char *result = malloc(buf_size + 1);
	while (fgets(result + pos, buf_size, stdin)) {
		size_t len = strlen(result + pos);
		if (result[pos + len - 1] == '\n')
			return result;
		pos += len;
		result = realloc(result, (buf_size = buf_size * 2 + 10) + 1);
	}
	return pos ? result : NULL;
}

const char *const *read_lines() {
	size_t size = 0, allocated = 0;
	const char **result = NULL;
	do {
		if (size == allocated)
			result = realloc(result, (allocated = 2 * allocated + 10) * sizeof *result);
	} while ((result[size ++] = read_line())); // Keep reading until you find NULL
	return result;
}

void dump_lines(const char *const *lines) {
	while (*lines)
		fputs(*lines ++, stdout);
}

uint8_t last[SHA_DIGEST_LENGTH] = {0};

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
	dump_lines(lines);
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
