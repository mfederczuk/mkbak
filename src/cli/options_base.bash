#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

declare -a _cli_options_short_chars=()
declare -a _cli_options_long_ids=()
declare -a _cli_options_arg_specs=()
declare -a _cli_options_prios=()
declare -a _cli_options_cmds=()

# $1: short character (must start with '-') or an empty string if the option doesn't have a short character
# $2: long identifier (must start with '--')
# $3: either 'no_arg', 'arg_required:<arg_name>' or 'arg_optional:<arg_name>'
# $4: either 'low_prio' or 'high_prio'
# $5: handling command; command to execute when the option is specified on the command line
function cli_options_define() {
	local short_char long_id arg_spec prio cmd

	case $# in
		(0)
			internal_errlog 'missing arguments: ( -<short_char> | "") --<long_id> <arg_spec> <priority> <command>'
			return 3
			;;
		(1)
			internal_errlog 'missing arguments: --<long_id> <arg_spec> <priority> <command>'
			return 3
			;;
		(2)
			internal_errlog 'missing arguments: <arg_spec> <priority> <command>'
			return 3
			;;
		(3)
			internal_errlog 'missing arguments: <priority> <command>'
			return 3
			;;
		(4)
			internal_errlog 'missing arguments: <command>'
			return 3
			;;
		(5)
			short_char="$1"
			long_id="$2"
			arg_spec="$3"
			prio="$4"
			cmd="$5"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 5))"
			return 4
			;;
	esac

	if [ -n "$short_char" ]; then
		if [[ "$short_char" =~ ^'-'(.)$ ]]; then
			short_char="${BASH_REMATCH[1]}"
		else
			internal_errlog "$short_char: does not match: /^-.$/"
			return 12
		fi
	fi
	readonly short_char

	if [[ "$long_id" =~ ^'--'([^'=']+)$ ]]; then
		long_id="${BASH_REMATCH[1]}"
	else
		internal_errlog "$long_id: does not match: /^--[^=]+$/"
		return 12
	fi
	readonly long_id

	case "$arg_spec" in
		('no_arg')
			arg_spec='none:'
			;;
		('arg_required:'?*)
			arg_spec="required:${arg_spec#arg_required:}"
			;;
		('arg_optional:'?*)
			arg_spec="optional:${arg_spec#arg_optional:}"
			;;
		(*)
			internal_errlog "$arg_spec: must be either 'no_arg', 'arg_required:<arg_name>' or 'arg_optional:<arg_name>'"
			return 13
			;;
	esac
	readonly arg_spec

	case "$prio" in
		('low_prio'|'high_prio')
			# ok
			;;
		(*)
			internal_errlog "$prio: must be either 'low_prio' or 'high_prio'"
			return 14
			;;
	esac
	readonly prio="${prio%_prio}"

	readonly cmd
	if [ -z "$cmd" ]; then
		internal_errlog 'argument 5: must not be empty'
		return 9
	fi
	if ! command_exists "$cmd"; then
		internal_errlog "$cmd: no such command"
		return 24
	fi


	_cli_options_short_chars+=("$short_char")
	_cli_options_long_ids+=("$long_id")
	_cli_options_arg_specs+=("$arg_spec")
	_cli_options_prios+=("$prio")
	_cli_options_cmds+=("$cmd")
}
readonly -f cli_options_define

