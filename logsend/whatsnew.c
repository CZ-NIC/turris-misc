#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

int main(int argc, const char *argv[]) {
	const char *const *lines = read_lines();
	dump_lines(lines);
	return 0;
}
