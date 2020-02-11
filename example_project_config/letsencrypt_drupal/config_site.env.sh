#!/usr/bin/env bash

# Slack endpoint and target channel.
# Get it here: https://my.slack.com/services/new/incoming-webhook/
SLACK_WEBHOOK_URL='https://hooks.slack.com/services/XXXXXXXXX/XXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX'
SLACK_CHANNEL='CHANNEL-NAME'

# UUID of target environment for cert deploy.
# Easiest to get from URL in Acquia Cloud UI. See https://cloudapi-docs.acquia.com/#/Environments/getEnvironment
# (Second uuid in URL when looking at specific environment.)
CERT_DEPLOY_ENVIRONMENT_UUID="XXXXXX-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"