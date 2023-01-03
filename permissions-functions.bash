#!/bin/bash

create_permission_grp() {
  local grp_name="$1"

  net_result=` net -A "$ads_credential_path" ads group add "$grp_name" -c "$ads_perm_group_container" `
  net_retval="$?"

  if [[ "$?" != 0 ]]; then
    echo -e "$echo_title \033[0;31m !!error!! executing 'net -A \"$ads_credential_path\" ads group add \"$grp_name\" -c \"$ads_perm_group_container\"'\033[0m"
    return $?
  fi
}

determine_grp_names() {
  ## need to have the parent_name already determined, check that
  if [ -z "$parent_name" ]; then
    echo "'parent_name' variable doesn't exist or is blank" >&2
    return 1
  fi
  echo_title="  [$parent_name]"

  ## perform substituion to add server name and share name to build modify group name
  declare -g full_grp_name=`echo "$full_grp_name_template" | sed -e "s/{{[[:space:]]*servername[[:space:]]*}}/$server_name/;s/{{[[:space:]]*sharename[[:space:]]*}}/$parent_name/"`
  echo "$echo_title FullControl group name for '$parent_name' is '$full_grp_name'"
  
  ## perform substituion to add server name and share name to build modify group name
  declare -g modify_grp_name=`echo "$modify_grp_name_template" | sed -e "s/{{[[:space:]]*servername[[:space:]]*}}/$server_name/;s/{{[[:space:]]*sharename[[:space:]]*}}/$parent_name/"`
  echo "$echo_title Modify group name for '$parent_name' is '$modify_grp_name'"
  
  ## perform substituion to add server name and share name to build read group name
  declare -g read_grp_name=`echo "$read_grp_name_template" | sed -e "s/{{[[:space:]]*servername[[:space:]]*}}/$server_name/;s/{{[[:space:]]*sharename[[:space:]]*}}/$parent_name/"`
  echo "$echo_title Read group name for '$parent_name' is '$read_grp_name'"

  if [[ ` parent_has_user_dirs `=="TRUE" ]]; then
    declare -g read_root_only_grp=` echo "$read_grp_name" | sed 's/$/RootOnly/' `
    echo "$echo_title ReadRootOnly group name for '$parent_name' is '$read_root_only_grp'"

    declare -g modify_root_only_grp=` echo "$modify_grp_name" | sed 's/$/RootOnly/' `
    echo "$echo_title ModifyRootOnly group name for '$parent_name' is '$modify_root_only_grp'"
  fi
}

is_employee() {

  local employee_gid=`wbinfo --group-info=ccs\\\\employee | awk -F ':' '{print $3}'`

  if [ -n "` wbinfo -r "$ad_domain\\\\$username" | grep "$employee_gid" `" ]; then
    echo "TRUE"
    return 0
  else
    echo "FALSE"
    return 1
  fi
}

