#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

#ignorenext
# shellcheck disable=2034
declare -a copy_destination_paths=()

function cli_opt_copy() {
	local -r origin="$1"
	local path="$2"

	if [ -z "$path" ]; then
		errlog --no-origin "$(argv0): $origin: argument must not be empty"
		return 9
	fi

	local force_dir
	force_dir=false
	if [[ "$path" =~ '/'$ ]]; then
		force_dir=true
	fi

	path="$(normalize_pathname "$path" && printf x)"
	path="${path%x}"

	if $force_dir; then
		path+='/'
	fi

	readonly path

	# avoid adding the same path twice
	local copy_destination_path
	for copy_destination_path in "${copy_destination_paths[@]}"; do
		if [ "$copy_destination_path" = "$path" ]; then
			return 0
		fi
	done

	copy_destination_paths+=("$path")
}
readonly -f cli_opt_copy

cli_options_define '-p' '--copy' 'arg_required:dest' \
                   'low_prio' cli_opt_copy
