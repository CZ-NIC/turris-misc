#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <time.h>

#define BUFFSIZE 512
#define SNAPSHOT_COUNT 80
#define SLEEP_TIME_USEC 3000000
#define SNIFF_FILE_NET "/proc/net/dev"
#define SNIFF_FILE_CPU "/proc/loadavg"
#define SNIFF_FILE_MEM "/proc/meminfo"
#define OUTPUT_FILE "/tmp/nethist.tmp"
#define FINAL_FILE "/tmp/nethist"
#define TEMPERATURE_CMD "thermometer"

#define MAX_LEN_INTERFACE_NAME 20
#define MAX_LEN_INTERFACE_LIST 20

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

struct network_configuration {
	char interfaces[MAX_LEN_INTERFACE_LIST][MAX_LEN_INTERFACE_NAME];
	size_t interfaces_cnt;
};

typedef struct {
	struct network_configuration network;
} configuration;

configuration g_config;

struct newtwork_interface_data {
	unsigned long long int r_bytes;
	unsigned long long int t_bytes;
};

struct network_snapshot {
	struct newtwork_interface_data interface[MAX_LEN_INTERFACE_LIST];
};

struct cpu_snapshot {
	float load;
};

struct memory_snapshot {
	unsigned long long int memtotal;
	unsigned long long int memfree;
	unsigned long long int buffers;
	unsigned long long int cached;
};


struct temperature_snapshot {
	unsigned int board;
	unsigned int cpu;
};

typedef struct {
	unsigned long long int timestamp;
	struct network_snapshot network;
	struct cpu_snapshot cpu;
	struct memory_snapshot memory;
	struct temperature_snapshot temperature;
	//struct cpu_snapshot cpu; //etc. etc.
} snapshot;

static void network_init_snapshot(struct network_snapshot *snapshot) {
	for (size_t i = 0; i < MAX_LEN_INTERFACE_LIST; i++) {
		snapshot->interface[i].r_bytes = 0;
		snapshot->interface[i].t_bytes = 0;
	}
}

static void cpu_init_snapshot(struct cpu_snapshot *snapshot) {
		snapshot->load = 0;
}

static void memory_init_snapshot(struct memory_snapshot *snapshot) {
		snapshot->memtotal = 0;
		snapshot->memfree = 0;
		snapshot->cached = 0;
		snapshot->buffers = 0;
}

static void temperature_init_snapshot(struct temperature_snapshot *snapshot) {
		snapshot->board = 0;
		snapshot->cpu = 0;
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
	char name[MAX_LEN_INTERFACE_NAME];
	size_t newlen;
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
		sscanf(buffer, "%20s", name);
		newlen = strlen(name) - 1;
		name[newlen] = '\0';
		memcpy(g_config.network.interfaces[g_config.network.interfaces_cnt++], name, newlen);
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

		name[strlen(name)-1] = '\0';

		pos = network_get_interface_number(name);
		if (pos == g_config.network.interfaces_cnt) {
			if (execlp ("nethist", "nethist", NULL) == -1) {
				//OK, it isn't working, the dogwatch is going to does dirty work
				exit(1);
			}
		}

		snap->interface[pos].r_bytes = r_bytes;
		snap->interface[pos].t_bytes = t_bytes;
	}

	fclose(f);

	return true;
}

static bool cpu_take_snapshot(struct cpu_snapshot *snap) {
	FILE *f = fopen(SNIFF_FILE_CPU, "r");
	if (f == NULL) return false;

	if (fscanf(f, "%f", &snap->load) != 1) {
		fclose(f);
		return false;
	}

	fclose(f);
	return true;
}

static bool temperature_take_snapshot(struct temperature_snapshot *snap) {
	FILE *f = popen(TEMPERATURE_CMD, "r");
	if (f == NULL) return false;

	char dummy[64];

	if (fscanf(f, "%s%u%s%u", dummy, &snap->board, dummy, &snap->cpu) != 4) {
		pclose(f);
		return false;
	}

	pclose(f);
	return true;
}

