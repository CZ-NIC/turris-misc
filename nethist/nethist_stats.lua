#!/usr/bin/env lua

--[[
Copyright 2014, CZ.NIC z.s.p.o. (http://www.nic.cz/)

This file is part of NUCI configuration server.

NUCI is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

NUCI is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with NUCI.  If not, see <http://www.gnu.org/licenses/>.
]]

local HIST_FILE = "/tmp/nethist";
local STATS_FILE = "/tmp/nethist.stats";

-- Init all variables to default (empty) values
local function stats_init()
	local stats = {};

	stats['temp_board_min'] = 1/0;
	stats['temp_board_max'] = 0;
	stats['temp_board_avg'] = 0;
	stats['temp_board_sum'] = 0;
	stats['temp_board_samples'] = 0;
	stats['temp_cpu_min'] = 1/0;
	stats['temp_cpu_max'] = 0;
	stats['temp_cpu_avg'] = 0;
	stats['temp_cpu_sum'] = 0;
	stats['temp_cpu_samples'] = 0;
	stats['fs_min'] = 1/0;
	stats['fs_max'] = 0;
	stats['fs_avg'] = 0;
	stats['fs_sum'] = 0;
	stats['fs_samples'] = 0;
	stats['mem_min'] = 1/0;
	stats['mem_max'] = 0;
	stats['mem_avg'] = 0;
	stats['mem_sum'] = 0;
	stats['mem_samples'] = 0;
	stats['load_min'] = 1/0;
	stats['load_max'] = 0;
	stats['load_avg'] = 0;
	stats['load_sum'] = 0;
	stats['load_samples'] = 0;
	stats['last_timestamp'] = 1;

	return stats;
end

local function stats_load(file)
	local stats = {};

	for line in file:lines() do
		local key, value = line:match('([^%s]+)%s*[=]%s*(%d+%.?%d*)');
		-- OK, I really hope that this will not have side effect.
		-- The main idea is that the empty keys are comment lines.
		if key then
			stats[key] = tonumber(value);
		end
	end

	return stats;
end

local function stats_store(data, file)
	for key, value in pairs(data) do
		file:write(key .. " = " .. value .."\n");
	end
end

-- Get items in line as array
local function parse_nethist_line(line)
	local items = {};
	local i = 1;
	line = line .. ',';
	for item in line:gmatch('([^,]*)[,]') do
		items[i] = item;
		i = i + 1;
	end

	return items;
end

local function stats_update(stats, file)
	local items;
	for line in file:lines() do
		items = parse_nethist_line(line);
		if (tonumber(items[1]) > stats['last_timestamp']) then
			if items[2] == "cpu" and items[3] ~= "0" then
				local val = tonumber(items[3]);
				if val < stats['load_min'] then stats['load_min'] = val; end;
				if val > stats['load_max'] then stats['load_max'] = val; end;
				stats['load_sum'] = stats['load_sum'] + val;
				stats['load_samples'] = stats['load_samples'] + 1;
			elseif items[2] == "fs" and items[3] ~= "0" and items[4] ~= "0" then
				local val = tonumber(items[4]);
				if val < stats['fs_min'] then stats['fs_min'] = val; end;
				if val > stats['fs_max'] then stats['fs_max'] = val; end;
				stats['fs_sum'] = stats['fs_sum'] + val;
				stats['fs_samples'] = stats['fs_samples'] + 1;
			elseif items[2] == "memory" and items[3] ~= "0" and items[4] ~= "0" then
				local val = tonumber(items[4]);
				if val < stats['mem_min'] then stats['mem_min'] = val; end;
				if val > stats['mem_max'] then stats['mem_max'] = val; end;
				stats['mem_sum'] = stats['mem_sum'] + val;
				stats['mem_samples'] = stats['mem_samples'] + 1;
			elseif items[2] == "temperature" and items[3] ~= "0" and items[4] ~= "0" then
				local val = tonumber(items[3]); -- Board column
				if val < stats['temp_board_min'] then stats['temp_board_min'] = val; end;
				if val > stats['temp_board_max'] then stats['temp_board_max'] = val; end;
				stats['temp_board_sum'] = stats['temp_board_sum'] + val;
				stats['temp_board_samples'] = stats['temp_board_samples'] + 1;
				val = tonumber(items[4]); -- CPU column
				if val < stats['temp_cpu_min'] then stats['temp_cpu_min'] = val; end;
				if val > stats['temp_cpu_max'] then stats['temp_cpu_max'] = val; end;
				stats['temp_cpu_sum'] = stats['temp_cpu_sum'] + val;
				stats['temp_cpu_samples'] = stats['temp_cpu_samples'] + 1;
			end
		end
	end

	stats['last_timestamp'] = tonumber(items[1]);

	-- Update averages
	stats['load_avg'] = stats['load_sum'] / stats['load_samples'];
	stats['fs_avg'] = stats['fs_sum'] / stats['fs_samples'];
	stats['mem_avg'] = stats['mem_sum'] / stats['mem_samples'];
	stats['temp_board_avg'] = stats['temp_board_sum'] / stats['temp_board_samples'];
	stats['temp_cpu_avg'] = stats['temp_cpu_sum'] / stats['temp_cpu_samples'];

	return stats;
end

function main()
	-- Check if exists nethist output, otherwise is nothing to do
	local nethist_file = io.open(HIST_FILE);
	if not nethist_file then
		io.stderr:write("Nethist file doesn't exists.");
		os.exit(1);
	end

	-- Get stats; from file or new and empty
	local stats;

	local stats_file = io.open(STATS_FILE);
	if stats_file then
		stats = stats_load(stats_file);
		stats_file:close();
	else
		stats = stats_init();
	end

	-- Compute new values
	stats = stats_update(stats, nethist_file);
	nethist_file:close();

	-- And store new snapshot
	local ofile = io.open(STATS_FILE, "w");
	if not ofile then
		io.stderr:write("Output file couldn't be open\n");
		os.exit(1);
	end

	stats_store(stats, ofile);
	ofile:close();

	os.exit(0);
end

main();
