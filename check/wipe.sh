
#!/bin/bash

#
# wipe wrapper
#


# read in configuration file
#
PWD="$(dirname $0)"
. $PWD/config
. $PWD/report.function
. $PWD/wipe.function

main_wipe "$@"
