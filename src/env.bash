#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

if [ -z "${HOME-}" ]; then
	errlog 'HOME environment variable must not be unset or empty'
	#ignorenext
	# shellcheck disable=2154,2086
	exit $exc_error_env_var_must_not_be_unset_or_empty
fi

if ! starts_with "$HOME" '/'; then
	errlog "$HOME: HOME environment variable must be an absolute path"
	#ignorenext
	# shellcheck disable=2154,2086
	exit $exc_error_env_var_must_be_absolute_pathname
fi

HOME="$(normalize_pathname "$HOME" && printf x)"
HOME="${HOME%x}"
readonly HOME
export HOME


declare -A var_names_with_default_values
var_names_with_default_values=(
	[XDG_DATA_HOME]="$HOME/.local/share"
	[XDG_CONFIG_HOME]="$HOME/.config"
	[XDG_STATE_HOME]="$HOME/.local/state"
	[XDG_CACHE_HOME]="$HOME/.cache"
)

declare var_name
for var_name in "${!var_names_with_default_values[@]}"; do
	declare pathname
	eval "pathname=\"\${$var_name-}\""

	if [ -n "$pathname" ] && ! starts_with "$pathname" '/'; then
		errlog "$pathname: $var_name environment variable must be an absolute path"
		#ignorenext
		# shellcheck disable=2086
		exit $exc_error_env_var_must_be_absolute_pathname
	fi

	if [ -z "$pathname" ]; then
		pathname="${var_names_with_default_values["$var_name"]}"
	fi

	pathname="$(normalize_pathname "$pathname" && printf x)"
	pathname="${pathname%x}"

	eval "$var_name=\"\$pathname\""

	eval "readonly $var_name"
	eval "export $var_name"

	unset -v pathname
done
unset -v var_name

unset -v var_names_with_default_values
