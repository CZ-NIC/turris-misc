/*
 * init-thermometer - utility to initialize the hardware thermometer
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
#include <stdbool.h>
#include <errno.h>
#include <string.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define HANDLE_ERROR (fprintf(stderr, "ERROR: %s\n", strerror(errno)))

#define I2C_LOCAL "/dev/i2c-0"
#define I2C_ADDRESS_7_THERMOMETER 0x4C

#define LOCAL_HIGH_REG 0x0B
#define REMOTE_HIGH_REG 0x0D
#define LOCAL_T_CRIT_REG 0x20
#define REMOTE_T_CRIT_REG 0x19
#define HISTERSE_T_CRIT_REG 0x21
#define CONV_RATE_REG 0x0A
#define ALERT_MODE_REG 0xBF

//Commands set for thermometer
unsigned char commands[][2] = {
	{ LOCAL_HIGH_REG,		0x32 }, // 50C ==> 0x32
	{ REMOTE_HIGH_REG,		0x50 }, // 80C ==> 0x50
	{ LOCAL_T_CRIT_REG,		0x41 }, // 65C ==> 0x41
	{ REMOTE_T_CRIT_REG,	0x5F }, // 95C ==> 0x5F
	{ HISTERSE_T_CRIT_REG,	0x05 }, // 5C  ==> 0x05
	{ CONV_RATE_REG,		0x08 }, // 16Hz ==> 0x08
	{ ALERT_MODE_REG,		0x00 }, // Iterrupt mode ==> 0x00
	{ 0, 0 }
};

int main(int argc, char **argv) {
	(void) argc; (void) argv;
	//Prepare I2C device
	int fd = open(I2C_LOCAL, O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "Cannot open I2C raw device.\n");
		return 2;
	}
	if (ioctl(fd, I2C_SLAVE, I2C_ADDRESS_7_THERMOMETER) < 0) {
		HANDLE_ERROR;
		return 1;
	}

	//Send configuration
	for (size_t i = 0; commands[i][0] != 0; i++) {
		if (write(fd, commands[i], 2) < 0) {
			HANDLE_ERROR;
			return 2;
		}
	}

	//Close files and devices
	close(fd);

	return 0;
}
