#!/bin/bash
# -*- sh -*-
# vim: set syntax=sh
# code: language=shellscript

# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0

case "$-" in
	(*'i'*)
		if [ -n "${BASH_VERSION-}" ]; then
			# using `eval` here in case a non-Bash shell tries to parse a branch even if the condition is false
			\eval "\\printf '%s: ' \"\${BASH_SOURCE[0]}\" >&2"
		fi

		\echo 'script was called interactively' >&2
		return 124
		;;
esac

set -o errexit
set -o nounset
set -o pipefail

# enabling POSIX-compliant behavior for GNU programs
export POSIXLY_CORRECT=yes POSIX_ME_HARDER=yes

if [ -z "${BASH_VERSION-}" ]; then
	echo 'GNU Bash is required to execute this script' >&2
	exit 1
fi

#include utils.bash
#ignorenext
. utils.bash

#include version.bash
#ignorenext
. version.bash
