#!/usr/bin/env bash

# Environment variables that need to be available:
# * PROJECT
# * ENVIRONMENT

# Build up all required variables.
DRUSH_ALIAS="@${PROJECT}.${ENVIRONMENT}"
# Project root is a known path on Acquia Cloud.
PROJECT_ROOT="$HOME/letsencrypt_drupal_config/${PROJECT}.${ENVIRONMENT}"
FILE_CONFIG=${PROJECT_ROOT}/letsencrypt_drupal/config_${PROJECT}.${ENVIRONMENT}.sh
DIRECTORY_DEHYDRATED_CONFIG=${PROJECT_ROOT}/letsencrypt_drupal/dehydrated
FILE_DOMAINSTXT=${PROJECT_ROOT}/letsencrypt_drupal/domains_${PROJECT}.${ENVIRONMENT}.txt
DEHYDRATED="https://github.com/dehydrated-io/dehydrated.git"
CERT_DIR=~/.letsencrypt_drupal
TMP_DIR=/tmp/letsencrypt_drupal
FILE_BASECONFIG=${TMP_DIR}/baseconfig

# Detect core version
DRUPAL_VERSION="9"
if grep -q -r -i --include Drupal.php "const version" ${PROJECT_ROOT}; then DRUPAL_VERSION="8"; fi
if grep -q -r -i --include bootstrap.inc "define('VERSION', '" ${PROJECT_ROOT}; then DRUPAL_VERSION="7"; fi

# Load all variables provided by the project.
. ${FILE_CONFIG}

#---------------------------------------------------------------------
acquire_lock_or_exit()
{
  # Check we are not running already: http://mywiki.wooledge.org/BashFAQ/045
  # @ToDo: Platform specific lock.
  exec 8>/tmp/cert_renew_lock
  if ! flock -n 8  ; then
    logline "Another instance of this script running.";
    exit 1
  fi
  # This now runs under the lock until 8 is closed (it will be closed automatically when the script ends)
}

#---------------------------------------------------------------------
slackpost()
{
  # Can either be one of 'good', 'warning', 'danger', or any hex color code
  COLOR="${2}"
  USERNAME="${3}"
  TEXT="${4}"

  if [[ "$SLACK_WEBHOOK_URL" =~ ^https:\/\/hooks.slack.com* ]]; then
    # based on https://gist.github.com/dopiaza/6449505
    escapedText=$(echo $TEXT | sed 's/"/\"/g' | sed "s/'/\'/g")
    json="{\"channel\": \"$SLACK_CHANNEL\", \"username\":\"$USERNAME\", \"icon_emoji\":\"ghost\", \"attachments\":[{\"color\":\"$COLOR\" , \"text\": \"$escapedText\"}]}"
    curl -s -d "payload=$json" "$SLACK_WEBHOOK_URL" || logline "Failed to send message to slack: ${USERNAME}: ${TEXT}"
  else
    logline "No Slack: ${USERNAME}: ${TEXT}"
  fi
}

#---------------------------------------------------------------------
logline()
{
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

#---------------------------------------------------------------------
cd_or_exit()
{
  rv=0
  cd "$1" || rv=$?
  if [ $rv -ne 0 ]; then
    logline "Failed to cd into $1 directory. exiting."
    exit 31
  fi
}

#---------------------------------------------------------------------
drush_set_challenge()
{
  DRUSH_ALIAS="${1}"
  DRUPAL_VERSION="${2}"
  DOMAIN="${3}"
  TOKEN_VALUE="${4}"

  pushd /var/www/html/${PROJECT}.${ENVIRONMENT}
  echo "EXECUTING: drush en -y --uri=${DOMAIN} letsencrypt_challenge"
  drush en -y --uri=${DOMAIN} letsencrypt_challenge
  echo "EXECUTING: drush sset -y --uri=${DOMAIN} letsencrypt_challenge.challenge \"${TOKEN_VALUE}\""
  drush -y --uri=${DOMAIN} sset letsencrypt_challenge.challenge "${TOKEN_VALUE}"
  drush --uri=${DOMAIN} cr
  popd
}

drush_clean_challenge()
{
  DRUSH_ALIAS="${1}"
  DRUPAL_VERSION="${2}"
  DOMAIN="${3}"

  pushd /var/www/html/${PROJECT}.${ENVIRONMENT}
  drush pmu -y --uri=${DOMAIN} letsencrypt_challenge
  popd
}
