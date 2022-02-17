ARG PHP_VERSION

FROM alpine:3.14.1 as typo3_install
ARG TYPO3_VERSION
RUN apk --no-cache add curl
WORKDIR /tmp

RUN curl -L -o typo3_src.tgz https://get.typo3.org/$TYPO3_VERSION && \
    mkdir -p /usr/share/typo3_src && \
    tar -xzf typo3_src.tgz && rm typo3_src.tgz && \
    cp -r "typo3_src-$TYPO3_VERSION"/. /usr/share/typo3_src

FROM php:${PHP_VERSION}-fpm-alpine3.14

RUN mkdir -p /var/cache/composer && chown -R www-data:www-data /var/cache/composer
ENV COMPOSER_HOME=/var/cache/composer

LABEL maintainer="Florian Dehn <flo@katzefudder.de>" \
  PHP_VERSION=${PHP_VERSION} \
  TYPO3_VERSION=${TYPO3_VERSION} \
  org.label-schema.description="TYPO3 Runtime" \
  org.label-schema.schema-version="1.0" \
  org.label-schema.vcs-url="git@github.com:katzefudder/typo3-fpm-nginx.git"

RUN apk add --no-cache git wget bash freetype libpng libjpeg-turbo libmcrypt-dev libxml2-dev freetype-dev libpng-dev libjpeg-turbo-dev libressl-dev libzip-dev icu-dev nodejs-current="16.11.1-r0" npm jq && \
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
          NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
    docker-php-ext-install -j$(nproc) gd && \
    docker-php-ext-configure json && \
    docker-php-ext-install -j$(nproc) json && \
    docker-php-ext-configure pdo_mysql && \
    docker-php-ext-install -j$(nproc) pdo_mysql && \
    docker-php-ext-install -j$(nproc) zip && \
    docker-php-ext-configure zip && \
    docker-php-ext-install -j$(nproc) fileinfo && \
    docker-php-ext-configure fileinfo && \
    docker-php-ext-install -j$(nproc) intl && \
    docker-php-ext-configure intl && \
    mkdir -p /usr/local/php/opcache && chown www-data:www-data /usr/local/php/opcache && \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

ADD php/php.ini /usr/local/etc/php/php.ini
ADD php/fpm.conf /usr/local/etc/php-fpm.d/www.conf

COPY --from=typo3_install /usr/share/typo3_src /usr/share/typo3_src

# install nginx and supervisor
RUN mkdir -p /var/lib/nginx/body /var/lib/nginx/proxy /var/lib/nginx/fastcgi && \
    #apt install -y nginx sudo supervisor procps && \
    apk add --no-cache nginx sudo su-exec supervisor procps aws-cli && \
    mkdir -p /var/log/supervisor

# nginx configuration
ADD nginx /etc/nginx

# supervisord configuration
ADD supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /var/www

RUN rm -Rf /var/www/html && \
    ln -s /usr/share/typo3_src typo3_src && \
    ln -s typo3_src/index.php && \
    ln -s typo3_src/typo3 && \
    # cp typo3/sysext/install/Resources/Private/FolderStructureTemplateFiles/root-htaccess .htaccess && \
    mkdir typo3temp && \
    mkdir typo3conf && \
    mkdir fileadmin && \
    mkdir uploads && \
    touch FIRST_INSTALL && \
    chown -R www-data:www-data /var/www

EXPOSE 80 9000

#USER www-data
WORKDIR /var/www

VOLUME /var/www/fileadmin
VOLUME /var/www/typo3conf
VOLUME /var/www/typo3temp
VOLUME /var/www/uploads

ADD entrypoint.sh /
CMD ["bash", "/entrypoint.sh"]