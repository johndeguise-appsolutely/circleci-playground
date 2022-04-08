#!/usr/bin/env bash

install_package()
{
  local packageVersionId=$1
  local alias=$2
  local devhubusername="${3:-mick.devalck@materialise.be}"
  local publish_wait_time="${4:-5}"
  local install_wait_time="${5:-30}"

  # get the package version ids on which this package id is dependent
  local dependencyJSON=$(sfdx force:data:soql:query -t -u "$devhubusername" -q "SELECT Dependencies FROM SubscriberPackageVersion WHERE Id='$packageVersionId'" --json)
  local dependencies=$(echo $dependencyJSON | jq -r '.result.records | .[] | .Dependencies.ids? | .[]? .subscriberPackageVersionId')
  # and install the dependent packages
  if [ ! -z "$dependencies" ]
  then
    for dependency in $dependencies
    do
      echo 'Installing package dependency '"$dependency"' for package version '"$packageVersionId"
      install_package "$dependency" "$alias" "$devhubusername" "$publish_wait_time" "$install_wait_time"
    done
  else
    echo 'No dependencies found for package version '"$packageVersionId"
  fi
  # install the main package
  local set alias_flag
  if [ -n "$alias" ]
  then
    alias_flag='-u '$alias
  fi
  local installed=$(sfdx force:data:soql:query -q "SELECT SubscriberPackageId,SubscriberPackageVersionId,Id FROM InstalledSubscriberPackage" -t $alias_flag --json | jq -r '.result.records | .[] | select(.SubscriberPackageVersionId=='\"$packageVersionId\"')')
  if [ -z "$installed" ]
  then
    echo 'Installing package version '$packageVersionId
    sfdx force:package:install --package "$packageVersionId" --noprompt --publishwait "$publish_wait_time" -w "$install_wait_time" -r $alias_flag
  else
    echo 'Package with package version id '$packageVersionId' already installed'
  fi
}
