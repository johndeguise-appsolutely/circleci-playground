#!/usr/bin/env bash

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

sfdx_project_dir=$1
alias=$2
package_versions=$3
devhubusername=${4:-""}


if [ -n "$package_versions" ]
then
  # switch to the path where the script is installed
  current_dir=$(pwd)
  echo 'current dir '$current_dir
  SCRIPT_PATH=${BASH_SOURCE[0]%/*}
  echo 'SCRIPT PATH '$SCRIPT_PATH
  if [ "$0" != "$SCRIPT_PATH" ] && [ "$SCRIPT_PATH" != "" ]; then
      cd "$SCRIPT_PATH"
      echo $(pwd)
  fi
  source ./install_package.sh
  # switch back
  cd "$current_dir" || exit

  # switch to the project dir
  cd "$sfdx_project_dir"
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

  for package_version in $package_versions
  do
    echo 'Processing package version '$package_version
    install_package "$package_version" "$alias" "$devhubusername" 5 30
  done
  cd "$current_dir" || exit
fi

