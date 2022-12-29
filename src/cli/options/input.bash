#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

# either 'default:', 'file:...' or 'stdin:'
#ignorenext
# shellcheck disable=2034
declare bak_paths_input_source='default:'

function cli_opt_input() {
	local -r origin="$1"
	local path="$3"

	case "$path" in
		('')
			errlog "$origin: argument must not be empty"
			return 9
			;;
		('-')
			bak_paths_input_source='stdin:'
			;;
		(*)
			path="$(normalize_pathname "$path" && printf x)"
			path="${path%x}"

			bak_paths_input_source="file:$path"
			;;
	esac
}
readonly -f cli_opt_input

cli_options_define '-i' '--input' 'arg_required:file' \
                   'low_prio' cli_opt_input