# $1: short char to search for
# stdout: handle to access the options's details or nothing if no option was found
function cli_options_find_by_short_char() {
	local requested_char
	case $# in
		(0)
			internal_errlog 'missing argument: <short_char>'
			return 3
			;;
		(1)
			requested_char="$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac
	readonly requested_char

	if ((${#requested_char} != 1)); then
		internal_errlog "$requested_char: must be a single character"
		return 13
	fi

	local -i i
	for ((i = 0; i < ${#_cli_options_short_chars[@]}; ++i)); do
		if [ "${_cli_options_short_chars[i]}" = "$requested_char" ]; then
			printf '%d' "$i"
			exit 0
		fi
	done
}
readonly -f cli_options_find_by_short_char

# $1: long identifier to search for
# stdout: handle to access the options's details or nothing if no option was found
function cli_options_find_by_long_id() {
	local requested_id
	case $# in
		(0)
			internal_errlog 'missing argument: <long_identifier>'
			return 3
			;;
		(1)
			requested_id="$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac
	readonly requested_id

	if [ -z "$requested_id" ]; then
		internal_errlog 'argument must not be empty'
		return 9
	fi
	if [[ "$requested_id" =~ '=' ]]; then
		internal_errlog "$requested_id: must not contain a equals character ('=')"
		return 13
	fi

	local -i i
	for ((i = 0; i < ${#_cli_options_long_ids[@]}; ++i)); do
		if [ "${_cli_options_long_ids[i]}" = "$requested_id" ]; then
			printf '%d' "$i"
			exit 0
		fi
	done
}
readonly -f cli_options_find_by_long_id

function cli_options_is_handle_valid() {
	local handle
	case $# in
		(0)
			internal_errlog 'missing argument: <handle>'
			return 3
			;;
		(1)
			handle="$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac
	readonly handle

	[[ "$handle" =~ ^('0'|[1-9][0-9]*)$ ]]
}
readonly -f cli_options_is_handle_valid

# $1: option handle
# exit code: zero if the option requires an argument, nonzero otherwise or the option with the given handle exists
function cli_options_option_requires_arg() {
	local handle
	case $# in
		(0)
			internal_errlog 'missing argument: <handle>'
			return 3
			;;
		(1)
			handle="$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac
	readonly handle

	if [ -z "$handle" ]; then
		internal_errlog 'argument must not be empty'
		return 9
	fi
	if ! cli_options_is_handle_valid "$handle"; then
		internal_errlog 'given handle is not valid'
		return 13
	fi

	if ((handle >= ${#_cli_options_arg_specs[@]})); then
		return 32
	fi

	local -r arg_spec="${_cli_options_arg_specs[handle]}"

	case "$arg_spec" in
		('none:'|'optional:'*)
			return 33
			;;
		('required:'*)
			return 0
			;;
	esac
}
readonly -f cli_options_option_requires_arg

# $1: option handle
# exit code: zero if the option is high priority, nonzero otherwise or the option with the given handle exists
function cli_options_option_is_high_prio() {
	local handle
	case $# in
		(0)
			internal_errlog 'missing argument: <handle>'
			return 3
			;;
		(1)
			handle="$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac
	readonly handle

	if [ -z "$handle" ]; then
		internal_errlog 'argument must not be empty'
		return 9
	fi
	if ! cli_options_is_handle_valid "$handle"; then
		internal_errlog 'given handle is not valid'
		return 13
	fi

	if ((handle >= ${#_cli_options_prios[@]})); then
		return 32
	fi

	local -r prio="${_cli_options_prios[handle]}"

	test "$prio" = 'high' || return 33
}
readonly -f cli_options_option_is_high_prio

# $1: option handle
# $2: origin
# $@: arguments to pass to the option's handling command; must not be more than one
function cli_options_execute() {
	local handle origin
	local -a args_to_pass=()
	case $# in
		(0)
			internal_errlog 'missing arguments: <handle> <origin> [<arg>]'
			return 3
			;;
		(1)
			internal_errlog 'missing arguments: <origin> [<arg>]'
			return 3
			;;
		(3)
			args_to_pass+=("$3")
			;&
		(2)
			handle="$1"
			origin="$2"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 3))"
			return 4
			;;
	esac
	readonly args_to_pass origin handle

	if [ -z "$handle" ]; then
		internal_errlog 'argument 1: must not be empty'
		return 9
	fi
	if ! cli_options_is_handle_valid "$handle"; then
		internal_errlog 'given handle is not valid'
		return 13
	fi

	if [ -z "$origin" ]; then
		internal_errlog 'argument 2: must not be empty'
		return 9
	fi
	if [[ ! "$origin" =~ ^('-'.|'--'[^'=']+)$ ]]; then
		internal_errlog "$origin: does not match /^(-.|--[^=]+)$/"
		return 12
	fi

	if ((handle >= ${#_cli_options_arg_specs[@]} || handle >= ${#_cli_options_cmds[@]})); then
		internal_errlog 'option with the given handle does not exist'
		return 48
	fi

	local -r arg_spec="${_cli_options_arg_specs[handle]}"

	case "$arg_spec" in
		('none:')
			if ((${#args_to_pass[@]} > 0)); then
				usage_errlog "$origin: too many arguments: ${#args_to_pass[@]}"
				return 4
			fi
			;;
		('required:'?*)
			if ((${#args_to_pass[@]} == 0)); then
				usage_errlog "$origin: missing argument: <${arg_spec#required:}>"
				return 3
			fi
			;;
		('optional:'?*)
			# ok
			;;
		(*)
			internal_errlog "emergency stop: arg_spec of option with handle of '$handle' is invalid ($arg_spec)"
			return 123
			;;
	esac

	local argv0
	argv0="$(get_argv0 && printf x)"
	argv0="${argv0%x}"
	readonly argv0

	local -r cmd="${_cli_options_cmds[handle]}"

	"$cmd" "$origin" "$argv0" "${args_to_pass[@]}"
}
readonly -f cli_options_execute
