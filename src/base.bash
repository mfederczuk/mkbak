#!/bin/bash
# -*- sh -*-
# vim: set syntax=sh
# code: language=shellscript

# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0

case "$-" in
	(*'i'*)
		if \command test -n "${BASH_VERSION-}"; then
			# using `eval` here in case a non-Bash shell tries to parse this branch even if the condition is false
			\command eval "\\command printf '%s: ' \"\${BASH_SOURCE[0]}\" >&2"
		fi

		\command printf 'script was called interactively\n' >&2
		return 124
		;;
esac

set -o errexit
set -o nounset

# enabling POSIX-compliant behavior for GNU programs
export POSIXLY_CORRECT=yes POSIX_ME_HARDER=yes

# Throughout the codebase, the following snippet (or a similiar one) can be found:
#
#         var="$(some_command && printf x)"
#         var="${var%x}"
#
# This is because command substition (this thing --> `$(some_command)`) automatically trims *all* trailing newlines.
# By printing additional non-newline characters (we use the single character 'x' for it) after the command, this
# behavior is avoided because then the newline characters are not anymore the trailing characters.
# Afterwards, the extra trailing 'x' character needs to be removed, which is safe to do so because
# variable substition (this thing --> `${var}`) does not have this trailing-newline-trimming behavior.
#
# A lot of commands (like `basename`, `pwd`, ...) also print an additional newline along the actual data we're
# interested in (e.g.: pathnames printed to stdout), which is why sometimes the second line will look like this:
#
#         var="${var%$'\nx'}"
#
# Which removes the extra newline, but preserves any newlines that belong to the actual data we're interested in.

if [ -z "${BASH_VERSION-}" ]; then
	if [ "${0#/}" = "$0" ]; then # checks whether or not $0 does not start with a slash
		argv0="$0"
	else
		# Rationale as to why only the basename of $0 is used for $argv0 if $0 is an absolute pathname:
		# When an executable file with a shebang is executed via the exec family of functions (which is how shells
		# invoke programs), then the absolute pathname of that file is passed to
		# the (in the shebang defined) interpreter program.
		# So when mkbak is invoked in a shell like this:
		#
		#         $ sh mkbak
		#
		# Then $0 will be an absolute pathname (e.g.: /usr/bin/local/mkbak), but the user doesn't expect error logs to
		# show that absolute pathname --- only the program name --- which is why only the basename is used.

		argv0="$(basename -- "$0" && printf x)"
		argv0="${argv0%"$(printf '\nx')"}"
	fi
	readonly argv0

	printf '%s: GNU Bash is required to execute this script\n' "$argv0" >&2
	exit 1
fi

set -o pipefail
shopt -s nullglob

#include utils.bash
#ignorenext
. utils.bash

#include version.bash
#ignorenext
. version.bash

#include exc.bash
#ignorenext
. exc.bash

#include cli/cli.bash
#ignorenext
. cli/cli.bash

#include env.bash
#ignorenext
. env.bash

#include config.bash
#ignorenext
. config.bash

#include main.bash
#ignorenext
. main.bash
