#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

function cli_opt_help() {
	local help_message
	help_message="$(cat <<EOF
#include help.in.txt
EOF
)"
	readonly help_message

	log "$help_message"
}
readonly -f cli_opt_help

cli_options_define '-h' '--help' 'no_arg' \
                   'high_prio' cli_opt_help
