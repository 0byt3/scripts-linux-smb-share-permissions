#!/usr/bin/bash

## make sure argument has been passed
if [ -z "$1" ]; then
  echo "Missing argument for path to user directory" >&2
  exit 1
fi

## remove trailing slash if there is one
user_dir=` echo "$1" | sed -r 's/\/$//' `
if [ ! -d "$user_dir" ]; then
  echo "'$1' is not a directory" >&2
  exit 1
fi

parent_dir=` dirname "$user_dir" `
parent_name=` basename "$parent_dir" `

## include functions and and variables from permissions-functions.bash and permissions-vars.bash.
#   expected to be in the same dir
script_dir=` dirname $0 `
if [ ! -f "$script_dir/permissions-functions.bash" ]; then
  echo "Expecting 'permissions-functions.bash' to be in the same directory as this script, however it is missing. 'permissions-functions.bash' is required." >&2
  exit 1
fi

if [ ! -f "$script_dir/permissions-vars.bash" ]; then
  echo "Expecting 'permissions-vars.bash' to be in the same directory as this script, however it is missing. 'permissions-vars.bash' is required." >&2
  exit 1
fi

. "$script_dir/permissions-vars.bash"
. "$script_dir/permissions-functions.bash"

## create global variables for the different groups representing the types of permissions
#   ( <SERVER_NAME>_<SHARE_NAME>-Share-Read, <SERVER_NAME>_<SHARE_NAME>-Share-Modify, ...)
determine_grp_names
validate_grp_names || exit $?

# parent_dir_recursive_permissions "user"

# parent_dir_rootonly_permissions "$parent_dir"

user_directory_permissions "$user_dir"
