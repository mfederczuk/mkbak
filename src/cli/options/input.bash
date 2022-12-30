#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

# either 'default:', 'file:...' or 'stdin:'
declare bak_pathnames_input_source='default:'

function cli_opt_input() {
	local -r origin="$1"
	local pathname="$3"

	case "$pathname" in
		('')
			errlog "$origin: argument must not be empty"
			return 9
			;;
		('-')
			bak_pathnames_input_source='stdin:'
			;;
		(*)
			pathname="$(normalize_pathname "$pathname" && printf x)"
			pathname="${pathname%x}"

			#ignorenext
			# shellcheck disable=2034
			bak_pathnames_input_source="file:$pathname"
			;;
	esac
}
readonly -f cli_opt_input

cli_options_define '-i' '--input' 'arg_required:file' \
                   'low_prio' cli_opt_input
