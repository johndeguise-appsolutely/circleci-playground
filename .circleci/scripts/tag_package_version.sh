#!/bin/bash

package_version_id=$1
devhubusername=${2:-""}
tag=${3:-""}

echo $package_version_id
echo $devhubusername
echo $tag

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

if [ -z "$tag" ]
then
  package_id=$(sfdx force:package:version:report -p "$package_version_id" -v "$devhubusername" --json | jq -r '.result.Package2Id')
  echo 'package id found '$package_id
  tag=$(sfdx force:package:version:list -v "$devhubusername" -p "$package_id" --json | jq -r '.result | .[] | select(.SubscriberPackageVersionId=='\"$package_version_id\"') | .Alias')
  if [ -z "$tag" ]
  then
    echo 'Alias not known on this system for package version '$package_version_id'. Did you forget to checkout/checkin the sfdx-project.json? Exiting'
    return 1;
  else
    echo 'Package version alias found '$tag
  fi
fi

gittags=$(git tag)
if [[ $gittags == *"$tag"* ]]
then
  echo 'Tag already present. Exiting'
  return 0;
fi

git tag -a $tag -m "tagging with ${tag} [skip ci]"
