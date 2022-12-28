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
	printf 'GNU Bash is required to execute this script\n' >&2
	exit 1
fi

set -o pipefail

#include utils.bash
#ignorenext
. utils.bash

#include version.bash
#ignorenext
. version.bash

#include cli/cli.bash
#ignorenext
. cli/cli.bash

if [ -z "${HOME-}" ]; then
	errlog 'HOME environment variable must not be empty'
	exit 48
fi

if ! starts_with "$HOME" '/'; then
	errlog "$HOME: HOME environment variable must be an absolute path"
	exit 49
fi

HOME="$(normalize_pathname "$HOME" && printf x)"
HOME="${HOME%x}"
readonly HOME
export HOME

#include config.bash
#ignorenext
. config.bash
