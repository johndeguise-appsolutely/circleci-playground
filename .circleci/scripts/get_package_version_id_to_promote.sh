#!/usr/bin/env bash

## Exit script if you try to use an uninitialized variable.
#set -o nounset
#
## Exit script if a statement returns a non-true return value.
#set -o errexit
#
## Use the error status of the first failure, rather than that of the last item in a pipeline.
#set -o pipefail

get_package_version_id_to_promote() {
  local package_id=$1
  local branch=${2:-"develop"}
  local devhubusername=${3:-""}
  local major_version_number=${4:-""}
  local minor_version_number=${5:-""}
  local patch_version_number=${6:-""}

  if [ -z $devhubusername ]
  then
    devhubusername=$(sfdx config:get defaultdevhubusername --json | jq -r '.result[0].value')
    if [ -z $devhubusername ]
    then
      echo 'Default devhub not set. Exiting' >&2
      return 1;
    fi
  fi

  # getting the right package version to promote
  local query="WHERE Package2Id='$package_id' AND Branch='$branch' AND IsReleased=FALSE AND IsDeprecated=FALSE"
  if [ -n "$major_version_number" ]
  then
    query="${query} AND MajorVersion='$major_version_number'"
    if [ -n "$minor_version_number" ]
    then
      query="${query} AND MinorVersion='$minor_version_number'"
      if [ -n "$patch_version_number" ]
      then
        query="${query} AND PatchVersion='$patch_version_number'"
      fi
    fi
  fi
  local package_versions_json=$(sfdx force:data:soql:query -q "SELECT SubscriberPackageVersionId,MajorVersion,MinorVersion,PatchVersion,HasPassedCodeCoverageCheck FROM Package2Version $query ORDER BY CreatedDate DESC LIMIT 1" -t --json -u "$devhubusername")
  local package_versions=$(echo $package_versions_json | jq -r '.result.records')
  if [ -z "$package_versions" ]
  then
    echo "No package versions found for the given criteria!" >&2
    return 1
  fi
  local package_version_id=$(echo $package_versions_json | jq -r '.result.records | .[] | select(.HasPassedCodeCoverageCheck==true) | .SubscriberPackageVersionId')
  if [ -z "$package_version_id" ]
  then
    echo "Package version found did not pass code coverage." >&2
    return 1
  fi
  echo "$package_version_id"
}
