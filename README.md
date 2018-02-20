# Let's Encrypt Drupal

Wrapper script for https://github.com/lukas2511/dehydrated opinionated towards running in Drupal hosting environments and reporting to Slack. Slack is optional. Let's Encrypt challenge is published trough Drupal using Drush. There is no need to alter webserver settings or upload files.

## What it does

* Installation (TL;DR version)
  * `git clone` this repository to your server
  * Add configuration to your project.
  * Add cron task.
* Every time script gets executed it will
  * Self update check.
  * Check if lukas2511/dehydrated is available and download it if needed.
  * [If] There is **no** certificate generated by this script yet.
    * Generate a key pair.
    * Register you with Let's Encrypt.
    * Generate new certificate for you.
    * Post the result to Slack with further instructions. 
    * You need to add the certificate manually using Acquia UI.
  * [If] There **already is** certificate generated by this script.
    * It will check the validity of the certificate.
    * [If] The certificate is valid and not near the expiration date.
      * Post to Slack that everything is all right.
    * [If] The certificate is about to expire.
      * Renew the certificate.
      * Post to Slack that everything is all right.
  * Altering the list of domains in project repository results in generating new certificate.

## Requirements

* Environment where you can run bash script and setup cron.
* Read access to project root. (accessing config files)
* Permissions to run Drush commands with Drush alias against the site which is accessible via domains listed in `domains_site.env.txt` from internet.
* `git` must available.
* https://www.drupal.org/project/letsencrypt_challenge on target site.

## Installation

These steps are for PROD environment of PROJECT on Acquia Cloud. Can be easily adapted to other hosting environments.

* `ssh PROJECT.PROD@srv-XXXX.devcloud.hosting.acquia.com`
  * (You can get the address on "Servers" tab in Acquia UI)
  * `cd ~`
  * `git clone https://github.com/morpht/letsencrypt_drupal.git`
* In project root
  * Add letsencrypt_drupal configuration.
    * `git clone https://github.com/morpht/letsencrypt_drupal.git tmp_lea` # Temporarily get the repository to get example configuration files.
    * `cp -r tmp_lea/example_project_config/* .` # Copy the configuration.
    * `rm -rf tmp_lea/`
    * Edit `letsencrypt_drupal/config.sh` 
      * You need to set your e-mail. The script provides the rest of defaults needed to get a certificate.
      * You can alter other values as described here: https://github.com/lukas2511/dehydrated/blob/master/docs/examples/config
    * Edit `letsencrypt_drupal/domains_site.env.txt`
      * Rename it based on site alias you are going to be using.
      * For multiple environments create multiple copies of this file.
      * One line, space separated list of domains.
      * First domain will be set as Common name
      * Others are set as SANs
    * Edit `letsencrypt_drupal/slack.sh`
      * Slack is optional. If you don't want to use it, just delete this file.
      * Get your webhook url here: https://my.slack.com/services/new/incoming-webhook/
      * Set the webhook url and target channel variables.
  * Add https://www.drupal.org/project/letsencrypt_challenge module.
    * `composer require drupal/letsencrypt_challenge`
  * Commit and deploy to production.
* In Acquia UI add the Scheduled task
  * Running the task often is not a problem.
  * Ideal is once a week, ideally on Monday morning.
    * Nobody wants to fix certificates on Friday evening :)
    * You should have 30 days of time (with default settings) even if something fails or new manual certificate upload is needed.
  * New job:
    * Job name: `LE renew cert` (just a default, feel free change it)
    * Command: `/home/PROJECT/letsencrypt_drupal/letsencrypt_drupal.sh @PROJECT.PROD [7|8] /var/www/html/PROJECT.PROD &>> /var/log/sites/${AH_SITE_NAME}/logs/$(hostname -s)/letsencrypt_drupal.log`
    * Command frequency `0 7 * * 1` ( https://crontab.guru/#0_7_*_*_1 )
  * It's good idea to run the command on Acquia manually or set the cron to run every minute for a bit so you don't have to wait.
* First script run will post instructions to Slack.

  Example:
  ```
  SSL bot @PROJECT.PROD APP
   New certificate for PROD.PROJECT.morpht.com was generated and needs to be uploaded to Acquia manually.
   
   SSH to @PROJECT.PROD to read files.
   Login to Acquia and open PROD environment for @PROJECT.PROD. Open SSL tab on the left side. Click Install SSL certificate.
   
   Text fields:
   SSL certificate: /home/PROJECT/.letsencrypt_drupal/certs/PROD.PROJECT.morpht.com/fullchain.pem
   SSL private key: /home/PROJECT/.letsencrypt_drupal/certs/PROD.PROJECT.morpht.com/privkey.pem
   CA intermediate certificates: /home/PROJECT/.letsencrypt_drupal/certs/PROD.PROJECT.morpht.com/chain.pem
   ```
