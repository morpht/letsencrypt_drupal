# How to use cert_deploy.php script

## Installation

Run `composer install` while staying in this directory.

## Usage

To be able to authenticate with Acquia Cloud API, you'll need to create token and secret as described at https://docs.acquia.com/acquia-cloud/develop/api/auth/ and store them in variables called `$acquia_cloud_token` and `$acquia_cloud_secret`, stored is `secrets.settings.php` as described at https://docs.acquia.com/resource/secrets/.

```
PROJECT@srv-XXXX:~$ cat /mnt/files/PROJECT.ENV/secrets.settings.php
<?php
// [NOTE ABOUT WHICH ACCOUNT IS USED]: morpht/letsencrypt_drupal
$acquia_cloud_token = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
$acquia_cloud_secret = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
```

To see the required parameters, execute the script with the `--help` option.
