#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

declare xdg_config_home
if [ -n "${XDG_CONFIG_HOME-}" ]; then
	xdg_config_home="$XDG_CONFIG_HOME"
	xdg_config_home="$(normalize_pathname "$xdg_config_home" && printf x)"
	xdg_config_home="${xdg_config_home%x}"
else
	xdg_config_home="$HOME/.config"
fi
readonly xdg_config_home

readonly config_dir_path="$xdg_config_home/mkbak"
readonly config_file_path="$config_dir_path/mkbak.conf"

readonly config_key_pattern='[a-z_]+'

# $1: config key
# $2: (optional) fallback value
# stdout: the value of the config key, or the given fallback value if the config key doesn't exist / couldn't be read
function config_read_value() {
	local requested_key fallback_value

	case $# in
		(0)
			errlog 'missing argument: <key> [<fallback_value>]'
			return 3
			;;
		(1)
			requested_key="$1"
			fallback_value=''
			;;
		(2)
			requested_key="$1"

			fallback_value="$2"
			if [ -z "$fallback_value" ]; then
				errlog 'argument 2: must not be empty'
				return 9
			fi
			;;
		(*)
			errlog "too many arguments: $(($# - 2))"
			return 4
			;;
	esac

	readonly fallback_value requested_key

	if [ -z "$requested_key" ]; then
		if [ -z "$fallback_value" ]; then
			errlog 'argument must not be empty'
		else
			errlog 'argument 1: must not be empty'
		fi

		return 9
	fi

	if [[ ! "$requested_key" =~ ^$config_key_pattern$ ]]; then
		errlog "$requested_key: does not match: /^$config_key_pattern\$/"
		return 12
	fi

	if [ ! -f "$config_file_path" ] || [ ! -r "$config_file_path" ]; then
		printf '%s' "$fallback_value"
		return
	fi

	local line
	while read -r line; do
		if [[ "$line" =~ ^(.*?)'#'.*$ ]]; then
			line="${BASH_REMATCH[1]}"

			# strips trailing whitespace
			if [[ "$line" =~ ^([^[:space:]]+([[:space:]]+[^[:space:]]+)*)[[:space:]]+$ ]]; then
				line="${BASH_REMATCH[1]}"
			fi
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
	done < "$config_file_path"
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
			errlog 'missing arguments: <key> <fallback_value>'
			return 3
			;;
		(1)
			errlog 'missing argument: <fallback_value>'
			return 3
			;;
		(2)
			requested_key="$1"
			fallback_value="$2"
			;;
		(*)
			errlog "too many arguments: $(($# - 2))"
			return 4
			;;
	esac

	readonly fallback_value requested_key

	if [ -z "$requested_key" ]; then
		errlog 'argument 1: must not be empty'
		return 9
	fi
	if [[ ! "$requested_key" =~ ^$config_key_pattern$ ]]; then
		errlog "$requested_key: does not match: /^$config_key_pattern\$/"
		return 12
	fi

	if [ -z "$fallback_value" ]; then
		errlog 'argument 2: must not be empty'
		return 9
	fi
	if [[ ! "$fallback_value" =~ ^$integer_pattern$ ]]; then
		errlog "$fallback_value: not an integer"
		return 10
	fi

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


readonly config_key_default_input_file_path='default_input_file_path'

declare default_input_file_path
default_input_file_path=$(config_read_value "$config_key_default_input_file_path")

if [ -n "$default_input_file_path" ]; then
	if [[ "$default_input_file_path" =~ ^'~'('/'.*)?$ ]]; then
		default_input_file_path="${HOME}${BASH_REMATCH[1]}"
	elif [[ ! "$default_input_file_path" =~ ^'/' ]]; then
		errlog "$default_input_file_path: $config_key_default_input_file_path config key must either start with a tilde (~) or be an absolute path"
		exit 79
	fi
fi

#ignorenext
# shellcheck disable=2034
readonly default_input_file_path
