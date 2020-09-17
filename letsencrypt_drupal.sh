#!/usr/bin/env bash

# Example call with logging:
# ./letsencrypt_drupal.sh "projectname" "prod" &>> /var/log/sites/${AH_SITE_NAME}/logs/$(hostname -s)/letsencrypt_drupal.log

# Params
#-----------------------------------
# * Project name
# * Target environment


# We need to export basic arguments so hooks/letsencrypt_drupal_hooks.sh can use them.
export PROJECT="$1"
export ENVIRONMENT="$2"

# Functions.sh adds some useful functions and propagates lots of variables.
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=functions.sh
. ${CURRENT_DIR}/functions.sh "$@"


## Based on "Shell script self update using git"
## @See: https://stackoverflow.com/a/35365800
## @See: https://stackoverflow.com/a/13738316
#SCRIPT=$(readlink -f "$0")
#SCRIPTNAME="$0"

self_update() {
    cd $CURRENT_DIR || exit
    #git fetch origin
    reslog=$(git log HEAD..origin/master --oneline)
    if [[ "${reslog}" != "" ]]; then
        echo "Found a new version of me, updating myself..."
        slackpost "${PROJECT_ROOT}" "warning" "Morpht/letsencrypt_drupal on ${DRUSH_ALIAS}" "Found a new version of me, updating myself..."

        # Remove dehydrated library to make sure we get new version.
        rm -rf ${CURRENT_DIR}/dehydrated
        # Self update.
        git pull --force
        git checkout master
        git pull --force

        # Running the new version.
        exec "$CURRENT_DIR/letsencrypt_drupal.sh" "$@"

        # Exit this old instance
        exit 1
    fi

    # Update the cert deploy script dependencies.
    cd ${CURRENT_DIR}/acquia_cloud_cert_deployment || exit
    # 2020: Still no composer on Acquia Cloud https://docs.acquia.com/resource/composer/#using-composer-with-acquia-cloud
    wget https://getcomposer.org/composer-stable.phar -O composer-stable.phar
    chmod +x ./cert_deploy.php
    chmod +x ./composer-stable.phar
    ./composer-stable.phar install --no-interaction
    cd ${CURRENT_DIR} || exit

    echo "Already the latest version."
    slackpost "${PROJECT_ROOT}" "good" "Morpht/letsencrypt_drupal on ${DRUSH_ALIAS}" "The script is already the latest version."
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
  echo 'CA="letsencrypt"' > ${FILE_BASECONFIG}
  echo 'CHALLENGETYPE="http-01"' >> ${FILE_BASECONFIG}
  echo 'WELLKNOWN="'${TMP_DIR}/wellknown'"' >> ${FILE_BASECONFIG}
  echo 'BASEDIR="'${CERT_DIR}'"' >> ${FILE_BASECONFIG}
  echo 'HOOK="'${CURRENT_DIR}'/hooks/letsencrypt_drupal_hooks.sh"' >> ${FILE_BASECONFIG}
  echo 'DOMAINS_TXT="'${FILE_DOMAINSTXT}'"' >> ${FILE_BASECONFIG}
  echo 'HOOK_CHAIN="no"' >> ${FILE_BASECONFIG}
  echo 'CONFIG_D="'${DIRECTORY_DEHYDRATED_CONFIG}'"' >> ${FILE_BASECONFIG}

  echo "EXECUTING: ${CURRENT_DIR}/dehydrated/dehydrated --config ${FILE_BASECONFIG} --cron --accept-terms"
  DEHYDRATED_RESULT=$(${CURRENT_DIR}/dehydrated/dehydrated --config ${FILE_BASECONFIG} --cron --accept-terms 2>&1)
  if [ $? -eq 0 ]
  then
    # Send result to slack.
    slackpost "${PROJECT_ROOT}" "good" "SSL bot ${DRUSH_ALIAS}" "SSL Dehydrated script success. \`\`\`${DEHYDRATED_RESULT}\`\`\`"
  else
    # Send result to slack.
    slackpost "${PROJECT_ROOT}" "danger" "SSL bot ${DRUSH_ALIAS}" "*SSL Dehydrated script failure.* Manual review/fix required!  \`\`\`${DEHYDRATED_RESULT}\`\`\`"
  fi
  # Output for logging.
  echo "${DEHYDRATED_RESULT}"
}

self_update
main
