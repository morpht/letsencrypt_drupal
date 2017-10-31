#!/usr/bin/env bash

# Example call:
# ./letsencrypt_acquia.sh @acquiasite.prod /var/www/html/acquiasite.prod &>> /var/log/sites/${AH_SITE_NAME}/logs/$(hostname -s)/letsencrypt_acquia.log

# Params
#---------------------------------------------------------------------
# * Site alias
# ** Drush alias for the site.
# * Path to project root
# ** Must contain letsencrypt_acquia folder. See readme.

# Basic variables.
DRUSH_ALIAS="$1"
PROJECT_ROOT="$2"

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEHYDRATED="https://github.com/lukas2511/dehydrated.git"

FILE_DOMAINSTXT=${PROJECT_ROOT}/letsencrypt_acquia/domains.txt
FILE_CONFIG=${PROJECT_ROOT}/letsencrypt_acquia

source ${CURRENT_DIR}/functions.sh

# Based on "Shell script self update using git"
# @See: https://stackoverflow.com/a/35365800
# @See: https://stackoverflow.com/a/13738316
SCRIPT=$(readlink -f "$0")
SCRIPTNAME="$0"

self_update() {
    cd $CURRENT_DIR
    git fetch origin
    reslog=$(git log HEAD..origin/master --oneline)
    if [[ "${reslog}" != "" ]]; then
        echo "Found a new version of me, updating myself..."
        slackpost "${PROJECT_ROOT}" "warning" "Morpht/letsencrypt_acquia on ${DRUSH_ALIAS}" "Found a new version of me, updating myself..."

        # Remove dehydrated library to make sure we get new version.
        rm -rf ${CURRENT_DIR}/dehydrated
        # Self update.
        git pull --force
        git checkout master
        git pull --force
        # Running the new version.
        exec "$CURRENT_DIR/letsencrypt_acquia.sh" "$DRUSH_ALIAS" "$PROJECT_ROOT"

        # Exit this old instance
        exit 1
    fi
    echo "Already the latest version."
    slackpost "${PROJECT_ROOT}" "good" "Morpht/letsencrypt_acquia on ${DRUSH_ALIAS}" "The script is already the latest version."
}

main() {
  # main code - let's go
  acquire_lock_or_exit

  # Make sure we have dehydrated library.
  if [ ! -f ${CURRENT_DIR}/dehydrated/dehydrated ]; then
    logline "${DEHYDRATED} is missing - running git clone to get the script."
    git clone ${DEHYDRATED} ${CURRENT_DIR}/dehydrated

    if [ $? -eq 0 ]; then
      logline "Successfully clonned ${DEHYDRATED}";
    else
      logline "Error clonning ${DEHYDRATED}";
      exit 1
    fi
  else
    logline "${DEHYDRATED} is already in place - all good."
  fi

  # Start clean
  rm -rf ${TMP_DIR}
  mkdir -p ${TMP_DIR}/wellknown
  mkdir -p ${CERT_DIR}

  # Generate config and create empty domains.txt
  echo 'CA="https://acme-v01.api.letsencrypt.org/directory"' > ${FILE_BASECONFIG}
  echo 'CA_TERMS="https://acme-v01.api.letsencrypt.org/terms"' >> ${FILE_BASECONFIG}
  #echo 'CA="https://acme-staging.api.letsencrypt.org/directory"' > ${FILE_BASECONFIG}
  #echo 'CA_TERMS="https://acme-staging.api.letsencrypt.org/terms"' >> ${FILE_BASECONFIG}
  echo 'CHALLENGETYPE="http-01"' >> ${FILE_BASECONFIG}
  echo 'WELLKNOWN="'${TMP_DIR}/wellknown'"' >> ${FILE_BASECONFIG}
  echo 'BASEDIR="'${CERT_DIR}'"' >> ${FILE_BASECONFIG}
  echo 'HOOK="'${CURRENT_DIR}'/letsencrypt_acquia_hooks.sh"' >> ${FILE_BASECONFIG}
  echo 'DOMAINS_TXT="'${FILE_DOMAINSTXT}'"' >> ${FILE_BASECONFIG}
  echo 'CONFIG_D="'${FILE_CONFIG}'"' >> ${FILE_BASECONFIG}

  # Dehydrated does not pass arbitary parameters to hooks. Save some data aside.
  echo ${DRUSH_ALIAS} > ${FILE_DRUSH_ALIAS}
  echo ${PROJECT_ROOT} > ${FILE_PROJECT_ROOT}

  ${CURRENT_DIR}/dehydrated/dehydrated --config ${FILE_BASECONFIG} --cron --accept-terms
}

self_update
main
