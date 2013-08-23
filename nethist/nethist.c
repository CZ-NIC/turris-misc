#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#define BUFFSIZE 512
#define SNAPSHOT_COUNT 100
#define SLEEP_TIME_USEC 3000000
#define SNIFF_FILE_NET "/proc/net/dev"

#define MAX_LEN_INTERFACE_NAME 20
#define MAX_LEN_INTERFACE_LIST 20

struct network_configuration {
	char interfaces[MAX_LEN_INTERFACE_LIST];
	size_t interfaces_cnt;
};

typedef struct {
	struct network_configuration network;
} configuration;

configuration g_config;

struct network_snapshot {
	unsigned long long interface[MAX_LEN_INTERFACE_LIST];
};

typedef struct {
	struct network_snapshot network;
	//struct cpu_snapshot cpu; //etc. etc.
} snapshot;


static void network_init_snapshot(struct network_snapshot *snapshot) {
	for (size_t i = 0; i < MAX_LEN_INTERFACE_LIST; i++) {
		snapshot->interface[i] = 0;
	}
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
		sscanf(buffer, "%20s", &g_config.network.interfaces[g_config.network.interfaces_cnt++]);
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

	while (fgets(buffer, BUFFSIZE, f) != NULL) {

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


		write_to++;
	}


	return 0;
}
