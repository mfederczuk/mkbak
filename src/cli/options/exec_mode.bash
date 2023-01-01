#ignore
# Copyright (c) 2023 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

readonly enum_exec_mode_normal='exec_mode_normal' \
         enum_exec_mode_list_transients='exec_mode_list_transients' \
         enum_exec_mode_clear_transients='exec_mode_clear_transients'

declare exec_mode="$enum_exec_mode_normal"


function cli_opt_list_transients() {
	exec_mode="$enum_exec_mode_list_transients"
}
readonly -f cli_opt_list_transients

cli_options_define '' '--list-transients' 'no_arg' \
                   'low_prio' cli_opt_list_transients


function cli_opt_clear_transients() {
	#ignorenext
	# shellcheck disable=2034
	exec_mode="$enum_exec_mode_clear_transients"
}
readonly -f cli_opt_clear_transients

cli_options_define '' '--clear-transients' 'no_arg' \
                   'low_prio' cli_opt_clear_transients
