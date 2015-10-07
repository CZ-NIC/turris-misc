#!/usr/bin/env python2

import hpfeeds
import json
import csv
import datetime
import os
import sys

hpc = hpfeeds.new(
    'hpfriends.honeycloud.net',
    20000,
    'username',
    'password'
)
print "Connected to {0}".format(hpc.brokername)

hpf_channel = 'turris'
dict = {}


if os.path.isfile('honey.json'):
    with open('honey.json', 'r') as json_file_r:
        dict = json.load(json_file_r)
    json_file_r.close()


new_dict = dict.copy()
date_ago = datetime.datetime.utcnow() - datetime.timedelta(hours=10)


for key in dict:
    date_string = key.split(',')[1].split('+')[0]
    date = datetime.datetime.strptime(date_string, '%Y-%m-%d %H:%M:%S')
    if date_ago > date:
        del new_dict[key]


if not os.path.isfile('honey.csv'):
    sys.stderr.write('file honey.csv not found\n')
    hpc.stop()
    print "Disconnected"
    exit()


with open('honey.csv', 'r') as f:
    reader = csv.reader(f)
    for row in reader:
        date_string = row[2].split('+')[0]
        date = datetime.datetime.strptime(date_string, '%Y-%m-%d %H:%M:%S')

        record = row[0] + "," + row[2]
        if date_ago < date and not record in new_dict:
            new_dict[record] = 1

            data = {
                "remote": row[0]
            }
            hpc.publish(hpf_channel, json.dumps(data))
f.close()


hpc.stop()
print "Disconnected"


json_file_w = open('honey.json', 'w')
json.dump(new_dict, json_file_w)
json_file_w.close()
