# How to use cert_deploy.php script

## Installation

Run `composer install` while staying in this directory.

## Usage

To be able to authenticate with Acquia Cloud API, you'll need to create token and secret as described at https://cloud.acquia.com/api-docs/#Authentication and store them in variables called `$acquia_cloud_token` and `$acquia_cloud_secret`, stored is `secrets.settings.php` as described at https://docs.acquia.com/resource/secrets/.

To see the required parameters, execute the script with the `--help` option.
