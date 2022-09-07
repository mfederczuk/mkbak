#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

# $1: message (optional)
# stderr: the given message or just a newline if the argument was omitted
function log() {
	local message

	case $# in
		(0)
			message=''
			;;
		(1)
			message="$1"

			if [ -z "$message" ]; then
				errlog 'argument must not be empty'
				return 9
			fi
			;;
		(*)
			errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	readonly message

	printf '%s\n' "$message" >&2
}
readonly -f log

#  $1: message
# or
#  $1: '--no-origin'
#  $2: message
# stderr: the error message
function errlog() {
	if (($# == 0)); then
		errlog 'missing argument: [--no-origin] <message>'
		return 3
	fi

	local prefix message

	if [ "$1" = '--no-origin' ]; then
		case $# in
			(1)
				errlog 'missing argument: <message>'
				return 3
				;;
			(2)
				prefix=''

				message="$2"
				if [ -z "$message" ]; then
					errlog 'argument 2: must not be empty'
					return 9
				fi
				;;
			(*)
				errlog "too many arguments: $(($# - 2))"
				return 4
				;;
		esac
	else
		if (($# > 1)); then
			errlog "too many arguments: $(($# - 1))"
			return 4
		fi

		if ((${#FUNCNAME[@]} > 2)); then
			prefix="${FUNCNAME[1]}"
		else
			prefix="$(argv0 && printf x)"
			prefix="${prefix%x}"
		fi
		prefix+=': '

		message="$1"
		if [ -z "$message" ]; then
			errlog 'argument must not be empty'
			return 9
		fi
	fi

	readonly message prefix

	log "${prefix}${message}"
}
readonly -f errlog


# $1: command name
# exit code: 0 if the given command exists, nonzero otherwise
function command_exists() {
	local command_name

	case $# in
		(0)
			errlog 'missing argument: <command>'
			return 3
			;;
		(1)
			command_name="$1"
			;;
		(*)
			errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	readonly command_name

	command -v "$command_name" > '/dev/null'
}
readonly -f command_exists


# Ensures that the given path is "safe", which means that it doesn't start with a dash character.
# $1: path
# stdout: the safe path
function safepath() {
	local path

	case $# in
		(0)
			errlog 'missing argument: <path>'
			return 3
			;;
		(1)
			path="$1"
			;;
		(*)
			errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	readonly path

	if [[ "$1" =~ ^'-' ]]; then
		printf './%s' "$path"
	else
		printf '%s' "$path"
	fi
}
readonly -f safepath

# stdout: the current working directory
# <https://github.com/koalaman/shellcheck/issues/2492>
# shellcheck disable=2120
function get_cwd() {
	if (($# > 0)); then
		errlog "too many arguments: $#"
		return 4
	fi

	# pwd(1p) always prints an additional newline, so we need to trim it
	# now, normally command substition like this $(cmd) automatically trims trailing newline, but it trims *all*
	# trailing newlines, meaning that if the CWD ends with any amount newlines, these would also be trimmed, so we need
	# to disable this automatic newline trimming, and then manually trim the additional newline from pwd(1p)

	local cwd
	cwd="$(pwd -L && printf x)" # this prevents the automatic newline trimming because with this, the newlines aren't
	cwd="${cwd%$'\nx'}"         # the trailing characters anymore, the 'x' is
	printf '%s' "$cwd"
}
readonly -f get_cwd

# Reads the contents of a symbolic link.
#
# $1: path of the symlink
# stdout: contents of the given symlink
function readlink_portable() {
	local path

	case $# in
		(0)
			errlog 'missing argument: <symlink>'
			return 3
			;;
		(1)
			path="$1"
			;;
		(*)
			errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	if [ -z "$path" ]; then
		errlog 'argument must not be empty'
		return 9
	fi

	if [ ! -L "$path" ]; then
		errlog "$path: not a symlink"
		return 26
	fi

	path="$(safepath "$1" && printf x)"
	path="${path%x}"
	readonly path

	# this is rather complicated because POSIX doesn't specifiy a proper utiltiy to read a symlink's target, only `ls`
	# is capable of it

	local ls_out
	ls_out="$(LC_ALL=POSIX LC_CTYPE=POSIX LC_TIME=POSIX ls -dn "$path" && printf x)"
	ls_out="${ls_out%$'\nx'}"

	# removing <file mode>, <number of links>, <owner name>, <group name>, <size> and <date and time> (where both
	# <owner name> and <group name> are their associated numeric values because of the '-n' option given to `ls`)
	if [[ ! "$ls_out" =~ ^([^[:space:]$' \t']+[[:space:]$' \t']+[0-9]+' '+[0-9]+' '+[0-9]+' '+[0-9]+' '+[A-Za-z]+' '+[0-9]+' '+([0-9]+':'[0-9]+|[0-9]+)' '+"$path -> ") ]]; then
		errlog 'emergency stop: unexpected output of ls'
		return 123
	fi
	ls_out="${ls_out#"${BASH_REMATCH[1]}"}"

	printf '%s' "$ls_out"
}
readonly -f readlink_portable

# Normalizes a path - which means:
#  * if it isn't already, makes the path absolute by inserting the current working directory plus a slash at the start
#    of the path
#  * '.' components are removed
#  * '..' components and the component behind them are removed
#  * multiple slashes are squeezed to one
#  * trailing slashes are removed
#
# This function only operates on the given path string and won't query the filesystem for any other information.
# (excluding the current working directory) e.g.: it's not an error to treat non-directories components as directories,
# symlinks arent't followed, etc.
#
# If the given path is empty, nothing is written to stdout. (i.e.: the same empty path is returned)
#
# $1: path
# stdout: the normalized path, or nothing if the given path is empty
function normalize_path() {
	local path

	case $# in
		(0)
			errlog 'missing arguments: <path>'
			return 3
			;;
		(1)
			path="$1"
			;;
		(*)
			errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	if [ -z "$path" ]; then
		return 0
	fi

	# ensure that the path is absolute
	if [[ ! "$path" =~ ^'/' ]]; then
		local cwd
		cwd="$(get_cwd && printf x)"
		cwd="${cwd%x}"

		path="$cwd/$path"

		unset -v cwd
	fi

	# ensure that the path ends with a slash so that we don't a special case of the end of the loop
	path+='/'

	local -a normalized_path
	normalized_path=''

	local component
	component=''

	local -i i
	for ((i = 0; i < ${#path}; ++i)); do
		local ch
		ch="${path:i:1}"

		if [ "$ch" != '/' ]; then
			component+="$ch"
		else
			if [ "$component" = '..' ]; then
				if [[ "$normalized_path" =~ ('/'[^'/']+)$ ]]; then
					normalized_path="${normalized_path%"${BASH_REMATCH[1]}"}"
				fi
			elif [ "$component" != '.' ] && [ -n "$component" ]; then
				normalized_path+="/$component"
			fi

			component=''
		fi

		unset -v ch
	done
	unset -v i \
	         component

	readonly normalized_path

	printf '%s' "${normalized_path:-/}"
}
readonly -f normalize_path


# stdout: the name of the script (may or may not have an extra trailing newline)
# <https://github.com/koalaman/shellcheck/issues/2492>
# shellcheck disable=2120
function argv0() {
	if (($# > 0)); then
		errlog "too many arguments: $#"
		return 4
	fi

	if [[ ! "$0" =~ ^'/' ]]; then
		printf '%s' "$0"
		return
	fi

	local path
	path="$(safepath "$0" && printf x)"
	path="${path%x}"
	readonly path

	local basename
	basename="$(basename "$path" && printf x)"
	basename="${basename%$'\nx'}"
	readonly basename

	printf '%s' "$basename"
}
readonly -f argv0


# $1: message
# $2: default answer, must be 'default=yes' or 'default=no'
# exit code: zero if the answer was yes, 32 if the answer was no
function prompt_yes_no() {
	local message default_is_yes

	case $# in
		(0)
			errlog 'missing arguments: <message> default=(yes|no)'
			return 3
			;;
		(1)
			errlog 'missing argument: default=(yes|no)'
			return 3
			;;
		(2)
			message="$1"

			if [[ ! "$2" =~ ^'default='('yes'|'no')$ ]]; then
				errlog "$2: does not match: /^default=(yes|no)$/"
				return 12
			fi

			if [ "$2" = 'default=yes' ]; then
				default_is_yes=true
			else
				default_is_yes=false
			fi
			;;
		(*)
			errlog "too many arguments: $(($# - 2))"
			return 4
			;;
	esac

	readonly default_is_yes message


	local y n
	if $default_is_yes; then
		y='Y'
		n='n'
	else
		y='y'
		n='N'
	fi

	printf '%s [%s/%s] ' "$message" "$y" "$n" >&2

	unset -v n y


	local ans
	read -r ans

	if [ -z "$ans" ]; then
		if $default_is_yes; then
			ans='y'
		else
			ans='n'
		fi
	fi

	if [[ "$ans" =~ ^['yY'] ]]; then
		return 0
	fi

	return 32
}
readonly -f prompt_yes_no