parent_dir_recursive_permissions() {
  ## have this function take parent or user, so it knows where to apply permissions to parent dir or just to user dir
  dir_type="$1"
  if [ "$dir_type" == "parent" ]; then
    dir_to_process="$parent_dir"
    echo_title="  [$parent_name]"
  else
    dir_to_process="$user_dir"
    echo_title="  [$parent_name][$username]"
  fi

  echo "$echo_title assign rwx ACL for $modify_grp_name recursively"
  setfacl -R -m group:"$ad_domain\\$modify_grp_name":rwx "$dir_to_process"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'setfacl -R -m group:$modify_grp_name:rwx $dir_to_process'\033[0m"

  echo "$echo_title assign default rwx ACL for $modify_grp_name recursively"
  setfacl -R -d -m group:"$ad_domain\\$modify_grp_name":rwx "$dir_to_process"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'setfacl -R -d -m group:$modify_grp_name:rwx $dir_to_process'\033[0m"

  echo "$echo_title assign rwx ACL for $full_grp_name recursively"
  setfacl -R -m group:"$ad_domain\\$full_grp_name":rwx "$dir_to_process"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'setfacl -R -m group:$full_grp_name:rwx $dir_to_process'\033[0m"

  echo "$echo_title assign default rwx ACL for $full_grp_name recursively"
  setfacl -R -d -m group:"$ad_domain\\$full_grp_name":rwx "$dir_to_process"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'setfacl -R -d -m group:$full_grp_name:rwx $dir_to_process'\033[0m"

  echo "$echo_title change assigned posix group to '$full_grp_name' recursively"
  chgrp -R "$ad_domain\\$full_grp_name" "$dir_to_process"

  echo "$echo_title assign rwx for posix group recursively"
  chmod -R g+rwx "$dir_to_process"

  echo "$echo_title add SGID to all directories"
  find "$dir_to_process" -type d -exec chmod g+s {} \;

  echo "$echo_title assign rx ACL for $read_grp_name recursively"
  setfacl -R -m group:"$ad_domain\\$read_grp_name":rx "$dir_to_process"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'setfacl -R -m group:$read_grp_name:rx $dir_to_process'\033[0m"

  echo "$echo_title assign default rx ACL for $read_grp_name recursively"
  setfacl -R -d -m group:"$ad_domain\\$read_grp_name":rx "$dir_to_process"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'setfacl -R -d -m group:$read_grp_name:rx $dir_to_process'\033[0m"

  echo "$echo_title add ACL rwx to 'Domain Admins' recursively"
  setfacl -R -m group:"$ad_domain\\domain admins":rwx "$dir_to_process"

  echo "$echo_title add default ACL rwx to 'Domain Admins' recursively"
  setfacl -R -d -m group:"$ad_domain\\domain admins":rwx "$dir_to_process"

  echo "$echo_title add ACL rwx to 'SYSTEM' recursively"
  setfacl -R -m group:"NT AUTHORITY\\system":rwx "$dir_to_process"

  echo "$echo_title add default ACL rwx to 'SYSTEM' recursively"
  setfacl -R -d -m group:"NT AUTHORITY\\system":rwx "$dir_to_process"

  echo "$echo_title removing permissions to posix other if any"
  chmod -R o-rwx "$dir_to_process"
}

parent_dir_rootonly_permissions() {
  echo_title="  [$parent_name]"

  echo "$echo_title assign rwx ACL for $modify_root_only_grp to root of dir only"
  setfacl -m group:"$ad_domain\\$modify_root_only_grp":rwx "$parent_dir"
  [[ "$?" != 0 ]] && echo "$echo_title \033[0;31m !!error!! executing 'setfacl -m group:$modify_root_only_grp:rwx $parent_dir'\033[0m"

  echo "$echo_title assign rx ACL for $read_root_only_grp to root of dir only"
  setfacl -m group:"$ad_domain\\$read_root_only_grp":rx "$parent_dir"
  [[ "$?" != 0 ]] && echo "$echo_title \033[0;31m !!error!! executing 'setfacl -m group:$read_root_only_grp:rx $parent_dir'\033[0m"
}

parent_has_user_dirs() {

  local has_user_dirs="FALSE"
  for n in "${parents_w_user_dirs[@]}"; do
    if [ -n "` echo "$parent_name" | egrep -i "^$n\$" `" ]; then
      declare -g "is_parent_$n"="TRUE"
      has_user_dirs="TRUE"
    else
      declare -g "is_parent_$n"="FALSE"
    fi
  done

  echo "$has_user_dirs"
  return 0
}

setup_scanner_dir() {
  local scanner_dir="$1/ricoh_scanner"

  echo "    [$parent_name][$username] Adding rx to '$ad_domain\\officecopier' ."
  setfacl -m "u:$ad_domain\\officecopier:rx" "$user_dir"
  [[ "$?" != 0 ]] && echo "    [$parent_name][$username] \033[0;31m !!error!! executing 'setfacl -m \"u:$addomain\\$officecopier:rx\" \"$user_dir\"'\033[0m"

  if [ ! -d "$scanner_dir" ]; then
    echo "    [$parent_name][$username] Creating 'ricoh_scanner' directory."
    mkdir -p "$scanner_dir"
    mkdir_retval="$?"
    if [[ "$mkdir_retval" != 0 ]]; then
      echo "    [$parent_name][$username] \033[0;31m !!error!! executing 'mkdir -p \"$scanner_dir\"'\033[0m"
      return $mkdir_retval
    fi
  fi

  if [ -d "$scanner_dir" ]; then
    echo "    [$parent_name][$username] adding ACL rwx to '$ad_domain\\officecopier' on '$username\ricoh_scanner'"
    setfacl -m "u:$ad_domain\\officecopier:rwx" "$scanner_dir"
    [[ "$?" != 0 ]] && echo "    [$parent_name][$username] \033[0;31m !!error!! executing 'setfacl -m \"u:$addomain\\$officecopier:rwx\" \"$scanner_dir\"'\033[0m"
  fi
}

user_directory_permissions() {
  local user_directory="$1"

  local user_dir_name=` basename "$user_directory" `
  local echo_title="    [$parent_name][$user_dir_name]"
  local username=` user_name_from_dir "$user_directory" `
  
  if [[ -z "$username" ]]; then
    echo -e "$echo_title Skipping '$user_directory'"
    return 1
  fi
  
  echo "$echo_title determined username is '$username' from directory name."

  echo "$echo_title assigning posix owner to '$username' recursively"
  chown -R "$ad_domain\\$username" "$user_directory"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'chown -R $username $user_directory'\033[0m"

  echo "$echo_title assign rwx to posix owner recursively"
  chmod -R u+rwx "$user_directory"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'chmod -R u+rwx $user_directory'\033[0m"

  echo "$echo_title adding default ACL rwx to '$username' recursively"
  setfacl -R -d -m "u:$ad_domain\\$username:rwx" "$user_directory"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'setfacl -R -d -m u:$username:rwx $user_directory'\033[0m"

  echo "$echo_title adding ACL rwx to '$username' recursively"
  setfacl -R -m "u:$ad_domain\\$username:rwx" "$user_directory"
  [[ "$?" != 0 ]] && echo -e "$echo_title \033[0;31m !!error!! executing 'setfacl -R -m u:$username:rwx $user_directory'\033[0m"

  if [[ ` is_employee ` == "TRUE" && "$parent_name" == "home" ]]; then
    setup_scanner_dir
  fi
}

user_name_from_dir() {
  local dir_to_check="$1"

  local dir_name=` basename "$dir_to_check" `
  local username=` echo "$dir_name" | sed -r -e 's/\.(orig|old|V[0-9]+)//' `

  ## check if username based on dir name exists
  if [ -z "` wbinfo -i "$ad_domain\\\\$username" `" ]; then
    echo -e "$echo_title \033[0;31m User '$username' doesn't exist. \033[0m" >&2
    return 1
  fi
  echo "$username"
}

## function to validate single group
does_grp_exist() {
  local grp_name="$1"

  wbinfo --group-info="$grp_name" > /dev/null
  wbinfo_retval="$?"
  if [[ "$wbinfo_retval" == 0 ]]; then
    echo "TRUE"
  else
    echo "FALSE"
  fi

  return $wbinfo_retval
}

test_ads_credentials() {
  net -A "$ads_credential_path" ads user > /dev/null
  net_retval="$?"
  if [ "$net_retval" != 0 ]; then
    echo -e "\033[0;31mError: provided ActiveDirectory credentials failed.\033[0m" >&2
    return $net_retval
  fi
}

## perform validation on all groups
validate_grp_names() {
  ## need to have the parent_name already determined, check that
  if [ -z "$parent_name" ]; then
    echo "'parent_name' variable doesn't exist or is blank" >&2
    return 1
  fi
  echo_title="  [$parent_name]"

  ## make sure groups exist
  echo -n "$echo_title Checking if '$full_grp_name' exists..."
  # wbinfo --group-info="$full_grp_name" > /dev/null || return $?
  does_grp_exist "$full_grp_name" > /dev/null || return $?
  echo "done."

  echo -n "$echo_title Checking if '$modify_grp_name' exists..."
  # wbinfo --group-info="$modify_grp_name" > /dev/null || return $?
  does_grp_exist "$modify_grp_name" > /dev/null || return $?
  echo "done."

  echo -n "$echo_title Checking if '$read_grp_name' exists..."
  # wbinfo --group-info="$read_grp_name" > /dev/null || return $?
  does_grp_exist "$read_grp_name" > /dev/null || return $?
  echo "done."

  if [[ ` parent_has_user_dirs `=="TRUE" ]]; then
    echo -n "$echo_title Checking if '$read_root_only_grp' exists..."
    # wbinfo --group-info="$ad_domain\\$read_root_only_grp" > /dev/null || return $?
    does_grp_exist "$read_root_only_grp" > /dev/null || return $?
    echo "done."

    echo -n "$echo_title Checking if '$modify_root_only_grp' exists..."
    # wbinfo --group-info="$ad_domain\\$modify_root_only_grp" > /dev/null || return $?
    does_grp_exist "$modify_root_only_grp" > /dev/null || return $?
    echo "done."
  fi
}