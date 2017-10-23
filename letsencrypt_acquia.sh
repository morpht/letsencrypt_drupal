#!/usr/bin/env bash

# Example call:
# ./letsencrypt_acquia.sh @acquiasite.prod /var/www/html/acquiasite.prod &>> /var/log/sites/${AH_SITE_NAME}/logs/$(hostname -s)/letsencrypt_acquia.log

# Params
#---------------------------------------------------------------------
# * Site alias
# ** Drush alias for the site.
# * Path to domains.txt
# ** One line = one cert, you most likely want space separated list of domains on one line for one acquia project.
DRUSH_ALIAS="$1"
PROJECT_ROOT="$2"

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEHYDRATED="https://github.com/lukas2511/dehydrated.git"

FILE_DOMAINSTXT=${PROJECT_ROOT}/letsencrypt_acquia/domains.txt
FILE_CONFIG=${PROJECT_ROOT}/letsencrypt_acquia

source ${CURRENT_DIR}/functions.sh

#---------------------------------------------------------------------
#---------------------------------------------------------------------
#---------------------------------------------------------------------

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


#${CURRENT_DIR}/dehydrated/dehydrated -f ${FILE_BASECONFIG} --version
#${CURRENT_DIR}/dehydrated/dehydrated -f ${FILE_BASECONFIG} --env
${CURRENT_DIR}/dehydrated/dehydrated --config ${FILE_BASECONFIG} --cron --accept-terms

# Cleanup
#rm -f ${FILE_BASECONFIG}
#rm -f ${FILE_DRUSH_ALIAS}
#rm -f ${FILE_PROJECT_ROOT}
