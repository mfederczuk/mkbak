#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0

# template for a doc comment:

#v#
 # SYNOPSIS:
 #     TODO
 #
 # DESCRIPTION:
 #     TODO
 #
 # OPTIONS:
 #     TODO
 #
 # OPERANDS:
 #     TODO
 #
 # STDIN:
 #     TODO
 #
 # STDOUT:
 #     TODO
 #
 # STDERR:
 #     Diagnostic messages in case of an error.
 #
 # EXIT STATUS:
 #      0  Success.
 #
 #     TODO
 #
 #     >0  Another error occurred.
#^#

#end-ignore

#region logging

#v#
 # SYNOPSIS:
 #     log [<message>]
 #
 # DESCRIPTION:
 #     Writes the operand <message> to standard error, followed by a newline character.
 #     If the operand <message> is not given, then only the newline charcacter is written.
 #
 # OPERANDS:
 #     <message>  The string to write to standard error.
 #                If this operand is given, it must not be empty.
 #
 # STDERR:
 #     Diagnostic messages in case of an error or --- on success --- the operand <message> (or nothing if it wasn't
 #     given), along with a newline character in the following format:
 #
 #             "%s\n", <message>
 #
 # EXIT STATUS:
 #      0  Success.
 #
 #      4  Too many operands are given.
 #
 #      9  The operand <message> is an empty string.
 #
 #     >0  Another error occurred.
#^#
function log() {
	local message

	case $# in
		(0)
			message=''
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


	printf '%s\n' "$message" >&2
}
readonly -f log

#v#
 # SYNOPSIS:
 #     internal_errlog <message>
 #
 # DESCRIPTION:
 #     Writes a diagnostic message, prefixed by the name of the program (see the function `get_argv0`) and the name of
 #     the function this function was called from, to standard error.
 #
 # OPERANDS:
 #     <message>  The string to write to standard error, it must not be empty.
 #
 # STDERR:
 #     Diagnostic messages in case of an error or --- on success --- the name of the program, the name of the function
 #     this function was called from and the operand <message> in the following format:
 #
 #             "%s: %s: %s\n", <argv0>, <outer_function_name>, <message>
 #
 # EXIT STATUS:
 #      0  Success.
 #
 #      3  The operand <message> is not given.
 #
 #      4  Too many operands are given.
 #
 #      9  The operand <message> is an empty string.
 #
 #     48  This function was not executed from within another function.
 #
 #     >0  Another error occurred.
#^#
function internal_errlog() {
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


	if ((${#FUNCNAME[@]} <= 2)); then
		# shellcheck disable=2016
		internal_errlog 'The function `internal_errlog` must be called from within another function'
		return 48
	fi

	local argv0
	argv0="$(get_argv0 && printf x)"
	argv0="${argv0%x}"
	readonly argv0

	local outer_func_name
	outer_func_name="${FUNCNAME[1]}"
	readonly outer_func_name


	log "$argv0: $outer_func_name: $message"
}
readonly -f internal_errlog

#v#
 # SYNOPSIS:
 #     errlog <message>
 #
 # DESCRIPTION:
 #     Writes a diagnostic message, prefixed by the name of the program (see the function `get_argv0`), to
 #     standard error.
 #
 # OPERANDS:
 #     <message>  The string to write to standard error, it must not be empty.
 #
 # STDERR:
 #     Diagnostic messages in case of an error or --- on success --- the name of the program and the operand <message>
 #     in the following format:
 #
 #             "%s: %s\n", <argv0>, <message>
 #
 # EXIT STATUS:
 #      0  Success.
 #
 #      3  The operand <message> is not given.
 #
 #      4  Too many operands are given.
 #
 #      9  The operand <message> is an empty string.
 #
 #     >0  Another error occurred.
#^#
function errlog() {
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


	local argv0
	argv0="$(get_argv0 && printf x)"
	argv0="${argv0%x}"
	readonly argv0

	log "$argv0: $message"
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
			internal_errlog 'missing arguments: <base_string> <substring>'
			return 3
			;;
		(1)
			internal_errlog 'missing argument: <substring>'
			return 3
			;;
		(2)
			base_string="$1"
			substring="$2"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 2))"
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
			internal_errlog 'missing arguments: <base_string> <search_substring> <replace_substring>'
			return 3
			;;
		(1)
			internal_errlog 'missing arguments: <search_substring> <replace_substring>'
			return 3
			;;
		(2)
			internal_errlog 'missing argument: <replace_substring>'
			return 3
			;;
		(3)
			base_string="$1"
			search_substring="$2"
			replace_substring="$3"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 3))"
			return 4
			;;
	esac

	readonly replace_substring search_substring base_string


	# shellcheck disable=2076
	if [[ "$replace_substring" =~ "$search_substring" ]]; then
		internal_errlog "refusing to continue because the search substring ($search_substring) is contained in the replace substring ($replace_substring)"
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
			internal_errlog 'missing arguments: <base_string> <char>'
			return 3
			;;
		(1)
			internal_errlog 'missing argument: <char>'
			return 3
			;;
		(2)
			case "$2" in
				('')
					internal_errlog 'argument 2: must not be empty'
					return 9
					;;
				(?)
					# ok
					;;
				(??*)
					internal_errlog "$2: invalid argument: must not be more than one character long"
					return 7
					;;
			esac

			base_string="$1"
			char="$2"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 2))"
			return 4
			;;
	esac

	readonly char base_string


	repeat_replace "$base_string" "${char}${char}" "$char"
}
readonly -f squeeze

