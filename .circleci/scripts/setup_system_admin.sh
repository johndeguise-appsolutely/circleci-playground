#!/usr/bin/env bash

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Sets up the system admin for a materialise scratch org
# must be run from a sfdx project directory
setup_system_admin() {
  # scratch org username
  local localUsername=${1:-""}
  local devhubusername=${2:-""}

  local mat_admin_permset_name="Materialise_Admin"

  if [ -z $devhubusername ]
  then
    devhubusername=$(sfdx config:get defaultdevhubusername --json | jq -r '.result[0].value')
    if [ -z $devhubusername ]
    then
      echo 'Default devhub not set. Exiting';
      return 1;
    fi
  fi
  echo 'Using devhub '$devhubusername

  local current_dir=$(pwd)
  local localSCRIPT_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 ; pwd -P )
  # local localSCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

  # get the username in case the arg is an alias
  local real_username=$(sfdx alias:list --json | jq -r '.result | .[] | select(.alias=='\"$localUsername\"') | .value')
  if [ -n "$real_username" ]
  then
    localUsername=$real_username
  fi

  # determine if this is a scratch org and if it is namespaced or not
  local org_list_json=$(sfdx force:org:list --clean --json -p)
  local local_org_exists=$(jq -r '.result | .scratchOrgs | unique_by(.username) | .[] | select(.username=='\"$localUsername\"')' <<< "$org_list_json")
  local namespace
  if [ -n "$local_org_exists" ]
  then
    local namespace_json=$(sfdx force:data:soql:query -u "$devhubusername" -q "SELECT Namespace FROM ActiveScratchOrg WHERE SignupUsername='$localUsername'" --json)
    namespace=$(jq -r '.result | .records | .[] | select(.Namespace!=null) | .Namespace' <<< $namespace_json)
    if [ -n "$namespace" ]
    then
      echo 'Namespace of org '$namespace
    else
      echo 'Non-namespaced org'
    fi
  fi

  echo 'Fetch user data'
  local userId=$(sfdx force:data:soql:query -u $localUsername --query \ "Select Id From User WHERE UserName ='$localUsername'" -r csv | tail -n +2)

  echo 'Set country code'
  sfdx force:data:record:update -s User -v "Country='United States'" -w "Username='$localUsername'"

  echo 'Assign Materialise admin permset'
  local permissionSetId=$(sfdx force:data:soql:query -u $localUsername --query "SELECT Id FROM PermissionSet WHERE Name='$mat_admin_permset_name'" --json | jq -r '.result.records[0].Id')
  local permSetAssigned=$(sfdx force:data:soql:query -u $localUsername --query "SELECT Id FROM PermissionSetAssignment WHERE AssigneeId='$userId' AND PermissionSetId='$permissionSetId'" --json | jq -r '.result.records | length')
  if [ "$permSetAssigned" -eq 0 ]
  then
    sfdx force:data:record:create -u $localUsername -s PermissionSetAssignment -v "AssigneeId=$userId PermissionSetId=$permissionSetId"
  else
    echo 'Permission set with name '$mat_admin_permset_name' already assigned to user '$localUsername
  fi

  echo 'Create and set role (necessary to use the user as default person account owner)'
  local nrOfRoles=$(sfdx force:data:soql:query -q "SELECT Id FROM UserRole WHERE DeveloperName='Portal_Account_Owner'" --json | jq -r '.result.records | length')
  if [ "$nrOfRoles" -eq 0 ]
  then
    echo 'Role does not exist yet. Creating'
    sfdx force:data:record:create -s UserRole -v "Name='Portal Account Owner' DeveloperName='Portal_Account_Owner' RollupDescription='Portal Account Owner' " -u $localUsername
  fi
  local roleId=$(sfdx force:data:soql:query -u $localUsername --query \ "SELECT Id FROM UserRole WHERE Name = 'Portal Account Owner'" -r csv | tail -n +2)
  sfdx force:data:record:update -u $localUsername -s User -v "UserRoleId='$roleId'" -w "Id='$userId'"

  # TODO: move this to its own script
  echo 'Set timezone'
  local organizationTimeZone=$(sfdx force:data:soql:query --query \ "SELECT TimeZoneSidKey From Organization" -r csv | tail -n +2)
  sfdx force:data:record:update -s BusinessHours -v "TimeZoneSidKey='$organizationTimeZone' SaturdayEndTime=NULL SaturdayStartTime=NULL SundayEndTime=NULL SundayStartTime=NULL" -w "Name=Default"

  USER_ID=$userId
}