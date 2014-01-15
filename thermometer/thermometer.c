/*
 * thermometer - utility that enables read temperature of Turris router
 *
 * Copyright (C) 2013 CZ.NIC, z.s.p.o. (http://www.nic.cz/)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <linux/i2c-dev.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define I2C_LOCAL "/dev/i2c-0"
#define I2C_ADDRESS_7_THERMOMETER 0x4C

#define BUFFSIZE 64
#define HANDLE_ERROR (fprintf(stderr, "ERROR: %s\n", strerror(errno)))

int main(int argc, char **argv) {
	const char *path = I2C_LOCAL;
	if (argc == 2) {
		path = argv[1];
	}

	int fd = 0;
	fd = open(path, O_RDWR);
	if (fd < 0) {
		HANDLE_ERROR;
		return 1;
	}
	if (ioctl(fd, I2C_SLAVE, I2C_ADDRESS_7_THERMOMETER) < 0) {
		HANDLE_ERROR;
		return 1;
	}

	//Prepare data
	char buff[BUFFSIZE];
	//Read local temperature
	buff[0] = 0x00;
	if (write(fd, buff, 1) != 1) {
		HANDLE_ERROR;
		return 2;
	}
	if (read(fd, buff, 1) != 1) {
		HANDLE_ERROR;
		return 3;
	} else {
		printf("Board:\t%u\n", (unsigned int)(buff[0]));
	}
	//Read remote temperature
	buff[0] = 0x01;
	if (write(fd, buff, 1) != 1) {
		HANDLE_ERROR;
		return 2;
	}
	if (read(fd, buff, 1) != 1) {
		HANDLE_ERROR;
		return 3;
	} else {
		printf("CPU:\t%u\n", (unsigned int)(buff[0]));
	}

	return 0;
}
