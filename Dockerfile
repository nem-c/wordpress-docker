FROM nginx:1.26-alpine3.20 as nginx

FROM redis:7.4-alpine3.20 as redis

FROM php:8.2-fpm-alpine3.20 as php

FROM wordpress:cli-php8.2 as wp-cli

FROM wordpress:php8.2-fpm-alpine as wp-core

FROM alpine:3.20 as base
# install missing packages
RUN apk add --no-cache --update git supervisor

# ensure www-data user exists
RUN set -x ; \
  addgroup -g 82 -S www-data ; \
  adduser -u 82 -D -S -G www-data www-data ; \
  adduser www-data tty && exit 0 ; exit 1
# 82 is the standard uid/gid for "www-data" in Alpine

# ensure redis user exists
RUN set -x ; \
  addgroup -S redis ; \
  adduser -D -S -G redis redis ; \
  adduser redis tty && exit 0 ; exit 1

# Copy nginx binary as configuration files
COPY --from=nginx /usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx /etc/nginx /etc/nginx
COPY --from=nginx /usr/lib/nginx/modules /usr/lib/nginx/modules
COPY --from=nginx /usr/share/nginx /usr/share/nginx

COPY ./docker/config/nginx /etc/nginx
RUN mkdir -p /var/www/html && chown www-data. /var/www/html && mkdir /var/cache/nginx && chown -R www-data. /var/cache/nginx

# Copy redis binary and configuration files
COPY --from=redis /usr/local/bin/redis-* /usr/local/bin/
COPY --from=redis /usr/local/bin/gosu /usr/local/bin/gosu

COPY ./docker/config/redis /etc/redis
RUN mkdir -p /usr/local/data/redis && chown -R redis:redis /usr/local/data/redis

# Copy php binary, extensions and configuration files
COPY --from=php /usr/local/bin/docker-php-* /usr/local/bin/
COPY --from=php /usr/local/bin/php* /usr/local/bin/
COPY --from=php /usr/local/bin/pear /usr/local/bin/
COPY --from=php /usr/local/bin/pecl /usr/local/bin/
COPY --from=php /usr/local/bin/phar.phar /usr/local/bin/
COPY --from=php /usr/local/etc/pear.conf /usr/local/etc/
COPY --from=php /usr/local/etc/php /usr/local/etc/php
COPY --from=php /usr/local/etc/php-fpm.conf /usr/local/etc/
COPY --from=php /usr/local/etc/php-fpm.conf.default /usr/local/etc/
COPY --from=php /usr/local/etc/php-fpm.d /usr/local/etc/php-fpm.d
COPY --from=php /usr/local/lib/php /usr/local/lib/php/
COPY --from=php /usr/local/php/ /usr/local/php/
COPY --from=php /usr/local/sbin/php-fpm /usr/local/sbin/
COPY --from=php /usr/lib /usr/lib

COPY ./docker/config/php-fpm /usr/local/etc
RUN rm -f /usr/local/etc/php-fpm.d/*docker.conf

# Copy wp-cli binary
COPY --from=wp-cli /usr/local/bin/wp /usr/local/bin/wp

# Copy supervisord configuration file
COPY ./docker/config/supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /var/www/html
RUN echo "<?php echo phpinfo();?>" > index.php && chown www-data. index.php

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --interval=30s  --timeout=30s --start-period=5s --retries=3 CMD [ "wp", "core", "is-installed" ]
