#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

declare config_dir_pathname
config_dir_pathname="$(normalize_pathname "$XDG_CONFIG_HOME/mkbak")"
readonly config_dir_pathname

declare config_file_pathname
config_file_pathname="$(normalize_pathname "$config_dir_pathname/mkbak.conf")"
readonly config_file_pathname


readonly config_key_pattern='[a-z_]+'

# $1: config key
# $2: (optional) fallback value
# stdout: the value of the config key, or the given fallback value if the config key doesn't exist / couldn't be read
function config_read_value() {
	local requested_key fallback_value

	case $# in
		(0)
			internal_errlog 'missing argument: <key> [<fallback_value>]'
			return 3
			;;
		(1)
			if [ -z "$1" ]; then
				internal_errlog 'argument: must not be empty'
				return 9
			fi

			requested_key="$1"
			fallback_value=''
			;;
		(2)
			if [ -z "$1" ]; then
				internal_errlog 'argument 1: must not be empty'
				return 9
			fi

			if [ -z "$2" ]; then
				internal_errlog 'argument 2: must not be empty'
				return 9
			fi

			requested_key="$1"
			fallback_value="$2"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 2))"
			return 4
			;;
	esac

	readonly fallback_value requested_key

	if [[ ! "$requested_key" =~ ^$config_key_pattern$ ]]; then
		internal_errlog "$requested_key: does not match: /^$config_key_pattern\$/"
		return 12
	fi


	if [ ! -f "$config_file_pathname" ] || [ ! -r "$config_file_pathname" ]; then
		printf '%s' "$fallback_value"
		return
	fi


	local line
	while read -r line; do
		if [[ "$line" =~ ^([^'#']*)'#' ]]; then
			line="$(trim_ws "${BASH_REMATCH[1]}")"
		fi

		local key value
		if [[ ! "$line" =~ ^(${config_key_pattern})[[:space:]]*'='[[:space:]]*(.*)$ ]]; then
			continue
		fi
		key="${BASH_REMATCH[1]}"
		value="${BASH_REMATCH[2]}"

		if [ "$key" = "$requested_key" ]; then
			printf '%s' "$value"
			return
		fi

		unset -v value key
	done < "$config_file_pathname"
	unset -v line

	printf '%s' "$fallback_value"
}
readonly -f config_read_value

readonly integer_pattern='[+-]?[0-9]+'

# $1: config key
# $2: fallback value
# stdout: the value of the config key, or the given fallback value if the config key is not an integer or
#         doesn't exist / couldn't be read
function config_read_integer() {
	local requested_key fallback_value

	case $# in
		(0)
			internal_errlog 'missing arguments: <key> <fallback_value>'
			return 3
			;;
		(1)
			internal_errlog 'missing argument: <fallback_value>'
			return 3
			;;
		(2)
			if [ -z "$1" ]; then
				internal_errlog 'argument 1: must not be empty'
				return 9
			fi
			if [[ ! "$1" =~ ^$config_key_pattern$ ]]; then
				internal_errlog "$1: does not match: /^$config_key_pattern\$/"
				return 12
			fi

			if [ -z "$2" ]; then
				internal_errlog 'argument 2: must not be empty'
				return 9
			fi
			if [[ ! "$2" =~ ^$integer_pattern$ ]]; then
				internal_errlog "$2: not an integer"
				return 10
			fi

			requested_key="$1"
			fallback_value="$2"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 2))"
			return 4
			;;
	esac

	readonly fallback_value requested_key


	local value
	value="$(config_read_value "$requested_key" "$fallback_value")"

	if [[ ! "$value" =~ ^$integer_pattern$ ]]; then
		value="$fallback_value"
	fi

	value="${value#+}"

	if [[ "$value" =~ ^('-'?)'0'+('0'|[1-9][0-9]*)$ ]]; then
		value="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
	fi

	value=$((value))

	readonly value

	printf '%s' "$value"
}
readonly -f config_read_integer


readonly config_key_default_input_file_pathname='default_input_file_path'

declare default_input_file_pathname
default_input_file_pathname=$(config_read_value "$config_key_default_input_file_pathname")

if [ -n "$default_input_file_pathname" ]; then
	if [[ "$default_input_file_pathname" =~ ^'~'('/'.*)?$ ]]; then
		default_input_file_pathname="${HOME}${BASH_REMATCH[1]}"
	elif [[ ! "$default_input_file_pathname" =~ ^'/' ]]; then
		errlog "$default_input_file_pathname: $config_key_default_input_file_pathname config key must either start with a tilde (~) or be an absolute path"
		exit 79
	fi
fi

readonly default_input_file_pathname
