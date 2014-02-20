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
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>

#define I2C_LOCAL "/dev/i2c-0"
#define I2C_ADDRESS_7_ATSHA204 0x64
#define ATSHA204_STATUS_WAKE_OK 0x11
#define POLYNOM 0x8005

#define BUFFSIZE_NI2C 64
#define ATSHA204_I2C_CMD_TOUT 100000
#define HANDLE_ERROR (fprintf(stderr, "ERROR: %s\n", strerror(errno)))

/*
 * This source code is subset of libatsha204. So, don't care about weird naming
 * convention.
*/

const unsigned char cmd_prefix[] =	{ 0x03, 0x07, 0x02, 0x01, 0x03, 0x00, 0x12, 0xA7 };
const unsigned char cmd_mac[] =		{ 0x03, 0x07, 0x02, 0x01, 0x04, 0x00, 0x1E, 0xE7 };

void print_packet(unsigned char *data) {
	size_t to = (data[0] < BUFFSIZE_NI2C) ? data[0] : BUFFSIZE_NI2C;

	if (to == 0) {
		printf("[EMPTY]\n");
		return;
	}

	for (size_t i = 0; i < to; i++) {
		printf("0x%02X ", data[i]);
	}

	printf("\n");
}

void calculate_crc(uint16_t length, unsigned char *data, unsigned char *crc) {
	uint16_t counter;
	uint16_t crc_register = 0;
	uint16_t polynom = POLYNOM;
	unsigned char shift_register;
	unsigned char data_bit, crc_bit;

	for (counter = 0; counter < length; counter++) {
	  for (shift_register = 0x01; shift_register > 0x00; shift_register <<= 1) {
		 data_bit = (data[counter] & shift_register) ? 1 : 0;
		 crc_bit = crc_register >> 15;
		 crc_register <<= 1;
		 if (data_bit != crc_bit)
			crc_register ^= polynom;
	  }
	}
	crc[0] = (unsigned char) (crc_register & 0x00FF);
	crc[1] = (unsigned char) (crc_register >> 8);
}

bool check_crc(unsigned char length, unsigned char *data, unsigned char *crc) {
	unsigned char rcrc[2];
	calculate_crc(length, data, rcrc);
	if ((crc[0] != rcrc[0]) || (crc[1] != rcrc[1])) {
		return false;
	}

	return true;
}

void ni2c_wait() {
	usleep(ATSHA204_I2C_CMD_TOUT);
}

int main(int argc, char **argv) {
	(void) argc; (void) argv;
	assert(sizeof(unsigned int) >= 4);
	//Try to open I2C bus
	int fd = open(I2C_LOCAL, O_RDWR);
	if (fd < 0) {
		HANDLE_ERROR;
		return 1;
	}
	//Bind with chip address
	if (ioctl(fd, I2C_SLAVE, I2C_ADDRESS_7_ATSHA204) < 0) {
		HANDLE_ERROR;
		return 1;
	}
	//Prepare buffer
	unsigned char buffer[BUFFSIZE_NI2C];
	memset(buffer, 0, BUFFSIZE_NI2C);

	//Send wake command to device
	unsigned char wr_wake[] = { 0x00 };
	write(fd, wr_wake, 1); //DO NOT CHECK RETURN STATUS - fail is expected
	ni2c_wait();

	//Read answer
	if (read(fd, buffer, BUFFSIZE_NI2C) < 0) return 1;
	if (!check_crc(buffer[0] - 2, buffer, (buffer + buffer[0] - 2))) {
		fprintf(stderr, "CRC doesn't match.\n");
		return 1;
	}
	if (buffer[1] != ATSHA204_STATUS_WAKE_OK) return 1;

	//Prepare some variables
	unsigned int mac_as_number = 0, mac_as_number_orig = 0;
	unsigned char tmp_mac[6];

	////////////////////////////// MAC PREFIX //////////////////////////////////
	//Send read command for MAC prefix
	if (write(fd, cmd_prefix, cmd_prefix[1]+1) < 0) return 1;
	ni2c_wait();

	//Read answer
	if (read(fd, buffer, BUFFSIZE_NI2C) < 0) return 1;
	if (!check_crc(buffer[0] - 2, buffer, (buffer + buffer[0] - 2))) return 1;

	memcpy(tmp_mac, (buffer + 2), 3);

	////////////////////////////// MAC SUFFIX //////////////////////////////////
	//Send read command for MAC suffix
	if (write(fd, cmd_mac, cmd_mac[1]+1) < 0) return 1;
	ni2c_wait();

	//Read answer
	if (read(fd, buffer, BUFFSIZE_NI2C) < 0) return 1;
	if (!check_crc(buffer[0] - 2, buffer, (buffer + buffer[0] - 2))) {
		fprintf(stderr, "CRC doesn't match.\n");
		return 1;
	}

	mac_as_number_orig |= (buffer[2] << 8*2);
	mac_as_number_orig |= (buffer[3] << 8*1);
	mac_as_number_orig |= buffer[4];

	for (char i = 0; i < 3; i++) {
		mac_as_number = mac_as_number_orig;
		mac_as_number_orig++;

		tmp_mac[5] = mac_as_number & 0xFF; mac_as_number >>= 8;
		tmp_mac[4] = mac_as_number & 0xFF; mac_as_number >>= 8;
		tmp_mac[3] = mac_as_number & 0xFF; mac_as_number >>= 8;

		printf("%02X:%02X:%02X:%02X:%02X:%02X\n", tmp_mac[0], tmp_mac[1], tmp_mac[2], tmp_mac[3], tmp_mac[4], tmp_mac[5]);
	}
	close(fd);

	return 0;
}