#endregion


#v#
 # SYNOPSIS:
 #     command_exists <command_name>
 #
 # DESCRIPTION:
 #     Indicates whether or not the command with the name of the operand <command_name> exists.
 #
 # OPERANDS:
 #     <command_name>  The name of a command.
 #
 # STDERR:
 #     Diagnostic messages in case of an error.
 #
 # EXIT STATUS:
 #      0  Success, the command exists.
 #
 #      3  The operand <command_name> is not given.
 #
 #      4  Too many operands are given.
 #
 #     >0  The command does not exist or another error occurred.
#^#
function command_exists() {
	local command_name

	case $# in
		(0)
			internal_errlog 'missing argument: <command_name>'
			return 3
			;;
		(1)
			if [ -z "$1" ]; then
				internal_errlog 'argument must not be empty'
				return 9
			fi

			command_name="$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	readonly command_name


	command -v "$command_name" > '/dev/null'
}
readonly -f command_exists


#region pathname utils

# Writes the current working directory to standard output.
#
# stdout: the current working directory
# <https://github.com/koalaman/shellcheck/issues/2492>
# shellcheck disable=2120
function get_cwd() {
	if (($# > 0)); then
		internal_errlog "too many arguments: $#"
		return 4
	fi


	local cwd
	cwd="$(pwd -L && printf x)"
	cwd="${cwd%$'\nx'}"
	readonly cwd

	printf '%s' "$cwd"
}
readonly -f get_cwd

# Reads the contents of a symbolic link and writes it to standard output.
#
# $1: pathname of the symlink
# stdout: contents of the given symlink
function readlink_portable() {
	local pathname

	case $# in
		(0)
			internal_errlog 'missing argument: <symlink>'
			return 3
			;;
		(1)
			if [ -z "$1" ]; then
				internal_errlog 'argument must not be empty'
				return 9
			fi

			pathname="$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	readonly pathname


	if [ ! -L "$pathname" ]; then
		internal_errlog "$pathname: not a symlink"
		return 26
	fi


	# this is rather complicated because POSIX doesn't specifiy a proper utiltiy to read a symlink's target, only `ls`
	# is capable of it

	local ls_out

	ls_out="$(LC_ALL=POSIX LC_CTYPE=POSIX LC_TIME=POSIX ls -dn -- "$pathname" && printf x)"
	ls_out="${ls_out%$'\nx'}"

	# removing <file mode>, <number of links>, <owner name>, <group name>, <size> and <date and time> (where both
	# <owner name> and <group name> are their associated numeric values because of the '-n' option given to `ls`)
	if [[ ! "$ls_out" =~ ^([^[:space:]$' \t']+[[:space:]$' \t']+[0-9]+' '+[0-9]+' '+[0-9]+' '+[0-9]+' '+[A-Za-z]+' '+[0-9]+' '+([0-9]+':'[0-9]+|[0-9]+)' '+"$pathname -> ") ]]; then
		internal_errlog 'emergency stop: unexpected output of ls'
		return 123
	fi
	ls_out="${ls_out#"${BASH_REMATCH[1]}"}"

	readonly ls_out


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
			internal_errlog 'missing argument: <pathname>'
			return 3
			;;
		(1)
			pathname="$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
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


# Writes the basename or relative pathname of this script file to the standard output.
#
# If $0 is an absolute pathname, only the basename of that pathname is written to the standard output,
# otherwise (if $0 is a relative pathname) $0 will be normalized (see the function `normalize_path`) and then written to
# the standard output.
#
# Rationale as to why only the basename of $0 is written to the standard output if it is an absolute pathname:
# When an executable file with a shebang is executed via the exec family of functions (which is how shells
# invoke programs), then the absolute pathname of that file is passed to
# the (in the shebang defined) interpreter program.
# So when mkbak is invoked in a shell simply like this:
#
#         $ mkbak
#
# Then $0 will be an absolute pathname (e.g.: /usr/bin/local/mkbak), but the user doesn't expect error logs to show
# that absolute pathname --- only the program name --- which is why only the basename is written.
#
# stdout: the name of this script file
# <https://github.com/koalaman/shellcheck/issues/2492>
# shellcheck disable=2120
function get_argv0() {
	if (($# > 0)); then
		internal_errlog "too many arguments: $#"
		return 4
	fi


	if starts_with "$0" '/'; then
		local basename
		basename="$(basename -- "$0" && printf x)"
		basename="${basename%$'\nx'}"
		readonly basename

		printf '%s' "$basename"

		return
	fi


	local starts_with_dot
	starts_with_dot=false

	if starts_with "$0" './'; then
		starts_with_dot=true
	fi

	readonly starts_with_dot


	local pathname

	pathname="$(normalize_pathname "$0" && printf x)"
	pathname="${pathname%x}"

	if $starts_with_dot; then
		pathname="./$pathname"
	fi

	readonly pathname


	printf '%s' "$pathname"
}
readonly -f get_argv0


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
			internal_errlog 'missing arguments: <message> default=(yes|no)'
			return 3
			;;
		(1)
			internal_errlog 'missing argument: default=(yes|no)'
			return 3
			;;
		(2)
			message="$1"

			case "$2" in
				('default=yes') default_is_yes=true  ;;
				('default=no')  default_is_yes=false ;;
				(*)
					internal_errlog "$2: invalid argument: must be either 'default=yes' or 'default=yes'"
					return 7
					;;
			esac
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 2))"
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
