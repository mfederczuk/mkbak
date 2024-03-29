#ignore
# Copyright (c) 2023 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

function usage_errlog() {
	local message

	case $# in
		(0)
			internal_errlog 'missing argument: <message>'
			return 3
			;;
		(1)
			if [ -z "$1" ]; then
				internal_errlog 'argument must not be empty'
				return 9
			fi

			message="$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	readonly message


	#ignorenext
	# $argv0 is also used in 'usage.in.txt'
	local argv0
	argv0="$(get_argv0 && printf x)"
	argv0="${argv0%x}"
	readonly argv0


	local usage
	usage="$(cat <<EOF
#include usage.in.txt
EOF
)"
	readonly usage


	errlog "$message"
	log "$usage"
}
readonly -f usage_errlog

#include options.bash
#ignorenext
. options.bash

declare -a bak_pathnames=()

declare -a cli_option_low_prio_handles=()
declare -a cli_option_low_prio_origins=()
declare -a cli_option_low_prio_args=()

declare cli_first_invalid_opt=''

declare cli_option_high_prio_handle=''
declare cli_option_high_prio_origin
declare cli_option_high_prio_arg='none:'

declare -a cli_args=("$@")
declare -i cli_arg_i
declare cli_process_opts=true

for ((cli_arg_i = 0; cli_arg_i < $#; ++cli_arg_i)); do
	declare arg="${cli_args[cli_arg_i]}"

	if $cli_process_opts; then
		if [ "$arg" = '--' ]; then
			cli_process_opts=false
			continue
		fi

		if [[ "$arg" =~ ^'--'([^'=']+)('='(.*))?$ ]]; then
			declare opt_id="${BASH_REMATCH[1]}"

			declare opt_handle
			opt_handle="$(cli_options_find_by_long_id "$opt_id")"

			if [ -n "$opt_handle" ]; then
				declare opt_arg='none:'
				if [ -n "${BASH_REMATCH[2]}" ]; then
					opt_arg="present:${BASH_REMATCH[3]}"
				fi

				if [ "$opt_arg" = 'none:' ] &&
				   cli_options_option_requires_arg "$opt_handle" &&
				   (((cli_arg_i + 1) < $#)); then

					((++cli_arg_i))
					opt_arg="present:${cli_args[cli_arg_i]}"
				fi

				if cli_options_option_is_high_prio "$opt_handle"; then
					if [ -z "$cli_option_high_prio_handle" ]; then
						cli_option_high_prio_handle="$opt_handle"
						cli_option_high_prio_origin="--$opt_id"
						cli_option_high_prio_arg="$opt_arg"
					fi
				else
					cli_option_low_prio_handles+=("$opt_handle")
					cli_option_low_prio_origins+=("--$opt_id")
					cli_option_low_prio_args+=("$opt_arg")
				fi

				unset -v opt_arg
			elif [ -z "$cli_first_invalid_opt" ]; then
				cli_first_invalid_opt="--$opt_id"
			fi

			unset -v opt_handle opt_id

			continue
		fi

		if [[ "$arg" =~ ^'-'(.+)$ ]]; then
			declare opt_chars="${BASH_REMATCH[1]}"

			declare -i j
			for ((j = 0; j < ${#opt_chars}; ++j)); do
				declare opt_char="${opt_chars:j:1}"

				declare opt_handle
				opt_handle="$(cli_options_find_by_short_char "$opt_char")"

				if [ -n "$opt_handle" ]; then
					declare opt_arg='none:'
					if cli_options_option_requires_arg "$opt_handle"; then
						if (((j + 1) < ${#opt_chars})); then
							opt_arg="present:${opt_chars:j + 1}"
							j=${#opt_chars}
						elif (((cli_arg_i + 1) < $#)); then
							((++cli_arg_i))
							opt_arg="present:${cli_args[cli_arg_i]}"
						fi
					fi

					if cli_options_option_is_high_prio "$opt_handle"; then
						if [ -z "$cli_option_high_prio_handle" ]; then
							cli_option_high_prio_handle="$opt_handle"
							cli_option_high_prio_origin="-$opt_char"
							cli_option_high_prio_arg="$opt_arg"
						fi
					else
						cli_option_low_prio_handles+=("$opt_handle")
						cli_option_low_prio_origins+=("-$opt_char")
						cli_option_low_prio_args+=("$opt_arg")
					fi

					unset -v opt_arg
				elif [ -z "$cli_first_invalid_opt" ]; then
					cli_first_invalid_opt="-$opt_char"
				fi

				unset -v opt_handle opt_char
			done

			unset -v j opt_chars

			continue
		fi
	fi

	declare pathname
	pathname="$(normalize_pathname "$arg" && printf x)"
	pathname="${pathname%x}"

	bak_pathnames+=("$pathname")

	unset -v pathname
	unset -v arg
done

unset -v cli_process_opts \
         cli_arg_i cli_args


if [ -n "$cli_option_high_prio_handle" ]; then
	declare -a args_to_pass=()

	if [[ "$cli_option_high_prio_arg" =~ ^'present:'(.*)$ ]]; then
		args_to_pass+=("${BASH_REMATCH[1]}")
	fi

	cli_options_execute "$cli_option_high_prio_handle" "$cli_option_high_prio_origin" "${args_to_pass[@]}"
	exit
fi
unset -v cli_option_high_prio_arg \
         cli_option_high_prio_origin \
         cli_option_high_prio_handle


if [ -n "$cli_first_invalid_opt" ]; then
	usage_errlog "$cli_first_invalid_opt: invalid option"
	exit 5
fi
unset -v cli_first_invalid_opt


declare -i i
for ((i = 0; i < ${#cli_option_low_prio_handles[@]}; ++i)); do
	declare -a args_to_pass=()

	if [[ "${cli_option_low_prio_args[i]}" =~ ^'present:'(.*)$ ]]; then
		args_to_pass+=("${BASH_REMATCH[1]}")
	fi

	cli_options_execute "${cli_option_low_prio_handles[i]}" "${cli_option_low_prio_origins[i]}" "${args_to_pass[@]}"

	unset -v args_to_pass
done
unset -v i \
         cli_option_low_prio_args \
         cli_option_low_prio_origins \
         cli_option_low_prio_handles


declare -i i
for ((i = 0; i < ${#bak_pathnames[@]}; ++i)); do
	declare bak_pathname
	bak_pathname="${bak_pathnames[i]}"

	if [ -z "$bak_pathname" ]; then
		if ((${#bak_pathnames[@]} == 1)); then
			errlog 'argument must not be empty'
		else
			errlog "argument $((i + 1)): must not empty"
		fi
		exit 9
	fi

	if ! starts_with "$bak_pathname" '/'; then
		errlog "$bak_pathname: must be an absolute path"
		#ignorenext
		# shellcheck disable=2154,2086
		exit $exc_usage_argument_must_be_absolute_pathname
	fi

	unset -v bak_pathname
done
unset -v i
