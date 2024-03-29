#ignore
# Copyright (c) 2023 Michael Federczuk
# SPDX-License-Identifier: MPL-2.0 AND Apache-2.0
#end-ignore

#include options_base.bash
#ignorenext
. options_base.bash


#include options/input.bash
#ignorenext
. options/input.bash

#include options/output.bash
#ignorenext
. options/output.bash

#include options/crontab.bash
#ignorenext
. options/crontab.bash

#include options/copy.bash
#ignorenext
. options/copy.bash

#ignore

# temporarily ignored while the transient backups feature is deactivated

#include options/transient.bash
#ignorenext
. options/transient.bash

#include options/exec_mode.bash
#ignorenext
. options/exec_mode.bash

#end-ignore

#include options/help.bash
#ignorenext
. options/help.bash

#include options/version_info.bash
#ignorenext
. options/version_info.bash
