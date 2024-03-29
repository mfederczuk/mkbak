#ignore
# Copyright (c) 2023 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

# either 'file:...' or 'stdout:'
declare output_archive_target
output_archive_target="file:$(date +'%Y-%m-%d').tar.gz"

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
		(*'/')
			errlog "$origin: $pathname: argument must not end with a slash"
			#ignorenext
			# shellcheck disable=2154,2086
			return $exc_usage_argument_must_not_end_with_slash
			;;
		(*)
			pathname="$(normalize_pathname "$pathname" && printf x)"
			pathname="${pathname%x}"

			local basename
			basename="$(basename -- "$pathname" && printf x)"
			basename="${basename%$'\nx'}"

			if [[ ! "$basename" =~ .+('.tar.gz'|'.tgz')$ ]]; then
				if [[ "$basename" =~ ^('.tar.gz'|'.tgz')$ ]]; then
					errlog "$origin: $pathname: filename without prefix '.tar.gz'/'.tgz' must not be empty"
				else
					errlog "$origin: $pathname: filename must end with '.tar.gz' and '.tgz'"
				fi

				#ignorenext
				# shellcheck disable=2154,2086
				return $exc_usage_output_filename_must_be_non_empty_gzipped_tarball
			fi

			unset -v basename

			#ignorenext
			# shellcheck disable=2034
			output_archive_target="file:$pathname"
			;;
	esac
}
readonly -f cli_opt_output

cli_options_define '-o' '--output' 'arg_required:archive' \
                   'low_prio' cli_opt_output
