#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

#region logging

# Prints the given message to standard error.
#
# $1: message (optional)
# stderr: the given message with an appended newline or just a newline if the argument was omitted
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

# Prints the given message to standard error, along with the "origin" of the message.
#
# Outside of functions, the origin is the name of the program (see the function `argv0`).
# Inside functions, the origin is the name of that function.
#
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

#endregion

#region string utils

# Tests whether or not a string starts with another substring.
#
# $1: base string
# $2: substring
# exit code: 0 if the given base string starts with the given substring, nonzero otherwise
function starts_with() {
	local base_string substring

	case $# in
		(0)
			errlog 'missing arguments: <base_string> <substring>'
			return 3
			;;
		(1)
			errlog 'missing argument: <substring>'
			return 3
			;;
		(2)
			base_string="$1"
			substring="$2"
			;;
		(*)
			errlog "too many arguments: $(($# - 2))"
			return 4
			;;
	esac

	readonly substring base_string


	if [[ "$base_string" =~ ^"$substring" ]]; then
		return 0
	fi

	return 32
}
readonly -f starts_with

# Repeatedly replaces the given search substring with the given replace substring in the given base string, until
# no more instances of the search substring exist.
#
# If the search substring is contained in the replace substring, then this functions fails because otherwise it would
# cause an infinite loop.
#
# $1: base string
# $2: search substring
# $3: replace substring
# stdout: the base string, with all search substrings replaced by the replace substring
function repeat_replace() {
	local base_string search_substring replace_substring

	case $# in
		(0)
			errlog 'missing arguments: <base_string> <search_substring> <replace_substring>'
			return 3
			;;
		(1)
			errlog 'missing arguments: <search_substring> <replace_substring>'
			return 3
			;;
		(2)
			errlog 'missing argument: <replace_substring>'
			return 3
			;;
		(3)
			base_string="$1"
			search_substring="$2"
			replace_substring="$3"
			;;
		(*)
			errlog "too many arguments: $(($# - 3))"
			return 4
			;;
	esac

	readonly replace_substring search_substring base_string


	# shellcheck disable=2076
	if [[ "$replace_substring" =~ "$search_substring" ]]; then
		errlog "refusing to continue because the search substring ($search_substring) is contained in the replace substring ($replace_substring)"
		return 13
	fi


	local replaced_string
	replaced_string="$base_string"

	local repeat
	repeat=true

	while $repeat; do
		local old_replaced_string
		old_replaced_string="$replaced_string"

		replaced_string="${replaced_string//"$search_substring"/"$replace_substring"}"

		if [ "$replaced_string" != "$old_replaced_string" ]; then
			repeat=true
		else
			repeat=false
		fi

		unset -v old_replaced_string
	done

	unset -v repeat

	readonly replaced_string


	printf '%s' "$replaced_string"
}
readonly -f repeat_replace

# Squeezes any and all substrings, which consist of two or more instances of the same given character, into
# a single instance of that character in the given base string.
#
# $1: base string
# $2: character to squeeze
# stdout: the base string, with the given character squeezed
function squeeze() {
	local base_string char

	case $# in
		(0)
			errlog 'missing arguments: <base_string> <char>'
			return 3
			;;
		(1)
			errlog 'missing argument: <char>'
			return 3
			;;
		(2)
			case "$2" in
				('')
					errlog 'argument 2: must not be empty'
					return 9
					;;
				(?)
					# ok
					;;
				(??*)
					errlog "$2: invalid argument: must not be more than one character long"
					return 7
					;;
			esac

			base_string="$1"
			char="$2"
			;;
		(*)
			errlog "too many arguments: $(($# - 2))"
			return 4
			;;
	esac

	readonly char base_string


	repeat_replace "$base_string" "${char}${char}" "$char"
}
readonly -f squeeze

#endregion


# Tests whether or not the given command exists.
#
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


#region pathname utils

# Ensures that the given path is "safe", which means that it doesn't start with a dash character, and writes it to
# standard output.
#
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

# Writes the current working directory to standard output.
#
# stdout: the current working directory
# <https://github.com/koalaman/shellcheck/issues/2492>
# shellcheck disable=2120
function get_cwd() {
	if (($# > 0)); then
		errlog "too many arguments: $#"
		return 4
	fi

	local cwd
	cwd="$(pwd -L && printf x)"
	cwd="${cwd%$'\nx'}"
	printf '%s' "$cwd"
}
readonly -f get_cwd

# Reads the contents of a symbolic link and writes it to standard output.
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

# Normalizes the given pathname and writes it to the standard output.
#
# Normalization is done by squeezing multiple slashes into one and by removing all unnecessary '.' pathname components.
#
# If the given pathname is empty, nothing / the same empty pathname is written to the standard output.
#
# $1: the pathname to normalize
# stdout: the normalized pathname, or nothing if the given argument is empty
function normalize_pathname() {
	local pathname

	case $# in
		(0)
			errlog 'missing argument: <pathname>'
			return 3
			;;
		(1)
			pathname="$1"
			;;
		(*)
			errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	readonly pathname


	if [ -z "$pathname" ]; then
		return 0
	fi


	local normalized_pathname
	normalized_pathname="$pathname"

	normalized_pathname="$(squeeze "$normalized_pathname" '/' && printf x)"
	normalized_pathname="${normalized_pathname%x}"

	normalized_pathname="$(repeat_replace "$normalized_pathname" '/./' '/' && printf x)"
	normalized_pathname="${normalized_pathname%x}"

	if [[ "$normalized_pathname" =~ ^'./'(.+)$ ]]; then
		normalized_pathname="${BASH_REMATCH[1]}"
	fi

	if [[ "$normalized_pathname" =~ ^(.*'/')'.'$ ]]; then
		normalized_pathname="${BASH_REMATCH[1]}"
	fi

	readonly normalized_pathname


	printf '%s' "$normalized_pathname"
}
readonly -f normalize_pathname

#endregion


# Writes the basename or path of this script file to standard output.
#
# If $0 is an absolute path, only the basename of that path is written, otherwise $0 is written without change.
# Rationale: When an executable file with a shebang is executed via the exec family of functions (i.e.: how shells
# invoke programs) the absolute path of that file is passed to the (in the shebang defined) interpreter program.
#
# stdout: the name of this script file
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


# Prints a given message to standard error and then prompts the user for a boolean yes/no answer.
# The given message should end with a question mark but should not contain any trailing whitespace or an "input hint"
# that most of the time takes a form of "(y/n)", "[Y/n]" or "[y/N]" as it will be added automatically.
#
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
