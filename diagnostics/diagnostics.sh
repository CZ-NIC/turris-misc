#!/bin/sh

MAX_LINES_PER_MODULE=${MAX_LINES_PER_MODULE:-10000}

# enter the script directory
cd "$(dirname $0)"

# read modules and load help
modules=""
for mod_file in modules/*.module ; do
	# load help
	. "$mod_file"
	module=$(basename "$mod_file" .module)
	modules="$modules $module"

done

is_in_list() {
	local list="$1"
	local item="$2"
	for element in $list ; do
		if [ "$item" = "$element" ] ; then
			return 0
		fi
	done
	return 1
}

module_help() {
	for module in $modules ; do
		echo '  '${module}
		./modules/"$module".module help | sed 's/^/    /'
		echo
	done
}

print_help() {
	echo "$(basename $0) [module1[ module2[...]]]"
	echo available modules:
	module_help
}

module_run() {
	local module="$1"
	printf "############## %s\n" $module
	./modules/"$module".module run 2>&1 | tail -n "$MAX_LINES_PER_MODULE"
	printf "************** %s\n" $module
}

if [ "$1" = help ] ; then
	print_help
	exit 0
fi

# no parameters run all modules
if [ $# = 0 ] ; then
	modules_to_run=$modules
else
	modules_to_run=$@
fi

for module in $modules_to_run ; do
	if ! is_in_list "${modules}" "${module}" ; then
		printf "!!!!!!!!!!!!!! %s not found\n" $module
	else
		module_run "$module"
	fi
done
