#ignore
# Copyright (c) 2023 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

declare -a copy_destination_pathnames=()

function cli_opt_copy() {
	local -r origin="$1"
	local pathname="$3"

	if [ -z "$pathname" ]; then
		errlog "$origin: argument must not be empty"
		return 9
	fi

	pathname="$(normalize_pathname "$pathname" && printf x)"
	pathname="${pathname%x}"

	readonly pathname

	# avoid adding the same pathname twice
	local copy_destination_pathname
	for copy_destination_pathname in "${copy_destination_pathnames[@]}"; do
		if [ "$copy_destination_pathname" = "$pathname" ]; then
			return 0
		fi
	done

	copy_destination_pathnames+=("$pathname")
}
readonly -f cli_opt_copy

cli_options_define '-p' '--copy' 'arg_required:dest' \
                   'low_prio' cli_opt_copy
