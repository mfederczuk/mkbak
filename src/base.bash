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

if [[ ! "$HOME" =~ ^'/' ]]; then
	errlog "$HOME: HOME environment variable must be an absolute path"
	exit 49
fi

HOME="$(normalize_path "$HOME")"
readonly HOME
export HOME

#include config.bash
#ignorenext
. config.bash
