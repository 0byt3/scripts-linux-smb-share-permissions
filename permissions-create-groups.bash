#!/usr/bin/bash

## if a temp credential file needs to be built, use this
ads_credential_path="/tmp/ads_permissions_group_$RANDOM.credential"

cleanup() {
  test -f "$ads_credential_path" && rm -f "$ads_credential_path"
}

trap "cleanup; exit" 1 2 3 6 14 15

## include functions and and variables from permissions-lib.bash and permissions-vars.bash.
#   expected to be in the same dir
script_dir=`dirname $0`
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

if [ "$#" -lt 2 ]; then
  parent_dir_arg="$1"

  ## get username with access to create groups in ActiveDirectory
  echo "Groups container: $ad_permission_group_container"
  read -p "User with access to create groups in the container: " ads_user
  read -p "Password for the user: " -s ads_pwd_1
  echo ""
  read -p "Confirm Password: " -s ads_pwd_2
  echo ""
  if [[ "$ads_pwd_1" != "$ads_pwd_2" ]]; then
    echo -e "Passwords do not match" >&2
    exit 1
  fi

  ## create credential file
  touch "$ads_credential_path"
  chown root:root "$ads_credential_path"
  chmod 600 "$ads_credential_path"
  cat > "$ads_credential_path"<<EOF
USERNAME=$ads_user
PASSWORD=$ads_pwd_1
DOMAIN=$ad_domain
EOF

else
  parent_dir_arg="$2"

  if [ ! -f "$1" ]; then
    echo "The credential file '$1' does not exist" >&2
    exit 1
  fi

  ads_credential_path="$1"
fi

test_ads_credentials || exit $?

## make sure argument has been passed
if [ -z "$parent_dir_arg" ]; then
  echo "Missing argument for path to share directory" >&2
  exit 1
fi

## remove trailing slash if there is one
if [ ! -d "$parent_dir_arg" ]; then
  echo "'$parent_dir_arg' is not a directory" >&2
  exit 1
fi

parent_dir=` echo "$parent_dir_arg" | sed -r 's/\/$//' `
parent_name=`basename $parent_dir`


## create global variables for the different groups representing the types of permissions
#   ( <SERVER_NAME>_<SHARE_NAME>-Share-Read, <SERVER_NAME>_<SHARE_NAME>-Share-Modify, ...)
determine_grp_names

## create variable storing distinguishedName of container without the domain components (DC=??,DC=??...)
declare -a ads_perm_group_container=` echo "$ad_permission_group_container" | sed -r -e 's/,DC=[^,]+//g' `

create_permission_grp "$full_grp_name" || exit $?

create_permission_grp "$modify_grp_name" || exit $?

create_permission_grp "$read_grp_name" || exit $?

if [[ ` parent_has_user_dirs `=="TRUE" ]]; then
  create_permission_grp "$read_root_only_grp" || exit $?

  create_permission_grp "$modify_root_only_grp" || exit $?
fi

cleanup