FROM php:8.3-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libzip-dev \
        unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        gd \
        mysqli \
        pdo \
        pdo_mysql \
        zip \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*

RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY docker/php/zz-travianz.ini \
     "$PHP_INI_DIR/conf.d/zz-travianz.ini"

WORKDIR /var/www/html

COPY . /var/www/html

# Preserve pristine copies of the writable runtime files and directories.
RUN mkdir -p \
        /usr/local/share/travianz-runtime-seed/var \
        /usr/local/share/travianz-runtime-seed/Prevention \
        /usr/local/share/travianz-runtime-seed/Notes \
    && cp -a /var/www/html/var/. \
        /usr/local/share/travianz-runtime-seed/var/ \
    && cp -a /var/www/html/GameEngine/Prevention/. \
        /usr/local/share/travianz-runtime-seed/Prevention/ \
    && cp -a /var/www/html/GameEngine/Notes/. \
        /usr/local/share/travianz-runtime-seed/Notes/ \
    && cp /var/www/html/Templates/text.tpl \
        /usr/local/share/travianz-runtime-seed/text.tpl

COPY docker/apache/travianz-security.conf \
     /etc/apache2/conf-available/travianz-security.conf

COPY docker/entrypoint.sh /usr/local/bin/travianz-entrypoint

RUN a2enconf travianz-security \
    && chmod 755 /usr/local/bin/travianz-entrypoint \
    && chown -R root:root /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

VOLUME ["/var/lib/travianz-runtime"]

EXPOSE 80

ENTRYPOINT ["travianz-entrypoint"]
CMD ["apache2-foreground"]
