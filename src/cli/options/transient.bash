#ignore
# Copyright (c) 2023 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

declare transient=false


function cli_opt_transient() {
	transient=true
}

cli_options_define '-t' '--transient' 'no_arg' \
                   'low_prio' cli_opt_transient


function cli_opt_no_transient() {
	#ignorenext
	# shellcheck disable=2034
	transient=false
}
readonly -f cli_opt_no_transient

cli_options_define '-T' '--no-transient' 'no_arg' \
                   'low_prio' cli_opt_no_transient
