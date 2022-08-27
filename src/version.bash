#ignore
# Copyright (c) 2022 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

readonly mkbak_version_major=0
readonly mkbak_version_minor=1
readonly mkbak_version_patch=0
readonly mkbak_version_pre_release=''

declare mkbak_version="$mkbak_version_major.$mkbak_version_minor.$mkbak_version_patch"
if [ -n "$mkbak_version_pre_release" ]; then
	mkbak_version+="-$mkbak_version_pre_release"
fi
readonly mkbak_version