static bool memory_take_snapshot(struct memory_snapshot *snap) {
	char buffer[BUFFSIZE];
	char dummy[64];
	FILE *f = fopen(SNIFF_FILE_MEM, "r");
	if (f == NULL) return false;

	//Get MemTotal
	if (fgets(buffer, BUFFSIZE, f) == NULL) {
		fclose(f);
		return false;
	}

	if (sscanf(buffer, "%s%llu", dummy, &snap->memtotal) != 2) {
		fclose(f);
		return false;
	}

	//Get MemFree
	if (fgets(buffer, BUFFSIZE, f) == NULL) {
		fclose(f);
		return false;
	}

	if (sscanf(buffer, "%s%llu", dummy, &snap->memfree) != 2) {
		fclose(f);
		return false;
	}

	//Get Buffers
	if (fgets(buffer, BUFFSIZE, f) == NULL) {
		fclose(f);
		return false;
	}

	if (sscanf(buffer, "%s%llu", dummy, &snap->buffers) != 2) {
		fclose(f);
		return false;
	}

	//Get Cached
	if (fgets(buffer, BUFFSIZE, f) == NULL) {
		fclose(f);
		return false;
	}

	if (sscanf(buffer, "%s%llu", dummy, &snap->cached) != 2) {
		fclose(f);
		return false;
	}

	fclose(f);
	return true;
}

static void init(snapshot *snapshots) {
	for (size_t i = 0; i < SNAPSHOT_COUNT; i++) {
		snapshots[i].timestamp = 0;
		network_init_snapshot(&(snapshots[i].network));
		cpu_init_snapshot(&(snapshots[i].cpu));
		memory_init_snapshot(&(snapshots[i].memory));
		temperature_init_snapshot(&(snapshots[i].temperature));
	}

	network_init_global();
}

static void take_snapshot(snapshot *snap) {
	snap->timestamp = (unsigned long long)time(NULL);
	network_take_snapshot(&(snap->network));
	cpu_take_snapshot(&(snap->cpu));
	memory_take_snapshot(&(snap->memory));
	temperature_take_snapshot(&(snap->temperature));
}

static void network_print_history(FILE *stream, unsigned long long int time, struct network_snapshot *snap) {
	for (size_t i = 0; i < g_config.network.interfaces_cnt; i++) {
		fprintf(stream, "%llu,%s,%s,%llu,%llu\n", time, "network", g_config.network.interfaces[i], snap->interface[i].r_bytes, snap->interface[i].t_bytes);
	}
}

static void cpu_print_history(FILE *stream, unsigned long long int time, struct cpu_snapshot *snap) {
	fprintf(stream, "%llu,%s,%f\n", time, "cpu", snap->load);
}

static void temperature_print_history(FILE *stream, unsigned long long int time, struct temperature_snapshot *snap) {
	fprintf(stream, "%llu,%s,%u,%u\n", time, "temperature", snap->board, snap->cpu);
}

static void memory_print_history(FILE *stream, unsigned long long int time, struct memory_snapshot *snap) {
	fprintf(stream, "%llu,%s,%llu,%llu,%llu,%llu\n", time, "memory", snap->memtotal, snap->memfree, snap->buffers, snap->cached);
}

static void print_history(FILE *stream, snapshot *snapshots, size_t from) {
	size_t pos = from;

	for (int i = 0; i < SNAPSHOT_COUNT; i++) {
		network_print_history(stream, snapshots[pos].timestamp, &(snapshots[pos].network));
		cpu_print_history(stream, snapshots[pos].timestamp, &(snapshots[pos].cpu));
		memory_print_history(stream, snapshots[pos].timestamp, &(snapshots[pos].memory));
		temperature_print_history(stream, snapshots[pos].timestamp, &(snapshots[pos].temperature));
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

		print_history(fout, snapshots, write_to+1);

		fclose(fout);
		rename(OUTPUT_FILE, FINAL_FILE);

		write_to++;

		usleep(SLEEP_TIME_USEC);
	}


	return 0;
}
