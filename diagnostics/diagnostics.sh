#!/bin/sh

MAX_LINES_PER_MODULE=${MAX_LINES_PER_MODULE:-10000}

# read modules and load help
modules=""
for mod_file in $(dirname $0)/modules/*.module ; do
	# load help
	. "$mod_file"
	module=$(basename "$mod_file" .module)
	modules="$modules $module"

	# remove first and last newline
	newline="
"
	help=${help##$newline}
	help=${help%%$newline}

	# store variable
	eval help_${module}="\${help}"
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
		eval echo \"\$help_$module\" | sed 's/^/    /'
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
	sh "$(dirname $0)"/modules/"$module".module run 2>&1 | tail -n "$MAX_LINES_PER_MODULE"
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
