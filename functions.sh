#!/usr/bin/env bash

CERT_DIR=~/.letsencrypt_drupal
TMP_DIR=/tmp/letsencrypt_drupal_$PROJECT_NAME
FILE_BASECONFIG=${TMP_DIR}/baseconfig
FILE_DRUSH_ALIAS=${TMP_DIR}/drush_alias
FILE_DRUPAL_VERSION=${TMP_DIR}/drupal_version
FILE_PROJECT_ROOT=${TMP_DIR}/project_root
LOCK_FILENAME=/tmp/cert_renew_lock_${PROJECT_NAME}

#---------------------------------------------------------------------
acquire_lock_or_exit()
{
  # Check we are not running already: http://mywiki.wooledge.org/BashFAQ/045
  exec 8>${LOCK_FILENAME}
  if ! flock -n 8  ; then
    logline "Another instance of this script running.";
    exit 1
  fi
  # This now runs under the lock until 8 is closed (it will be closed automatically when the script ends)
}

#---------------------------------------------------------------------
slackpost()
{
  SLACK_CONF="${1}/letsencrypt_drupal/slack.sh"
  # Can either be one of 'good', 'warning', 'danger', or any hex color code
  COLOR="${2}"
  USERNAME="${3}"
  TEXT="${4}"

  if [ -f ${SLACK_CONF} ]; then
    source ${SLACK_CONF}
    # based on https://gist.github.com/dopiaza/6449505
    escapedText=$(echo $TEXT | sed 's/"/\"/g' | sed "s/'/\'/g" )
    json="{\"channel\": \"$channel\", \"username\":\"$USERNAME\", \"icon_emoji\":\"ghost\", \"attachments\":[{\"color\":\"$COLOR\" , \"text\": \"$escapedText\"}]}"
    curl -s -d "payload=$json" "$webhook_url" || logline "Failed to send message to slack: ${USERNAME}: ${TEXT}"
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

  if [[ "${DRUPAL_VERSION}" == "7" ]]; then
    drush ${DRUSH_ALIAS} en -y --uri=${DOMAIN} letsencrypt_challenge
    drush ${DRUSH_ALIAS} vset -y --uri=${DOMAIN} letsencrypt_challenge "${TOKEN_VALUE}"
  elif [[ "${DRUPAL_VERSION}" == "8" ]]; then
    drush ${DRUSH_ALIAS} en -y --uri=${DOMAIN} letsencrypt_challenge
    drush ${DRUSH_ALIAS} sset -y --uri=${DOMAIN} letsencrypt_challenge.challenge "${TOKEN_VALUE}"
  fi
}
