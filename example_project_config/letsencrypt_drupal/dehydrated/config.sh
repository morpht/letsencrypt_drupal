# Only overrides here.
# @See: https://github.com/lukas2511/dehydrated/blob/master/docs/examples/config
CONTACT_EMAIL="contact+PROJECT@morpht.com"

# Minimum days before expiration to automatically renew certificate (default: 30)
# 60 for forcing new cert every month. (Fresh cert expires in 90 days.)
RENEW_DAYS="60"

# You should use following staging URLs when experimenting with this script
# to not hit Let's Encrypt's rate limits.
#CA="https://acme-staging.api.letsencrypt.org/directory"
#CA_TERMS="https://acme-staging.api.letsencrypt.org/terms"
