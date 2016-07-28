#!/usr/bin/python

import sys
import os
import select
import time

sfpdet_pin = 508
sfpdis_pin = 505
sfplos_pin = 507
sfpflt_pin = 504

gpio_export = '/sys/class/gpio/export'
sfp_select = '/sys/devices/platform/soc/soc:internal-regs/f1034000.ethernet/net/eth1/phy_select'
map = { 1: 'phy-def', 0: 'phy-sfp' }
cmd_net_res = 'ip link set down dev eth1; /etc/init.d/network restart'
cmd_safety_sleep = 2
wan_led = '/sys/devices/platform/soc/soc:internal-regs/f1011000.i2c/i2c-0/i2c-1/1-002b/leds/omnia-led:wan'

def write_once(path, value):
	with open(path, 'w') as f:
		f.write(value)



def gpio_dir(pin):
	return '/sys/class/gpio/gpio%d/' % pin

def init_gpio(pin):
	if not (os.path.exists(gpio_dir(pin)) and
		os.path.isdir(gpio_dir(pin))):
		write_once(gpio_export, str(pin))

	if not (os.path.exists(gpio_dir(pin)) and
		os.path.isdir(gpio_dir(pin))):
		raise Exception('Can not access %s' % gpio_dir(pin))
	

def init():
	init_gpio(sfpdet_pin)
	write_once(os.path.join(gpio_dir(sfpdet_pin), 'direction'), 'in')
	write_once(os.path.join(gpio_dir(sfpdet_pin), 'edge'), 'both')

	init_gpio(sfpdis_pin)
	write_once(os.path.join(gpio_dir(sfpdis_pin), 'direction'), 'out')
	write_once(os.path.join(gpio_dir(sfpdis_pin), 'value'), '0')

	init_gpio(sfplos_pin)
	write_once(os.path.join(gpio_dir(sfplos_pin), 'direction'), 'in')
	write_once(os.path.join(gpio_dir(sfplos_pin), 'edge'), 'both')

	init_gpio(sfpflt_pin)
	write_once(os.path.join(gpio_dir(sfpflt_pin), 'direction'), 'in')
	write_once(os.path.join(gpio_dir(sfpflt_pin), 'edge'), 'both')

def set_led_mode(state):
	if state == 1: # phy-def, autonomous blink
		write_once(os.path.join(wan_led, 'autonomous'), '1')
	elif state == 0: # phy-sfp, user blink
		write_once(os.path.join(wan_led, 'autonomous'), '0')
	else:
		raise Exception("Unknown state %d. Can not happen." % state)

def set_led_brightness(light=False):
	write_once(os.path.join(wan_led, 'brightness'), '1' if light else '0')

def do_switch(state, restart_net=True):
	print 'Switching state to %s' % map[state]
	write_once(sfp_select, map[state])
	set_led_mode(state)
	if restart_net:
		time.sleep(cmd_safety_sleep)
		os.system(cmd_net_res)


def oneshot():
	init()
	f = open(os.path.join(gpio_dir(sfpdet_pin), 'value'), 'r')
	state_last = int(f.read().strip())
	do_switch(state_last, False)


def run():
	global state_last

	def fdet_changed():
		global state_last
		fdet.seek(0)
		state = int(fdet.read().strip())
		if state != state_last:
			state_last = state
			do_switch(state)

	def set_led():
		global state_last

		flos.seek(0)
		fflt.seek(0)
		los = int(flos.read().strip())
		flt = int(fflt.read().strip())

		set_led_mode(state_last)

		if los or flt:
			set_led_brightness(False)
		else:
			set_led_brightness(True)

	def flos_changed():
		set_led()

	def fflt_changed():
		set_led()

	init()

	fdet = open(os.path.join(gpio_dir(sfpdet_pin), 'value'), 'r')
	flos = open(os.path.join(gpio_dir(sfplos_pin), 'value'), 'r')
	fflt = open(os.path.join(gpio_dir(sfpflt_pin), 'value'), 'r')

	po = select.epoll()
	po.register(fdet, select.EPOLLPRI)
	po.register(flos, select.EPOLLPRI)
	po.register(fflt, select.EPOLLPRI)

	state_last = int(fdet.read().strip())
	do_switch(state_last)
	set_led()

	# main loop
	while 1:
		events = po.poll(60000)
		for e in events:
			ef = e[0] # event file descriptor
			time.sleep(cmd_safety_sleep)
			if ef == fdet.fileno():
				fdet_changed()
			elif ef == flos.fileno():
				flos_changed()
			elif ef == fflt.fileno():
				fflt_changed()
			else:
				raise Exception("Unknown FD. Can not happen.")


def create_daemon():
	try:
		pid = os.fork()
		if pid > 0:
			print 'PID: %d' % pid
			os._exit(0)

	except OSError, error:
		print 'Unable to fork. Error: %d (%s)' % (error.errno, error.strerror)
		os._exit(1)

	run()

def help():
	print """sfpswitch.py daemon for Turris Omnia

--oneshot : set the PHY and restart network, then exit
--nodaemon : run in foreground
NO PARAM : daemonize and wait for PHY change
"""

def main():
	if len(sys.argv) > 1:
		if sys.argv[1] == '--oneshot':
			oneshot()
		elif sys.argv[1] == '--nodaemon':
			run()
		elif sys.argv[1] == '--help':
			help()
		else:
			print "Unknown option: %s" % sys.argv[1]
			help()
	else:
		create_daemon()

if __name__ == '__main__':
	main()

