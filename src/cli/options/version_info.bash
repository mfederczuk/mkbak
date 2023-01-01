#ignore
# Copyright (c) 2023 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

function cli_opt_version_info() {
	local version_info_message
	version_info_message="$(cat <<EOF
#include version_info.in.txt
EOF
)"
	readonly version_info_message

	log "$version_info_message"
}
readonly -f cli_opt_version_info

cli_options_define '-V' '--version' 'no_arg' \
                   'high_prio' cli_opt_version_info
