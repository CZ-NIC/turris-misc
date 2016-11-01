/*
 * This program sends "beacon" to stop boot of Marvell Armada 385
 * so it waits for kwboot to load up U-Boot.
 *
 * Copyright (C) 2016 CZ.NIC
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * Procedure:
 *  1) Connect the serial line to the router
 *  2) Run the program.
 *  3) Power up the router within 5 sec.
 *  4) Wait for the program to finish and run kwboot ... to load up U-Boot.
 */

#include <errno.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

#define READ_BUFFER_SIZE 100
#define VERIFY_LEN 20
#define VERIFY_CHR 0x15
#define error_message(args...) fprintf(stderr, args)

static pthread_barrier_t barrier;

int set_interface_attribs(int fd, int speed, int parity)
{
	struct termios tty;
	memset(&tty, 0, sizeof tty);
	if(tcgetattr(fd, &tty) != 0) {
		error_message("error %d from tcgetattr\n", errno);
		return -1;
	}

	cfsetospeed(&tty, speed);
	cfsetispeed(&tty, speed);

	tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;     // 8-bit chars
	tty.c_lflag = 0;
	tty.c_oflag = 0;
	tty.c_cc[VMIN]  = 0;
	tty.c_cc[VTIME] = 5;
	tty.c_cflag |= (CLOCAL | CREAD);
	tty.c_cflag &= ~(PARENB | PARODD);
	tty.c_cflag |= parity;
	tty.c_cflag &= ~CSTOPB;
	tty.c_cflag &= ~CRTSCTS;

	if(tcsetattr(fd, TCSANOW, &tty) != 0) {
		error_message("error %d from tcsetattr\n", errno);
		return -1;
	}
	return 0;
}

void set_blocking(int fd, char block, char timeout)
{
	struct termios tty;
	memset(&tty, 0, sizeof tty);
	if(tcgetattr(fd, &tty) != 0) {
		error_message("error %d from tggetattr\n", errno);
		return;
	}

	tty.c_cc[VMIN] = block;
	tty.c_cc[VTIME] = timeout;

	if(tcsetattr(fd, TCSANOW, &tty) != 0)
		error_message("error %d setting term attributes\n", errno);
}

void print_usage()
{
	printf("usage: sendbeacon <serial_device>\n");
}

void * write_handler(void *ptr)
{
	char *path = (char *)ptr;
	while (1) {
		int fd = open(path, O_WRONLY | O_NOCTTY | O_SYNC);
		if(fd < 0) {
			error_message("error %d opening %s: %s\n", errno, path, strerror(errno));
			return NULL;
		}

		set_interface_attribs(fd, B115200, 0);
		set_blocking(fd, 0, 5);

		// write for some time
		char buf [8] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0xbb};
		int i;
		for (i = 0; i < 10000; i++) {
			write(fd, buf, 8);
		}
		close(fd);

		pthread_barrier_wait(&barrier);
	}
}

void * read_handler(void *ptr)
{
	char *path = (char *)ptr;
	char expected[VERIFY_LEN];
	memset(expected, VERIFY_CHR, VERIFY_LEN);

	while (1) {
		int fd = open(path, O_RDONLY | O_NOCTTY | O_SYNC);
		if(fd < 0) {
			error_message("error %d opening %s: %s\n", errno, path, strerror(errno));
			return NULL;
		}

		set_interface_attribs(fd, B115200, 0);
		set_blocking(fd, VERIFY_LEN, 5);

		char buffer[READ_BUFFER_SIZE];
		int cnt = read(fd, buffer, sizeof buffer);
		if (cnt) {
			int i;
			for (i = 0; i < cnt; ++i) {
				printf("%02X", (unsigned char)buffer[i]);
			}
			printf("\n");
			if (cnt == VERIFY_LEN) {
				if (0 == memcmp(expected, buffer, VERIFY_LEN)) {
					exit(0);
				}
			}
		}
		close(fd);

		pthread_barrier_wait(&barrier);
	}
}

int main(int argc, char **argv)
{
	if (argc != 2) {
		print_usage();
		return 1;
	}

	if (argv[1] == "-h") {
		print_usage();
		return 0;
	}

	char *portname = argv[1];

	// init barrier
	int res = pthread_barrier_init(&barrier, NULL, 2);
	if (res != 0) {
		error_message("pthread_barrier_init failed!\n");
		return 1;
	}

	// create worker threads
	pthread_t write_thread;
	res = pthread_create(&write_thread, NULL, write_handler, (void *) portname);
	if (res != 0) {
		error_message("failed to create write thread!\n");
		return 1;
	}

	pthread_t read_thread;
	res = pthread_create(&read_thread, NULL, read_handler, (void *) portname);
	if (res != 0) {
		error_message("failed to create read thread!\n");
		return 1;
	}

	pthread_join(write_thread, NULL);
	pthread_join(read_thread, NULL);

	// this should not be reached if no error is triggered
	return 1;
}

