#!/usr/bin/env bash

## Exit script if you try to use an uninitialized variable.
#set -o nounset
#
## Exit script if a statement returns a non-true return value.
#set -o errexit
#
## Use the error status of the first failure, rather than that of the last item in a pipeline.
#set -o pipefail

sfdx_project_dir=$1
alias=$2
declare -a packages=${3}
devhubusername=${4:-""}

if [ -n "$packages" ]
then
  # switch to the path where the script is installed
  current_dir=$(pwd)
  SCRIPT_PATH=${BASH_SOURCE[0]%/*}
  if [ "$0" != "$SCRIPT_PATH" ] && [ "$SCRIPT_PATH" != "" ]; then
      cd "$SCRIPT_PATH"
  fi
  source ./install_package.sh
  # switch back
  cd "$current_dir" || exit

  if [ -z "$devhubusername"  ]
  then
    devhubusername=$(sfdx config:get defaultdevhubusername --json | jq -r '.result[0].value')
  fi
  if [ -z $devhubusername ]
  then
    echo 'Packaging dev hub not set. Exiting';
    return 1;
  else
    real_username=$(sfdx alias:list --json | jq -r '.result | .[] | select(.alias=='\"$devhubusername\"') | .value')
    if [ -n "$real_username" ]
    then
      devhubusername=$real_username
    fi
    echo 'Using '"$devhubusername"' as packaging dev hub username or alias';
  fi
  for package in "${packages[@]}"
  do
    echo 'Processing package id ' $package
    packageVersionJSON=$(sfdx force:data:soql:query -q "SELECT Id,Package2Id,SubscriberPackageVersionId,Description,IsDeprecated,IsPasswordProtected,IsReleased FROM Package2Version WHERE Package2Id='$package' AND IsReleased=TRUE ORDER BY CreatedDate DESC LIMIT 1" -t --json -u "$devhubusername")
    packageVersionId=$(echo $packageVersionJSON | jq -r '.result.records[0].SubscriberPackageVersionId')
    echo 'Package version id ' $packageVersionId ' found'
    install_package "$packageVersionId" "$alias" "$devhubusername" 5 30
  done
  cd "$current_dir" || exit
fi
