#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdbool.h>

#define BUFFSIZE 512
#define SNAPSHOT_COUNT 100
#define SLEEP_TIME_USEC 3000000
#define SNIFF_FILE_NET "/proc/net/dev"
#define OUTPUT_FILE "/tmp/nethist.tmp"
#define FINAL_FILE "/tmp/nethist"

#define MAX_LEN_INTERFACE_NAME 20
#define MAX_LEN_INTERFACE_LIST 20

struct network_configuration {
	char interfaces[MAX_LEN_INTERFACE_LIST][MAX_LEN_INTERFACE_NAME];
	size_t interfaces_cnt;
};

typedef struct {
	struct network_configuration network;
} configuration;

configuration g_config;

struct newtwork_interface_data {
	unsigned long long r_bytes;
	unsigned long long t_bytes;
};

struct network_snapshot {
	struct newtwork_interface_data interface[MAX_LEN_INTERFACE_LIST];
};

typedef struct {
	struct network_snapshot network;
	//struct cpu_snapshot cpu; //etc. etc.
} snapshot;

static void network_init_snapshot(struct network_snapshot *snapshot) {
	for (size_t i = 0; i < MAX_LEN_INTERFACE_LIST; i++) {
		snapshot->interface[i].r_bytes = 0;
		snapshot->interface[i].t_bytes = 0;
	}
}

static size_t network_get_interface_number(char *name) {
	for (size_t i = 0; i < g_config.network.interfaces_cnt; i++) {
		if (strcmp(name, g_config.network.interfaces[i]) == 0) {
			return i;
		}
	}

	return g_config.network.interfaces_cnt;
}

static bool network_init_global() {
	char buffer[BUFFSIZE];
	FILE *f = fopen(SNIFF_FILE_NET, "r");
	if (f == NULL) return false;

	for (size_t i = 0; i < 2; i++) { //skip first 2 lines
		if (fgets(buffer, BUFFSIZE, f) == NULL) {
			fclose(f);
			return false;
		}
	}

	g_config.network.interfaces_cnt = 0;

	while (fgets(buffer, BUFFSIZE, f) != NULL) {
		sscanf(buffer, "%20s", g_config.network.interfaces[g_config.network.interfaces_cnt++]);
	}

	fclose(f);

	return true;
}

static bool network_take_snapshot(struct network_snapshot *snap) {
	char buffer[BUFFSIZE];
	FILE *f = fopen(SNIFF_FILE_NET, "r");
	if (f == NULL) return false;

	for (size_t i = 0; i < 2; i++) { //skip first 2 lines
		if (fgets(buffer, BUFFSIZE, f) == NULL) {
			fclose(f);
			return false;
		}
	}

	char name[MAX_LEN_INTERFACE_NAME];
	size_t pos;
	unsigned long long r_bytes, t_bytes, dummy;
	while (fgets(buffer, BUFFSIZE, f) != NULL) {
		sscanf(buffer, "%20s%llu%llu%llu%llu%llu%llu%llu%llu%llu%llu%llu%llu%llu%llu%llu%llu",
			name, &r_bytes,
			&dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy,
			&t_bytes,
			&dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy
		);

		pos = network_get_interface_number(name);
		if (pos == g_config.network.interfaces_cnt) {
			printf("INTERRUPT\n");
			exit(1);
		}

		snap->interface[pos].r_bytes = r_bytes;
		snap->interface[pos].t_bytes = t_bytes;
	}

	fclose(f);

	return true;
}

static void init(snapshot *snapshots) {
	for (size_t i = 0; i < SNAPSHOT_COUNT; i++) {
		network_init_snapshot(&(snapshots[i].network));
	}

	network_init_global();
}

static void take_snapshot(snapshot *snap) {
	network_take_snapshot(&(snap->network));
}

static void network_print_history(FILE *stream, int time, struct network_snapshot *snap) {
	for (size_t i = 0; i < g_config.network.interfaces_cnt; i++) {
		fprintf(stream, "%d,%s,%llu,%llu\n", time, g_config.network.interfaces[i], snap->interface[i].r_bytes, snap->interface[i].t_bytes);
	}
}

static void print_history(FILE *stream, snapshot *snapshots, size_t from) {
	size_t pos = from;

	for (int i = 0; i < SNAPSHOT_COUNT; i++) {
		network_print_history(stream, i, &(snapshots[pos].network));
		pos = (pos + 1) % SNAPSHOT_COUNT;
	}

}

int main(int argc, char **argv) {
	(void) argc; (void) argv;

	snapshot snapshots[SNAPSHOT_COUNT];
	size_t write_to = 0;

	init(snapshots);

	while(true) {
		/*
		 * Using modulo is possibly not good idea - we expect very, very long runtime
		 */
		if (write_to == SNAPSHOT_COUNT) {
			write_to = 0;
		}

		take_snapshot(&(snapshots[write_to]));

		FILE *fout = fopen(OUTPUT_FILE, "w+");
		if (fout == NULL) {
			return 1;
		}
		print_history(fout, snapshots, write_to);
		fclose(fout);
		rename(OUTPUT_FILE, FINAL_FILE);

		write_to++;

		usleep(SLEEP_TIME_USEC);
	}


	return 0;
}
