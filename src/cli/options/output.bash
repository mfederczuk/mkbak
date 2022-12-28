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
	local path="$2"

	case "$path" in
		('')
			errlog --no-origin "$(argv0): $origin: argument must not be empty"
			return 9
			;;
		('-')
			output_archive_target='stdout:'
			;;
		(*)
			path="$(normalize_pathname "$path" && printf x)"
			path="${path%x}"

			output_archive_target="file:$path"
			;;
	esac
}
readonly -f cli_opt_output

cli_options_define '-o' '--output' 'arg_required:archive' \
                   'low_prio' cli_opt_output
