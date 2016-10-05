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
	echo "$(basename $0) [-b] [-o <file> | -O <file>] [module1[ module2[...]]]"
	echo "	-b		run in background"
	echo "	-o <file>	print output to a file"
	echo "	-O <file>	print output to a directory module per file"
	echo
	echo modules:
	module_help
}

module_run() {
	local module="$1"
	if [ -n "$OUTPUT_DIRECTORY" ] ; then
		./modules/"$module".module run 2>&1 | tail -n "$MAX_LINES_PER_MODULE" >> "$OUTPUT_DIRECTORY.preparing/$module".out.preparing
		mv "$OUTPUT_DIRECTORY.preparing/$module".out.preparing "$OUTPUT_DIRECTORY.preparing/$module".out
	elif [ -n "$OUTPUT_FILE" ] ; then
		printf "############## %s\n" $module >> "$OUTPUT_FILE".preparing
		./modules/"$module".module run 2>&1 | tail -n "$MAX_LINES_PER_MODULE" >> "$OUTPUT_FILE".preparing
		printf "************** %s\n" $module >> "$OUTPUT_FILE".preparing
	else
		printf "############## %s\n" $module
		./modules/"$module".module run 2>&1 | tail -n "$MAX_LINES_PER_MODULE"
		printf "************** %s\n" $module
	fi
}

if [ "$1" = "-b" ] ; then
	shift
	"$0" "$@" >/dev/null 2>&1 &
	exit 0
fi

if [ "$1" = "-o" ] ; then
	shift
	OUTPUT_FILE="$1"
	# clean the last output files
	rm -rf "$OUTPUT_FILE"
	rm -rf "$OUTPUT_FILE".preparing
	shift
fi

if [ "$1" = "-O" ] ; then
	shift
	OUTPUT_DIRECTORY="$1"
	rm -rf "$OUTPUT_DIRECTORY" "$OUTPUT_DIRECTORY.preparing"
	mkdir -p "$OUTPUT_DIRECTORY.preparing" || ( echo "Failed to created the log directory" && exit 1 )
	shift
fi

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

# rename the output directory when finished
if [ -n "$OUTPUT_DIRECTORY" ] ; then
	mv "$OUTPUT_DIRECTORY".preparing "$OUTPUT_DIRECTORY"
else
	# rename the output file when finished
	if [ -n "$OUTPUT_FILE" ] ; then
		mv "$OUTPUT_FILE".preparing "$OUTPUT_FILE"
	fi
fi
