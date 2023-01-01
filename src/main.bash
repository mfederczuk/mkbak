#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0

# declare these variables so that during development, ShellCheck doesn't issue warnings

declare -i exc_feedback_prompt_abort

declare -i exc_error_gnu_tar_required \
           exc_error_input_file_malformed \
           exc_error_no_bak_pathnames

declare bak_pathnames_input_source
declare output_archive_target
declare include_user_crontab
declare -a copy_destination_pathnames
declare -a bak_pathnames

#end-ignore

#region checking commands

if ! command_exists tar; then
	errlog 'tar: program missing'
	exit 27
fi

declare tar_version_info
if tar_version_info="$(tar --version)"; then
	tar_version_info="$(head -n1 <<< "$tar_version_info")"
else
	tar_version_info=''
fi
if [[ ! "$tar_version_info" =~ ^'tar (GNU tar)' ]]; then
	errlog "GNU tar is required"
	exit $exc_error_gnu_tar_required
fi
unset -v tar_version_info


if $include_user_crontab; then
	if ! command_exists crontab; then
		errlog 'crontab: program missing'
		exit 27
	fi
fi

#endregion

#region checking & reading input file

# only take the configured default input file pathname when no pathnames have been given on the command line and
# no input file has been specified
if ((${#bak_pathnames[@]} == 0)) && [ "$bak_pathnames_input_source" = 'default:' ]; then
	if [ -z "$default_input_file_pathname" ]; then
		#ignorenext
		# shellcheck disable=2154
		errlog "$config_key_default_input_file_pathname config key must not be missing or empty"
		exit 80
	fi

	bak_pathnames_input_source="file:$default_input_file_pathname"
fi

function read_pathnames_from_input() {
	local input_source

	case $# in
		(0)
			input_source='stdin:'
			;;
		(1)
			if [ -z "$1" ]; then
				internal_errlog "argument must not be empty"
				return 9
			fi

			input_source="file:$1"
			;;
		(*)
			internal_errlog "too many arguments: $(($# - 1))"
			return 4
			;;
	esac

	readonly input_source


	local input_source_name

	case "$input_source" in
		('file:'?*) input_source_name="${input_source#file:}" ;;
		('stdin:')  input_source_name='<stdin>'               ;;
	esac

	readonly input_source_name


	local -i row
	row=0

	local line
	while read -r line; do
		((++row))

		if [[ "$line" =~ ^([^'#']*)'#' ]]; then
			line="$(trim_ws "${BASH_REMATCH[1]}")"
		fi

		if [ -z "$line" ]; then
			continue
		fi

		case "$line" in
			('~'*)
				local substring_after_tilde
				substring_after_tilde="${line#\~}"

				if [ -n "$substring_after_tilde" ] && ! starts_with "$substring_after_tilde" '/'; then
					errlog "$input_source_name:$row: $line: a leading tilde ('~') must be followed by either nothing or a slash"
					exit $exc_error_input_file_malformed
				fi

				line="${HOME}${substring_after_tilde}"

				unset -v substring_after_tilde
				;;
			('$'*)
				if [[ ! "$line" =~ ^'$'([A-Za-z_][A-Za-z0-9_]*)([^A-Za-z0-9_].*)?$ ]]; then
					errlog "$input_source_name:$row: $line: a leading dollar ('$') must be followed by a valid variable name"
					exit $exc_error_input_file_malformed
				fi


				local var_name substring_after_var_name
				var_name="${BASH_REMATCH[1]}"
				substring_after_var_name="${BASH_REMATCH[2]}"

				if [[ ! "$var_name" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
					errlog "$input_source_name:$row: $var_name: variable names must not contain lowercase letters"
					exit $exc_error_input_file_malformed
				fi

				if [ -n "$substring_after_var_name" ] && ! starts_with "$substring_after_var_name" '/'; then
					errlog "$input_source_name:$row: $line: a leading variable must be followed by either nothing or a slash"
					exit $exc_error_input_file_malformed
				fi


				local var_value
				eval "var_value=\"\${$var_name-}\""

				if [ -z "$var_value" ]; then
					errlog "$input_source_name:$row: $var_name: environment variable must not be unset or empty"
					exit $exc_error_input_file_malformed
				fi

				if ! starts_with "$var_value" '/'; then
					errlog "$input_source_name:$row: $var_value: value of environment variable $var_name must be an absolute path"
					exit $exc_error_input_file_malformed
				fi


				line="${var_value}${substring_after_var_name}"


				unset -v var_value \
				         substring_after_var_name var_name
				;;
		esac

		line="$(normalize_pathname "$line" && printf x)"
		line="${line%x}"

		if ! starts_with "$line" '/'; then
			errlog "$input_source_name:$row: $line: path must be absolute"
			exit $exc_error_input_file_malformed
		fi

		bak_pathnames+=("$line")
	done < <(case "$input_source" in
		         ('file:'?*) cat -- "${input_source#file:}" ;;
		         ('stdin:')  cat                            ;;
	         esac)
}
readonly -f read_pathnames_from_input

case "$bak_pathnames_input_source" in
	('file:'?*)
		declare bak_pathnames_input_file_pathname
		bak_pathnames_input_file_pathname="${bak_pathnames_input_source#file:}"

		declare result
		result="$(resolve_pathname "$bak_pathnames_input_file_pathname" && printf x)"
		result="${result%x}"

		case "$result" in
			('directory:'?*)
				errlog "${result#directory:}: not a file"
				exit 26
				;;
			('EACCESS:'?*)
				errlog "${result#EACCESS:}: permission denied: search permissions missing"
				exit 77
				;;
			('ENOENT:'*)
				errlog "${result#ENOENT:}: no such file or directory"
				exit 24
				;;
			('ENOTDIR:'?*)
				errlog "${result#ENOTDIR:}: not a directory"
				exit 26
				;;
		esac

		unset -v result

		if [ ! -e "$bak_pathnames_input_file_pathname" ]; then
			errlog "$bak_pathnames_input_file_pathname: no such file"
			exit 24
		fi

		if [ -d "$bak_pathnames_input_file_pathname" ]; then
			errlog "$bak_pathnames_input_file_pathname: not a file"
			exit 26
		fi

		if [ ! -r "$bak_pathnames_input_file_pathname" ]; then
			errlog "$bak_pathnames_input_file_pathname: permission denied: read permissions missing"
			exit 77
		fi

		read_pathnames_from_input "$bak_pathnames_input_file_pathname"

		unset -v bak_pathnames_input_file_pathname
		;;
	('stdin:')
		read_pathnames_from_input
		;;
	('default:')
		# nothing
		;;
	(*)
		errlog "emergency stop: wrong format for 'bak_pathnames_input_source' variable: $bak_pathnames_input_source"
		exit 123
		;;
esac

unset -v bak_pathnames_input_source

#endregion

declare user_was_prompted
user_was_prompted=false


declare -a missing_pathnames
missing_pathnames=()

declare bak_pathname
for bak_pathname in "${bak_pathnames[@]}"; do
	if [ -e "$bak_pathname" ]; then
		continue
	fi

	missing_pathnames+=("$bak_pathname")

	if [ -t 0 ]; then
		declare -i exc
		exc=0
		prompt_yes_no "The path '$bak_pathname' does not exist. Continue anyway?" default=no ||
			exc=$?

		user_was_prompted=true

		case $exc in
			(0)
				# continue
				;;
			(32)
				log 'Aborting.'
				exit $exc_feedback_prompt_abort
				;;
			(*)
				exit $exc
				;;
		esac

		unset -v exc
	fi
done
unset -v bak_pathname

readonly missing_pathnames

#region checking user crontab

if $include_user_crontab; then
	declare crontab_backup_file_pathname
	crontab_backup_file_pathname="$(normalize_pathname "$HOME/crontab_backup")"
	readonly crontab_backup_file_pathname

	declare result
	result="$(resolve_pathname "$crontab_backup_file_pathname")"

	case "$result" in
		('directory:'?*)
			errlog "${result#directory:}: not a file"
			exit 26
			;;
		('EACCESS:'?*)
			errlog "${result#EACCESS:}: permission denied: search permissions missing"
			exit 77
			;;
		('ENOENT:'*)
			errlog "${result#ENOENT:}: no such file or directory"
			exit 24
			;;
		('ENOTDIR:'?*)
			errlog "${result#ENOTDIR:}: not a directory"
			exit 26
			;;
	esac

	unset -v result

	if [ -e "$crontab_backup_file_pathname" ]; then
		if [ -d "$crontab_backup_file_pathname" ]; then
			errlog "$crontab_backup_file_pathname: not a file"
			exit 26
		fi

		if [ -t 0 ]; then
			declare -i exc
			exc=0
			prompt_yes_no "The file '$crontab_backup_file_pathname' already exists. Overwrite?" default=yes ||
				exc=$?

			user_was_prompted=true

			case $exc in
				(0)
					# continue
					;;
				(32)
					log 'Aborting.'
					exit $exc_feedback_prompt_abort
					;;
				(*)
					exit $exc
					;;
			esac

			unset -v exc
		fi
	fi

	declare crontab_backup_file_parent_dir_pathname
	crontab_backup_file_parent_dir_pathname="$(dirname -- "$crontab_backup_file_pathname" && printf x)"
	crontab_backup_file_parent_dir_pathname="${crontab_backup_file_parent_dir_pathname%$'\nx'}"

	if [ ! -w "$crontab_backup_file_parent_dir_pathname" ]; then
		errlog "$crontab_backup_file_parent_dir_pathname: permission denied: write permission missing"
		exit 77
	fi

	unset -v crontab_backup_file_parent_dir_pathname


	bak_pathnames+=("$crontab_backup_file_pathname")
fi

#endregion

if ((${#bak_pathnames[@]} == 0)); then
	errlog 'no paths to backup given'
	exit $exc_error_no_bak_pathnames
fi

#region checking output file

declare output_archive_file_pathname

case "$output_archive_target" in
	('file:'?*)
		output_archive_file_pathname="${output_archive_target#file:}"

		declare result
		result="$(resolve_pathname "$output_archive_file_pathname" && printf x)"
		result="${result%x}"

		case "$result" in
			('directory:'?*)
				errlog "${result#directory:}: not a file"
				exit 26
				;;
			('EACCESS:'?*)
				errlog "${result#EACCESS:}: permission denied: search permissions missing"
				exit 77
				;;
			('ENOENT:'*)
				errlog "${result#ENOENT:}: no such file or directory"
				exit 24
				;;
			('ENOTDIR:'?*)
				errlog "${result#ENOTDIR:}: not a directory"
				exit 26
				;;
		esac

		unset -v result

		if [ -e "$output_archive_file_pathname" ]; then
			if [ -d "$output_archive_file_pathname" ]; then
				errlog "$output_archive_file_pathname: not a file"
				exit 26
			fi

			if [ -t 0 ]; then
				declare -i exc
				exc=0
				prompt_yes_no "The file '$output_archive_file_pathname' already exists. Overwrite?" default=no ||
					exc=$?

				user_was_prompted=true

				case $exc in
					(0)
						# continue
						;;
					(32)
						log 'Aborting.'
						exit $exc_feedback_prompt_abort
						;;
					(*)
						exit $exc
						;;
				esac

				unset -v exc
			fi

			if [ ! -w "$output_archive_file_pathname" ]; then
				errlog "$output_archive_file_pathname: permission denied: write permission missing"
				exit 77
			fi
		else
			declare output_archive_parent_dir_pathname
			output_archive_parent_dir_pathname="$(dirname -- "$output_archive_file_pathname" && printf x)"
			output_archive_parent_dir_pathname="${output_archive_parent_dir_pathname%$'\nx'}"

			if [ ! -w "$output_archive_parent_dir_pathname" ]; then
				errlog "$output_archive_parent_dir_pathname: permission denied: write permission missing"
				exit 77
			fi

			unset -v output_archive_parent_dir_pathname
		fi
		;;
	('stdout:')
		output_archive_file_pathname=''
		;;
	(*)
		errlog "emergency stop: wrong format for 'output_archive_target' variable: $output_archive_target"
		exit 123
		;;
esac

readonly output_archive_file_pathname

unset -v output_archive_target

#endregion

readonly user_was_prompted

#region checking copy destinations

declare copy_destination_pathname
for copy_destination_pathname in "${copy_destination_pathnames[@]}"; do
	declare result
	result="$(resolve_pathname "$copy_destination_pathname" && printf x)"
	result="${result%x}"

	case "$result" in
		('EACCESS:'?*)
			errlog "${result#EACCESS:}: permission denied: search permissions missing"
			exit 77
			;;
		('ENOENT:'*)
			errlog "${result#ENOENT:}: no such file or directory"
			exit 24
			;;
		('ENOTDIR:'?*)
			errlog "${result#ENOTDIR:}: not a directory"
			exit 26
			;;
	esac

	unset -v result
done
unset -v copy_destination_pathname

#endregion

#region executing final commands

function write_bak_pathnames_null_separated() {
	local -i i
	i=1

	printf '%s' "${bak_pathnames[0]}"

	for ((; i < ${#bak_pathnames[@]}; ++i)); do
		printf '\0%s' "${bak_pathnames[i]}"
	done
}
readonly -f write_bak_pathnames_null_separated


declare -a tar_args
tar_args=(
	--create --gzip
	--verbose
)


if [ -n "$output_archive_file_pathname" ]; then
	tar_args+=(--force-local --file="$output_archive_file_pathname")
else
	tar_args+=(--to-stdout)
fi


declare output_archive_file_absolute_pathname

output_archive_file_absolute_pathname="$(ensure_absolute_pathname "$output_archive_file_pathname" && printf x)"
output_archive_file_absolute_pathname="${output_archive_file_absolute_pathname%x}"

output_archive_file_absolute_pathname="$(escape_glob_pattern "$output_archive_file_absolute_pathname" && printf x)"
output_archive_file_absolute_pathname="${output_archive_file_absolute_pathname%x}"

tar_args+=(
	--exclude='node_modules'
	--exclude-tag='.nobak'
	--exclude-ignore='.nobakpattern'

	--exclude="$output_archive_file_absolute_pathname"
)

unset -v output_archive_file_absolute_pathname


declare missing_pathname
for missing_pathname in "${missing_pathnames[@]}"; do
	missing_pathname="${missing_pathname%/}"

	missing_pathname="$(escape_glob_pattern "$missing_pathname" && printf x)"
	missing_pathname="${missing_pathname%x}"

	tar_args+=(--exclude="$missing_pathname")
done
unset -v missing_pathname


tar_args+=(
	--absolute-names
	--verbatim-files-from --null --files-from='-'
)


if $include_user_crontab; then
	function remove_crontab_file() {
		rm -f -- "$crontab_backup_file_pathname"
	}
	readonly -f remove_crontab_file

	crontab -l > "$crontab_backup_file_pathname"
	trap remove_crontab_file EXIT TERM INT QUIT
fi

if $user_was_prompted; then
	log
fi
tar "${tar_args[@]}" < <(write_bak_pathnames_null_separated)

if $include_user_crontab; then
	remove_crontab_file
	trap - EXIT TERM INT QUIT
fi


declare copy_destination_pathname
for copy_destination_pathname in "${copy_destination_pathnames[@]}"; do
	cp -- "$output_archive_file_pathname" "$copy_destination_pathname"
done
unset -v copy_destination_pathname

#endregion
