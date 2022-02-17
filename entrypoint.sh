#!/usr/bin/env bash

set -m

echo "Starting php-fpm and nginx via supervisor, send it to the background"
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf