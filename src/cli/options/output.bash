#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

# either 'file:...' or 'stdout:'
#ignorenext
# shellcheck disable=2034
declare output_archive_target
output_archive_target="file:$(date +'%Y-%M-%d').tar.gz"

function cli_opt_output() {
	local -r origin="$1"
	local pathname="$3"

	case "$pathname" in
		('')
			errlog "$origin: argument must not be empty"
			return 9
			;;
		('-')
			output_archive_target='stdout:'
			;;
		(*)
			pathname="$(normalize_pathname "$pathname" && printf x)"
			pathname="${pathname%x}"

			output_archive_target="file:$pathname"
			;;
	esac
}
readonly -f cli_opt_output

cli_options_define '-o' '--output' 'arg_required:archive' \
                   'low_prio' cli_opt_output
