#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

#ignorenext
# shellcheck disable=2034
declare include_user_crontab=true


function cli_opt_crontab() {
	include_user_crontab=true
}

cli_options_define '-n' '--crontab' 'no_arg' \
                   'low_prio' cli_opt_crontab


function cli_opt_no_crontab() {
	include_user_crontab=false
}
readonly -f cli_opt_no_crontab

cli_options_define '-N' '--no-crontab' 'no_arg' \
                   'low_prio' cli_opt_no_crontab
