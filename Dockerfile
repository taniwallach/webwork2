FROM ubuntu:16.04

ENV PG_BRANCH=develop \
    WEBWORK_URL=/webwork2 \
    WEBWORK_ROOT_URL=https://mathnet-faq.math.technion.ac.il \
    WEBWORK_DB_HOST=db \
    WEBWORK_DB_PORT=3306 \
    WEBWORK_DB_NAME=webwork \
    WEBWORK_DB_USER=webworkWrite \
    WEBWORK_DB_PASSWORD=passwordRW \
    WEBWORK_SMTP_SERVER=techunix.technion.ac.il \
    WEBWORK_SMTP_SENDER=techdesk@mathnet.technion.ac.il \
    WEBWORK_TIMEZONE=Asia/Jerusalem \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    # temporary state file location. This might be changed to /run in Wheezy+1 \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_DIR=/var/run/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2 \
    # Only /var/log/apache2 is handled by /etc/logrotate.d/apache2.
    APACHE_LOG_DIR=/var/log/apache2 \
    APP_ROOT=/opt/webwork \
    DEBIAN_FRONTEND=noninteractive                \
    DEBCONF_NONINTERACTIVE_SEEN=true              \
    TZ='Asia/Jerusalem'                           \
    DEV=0

ENV WEBWORK_DB_DSN=DBI:mysql:${WEBWORK_DB_NAME}:${WEBWORK_DB_HOST}:${WEBWORK_DB_PORT} \
    WEBWORK_ROOT=$APP_ROOT/webwork2 \
    PG_ROOT=$APP_ROOT/pg \
    PATH=$PATH:$APP_ROOT/webwork2/bin



RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
       apache2 \
       curl \
       mc vim telnet tzdata apt-utils locales debconf-utils \
       ca-certificates \
       dvipng \
       gcc \
       libapache2-request-perl \
       libcrypt-ssleay-perl \
       libdatetime-perl \
       libdancer-perl \
       libdancer-plugin-database-perl \
       libdbd-mysql-perl \
       libemail-address-perl \
       libexception-class-perl \
       libextutils-xsbuilder-perl \
       libfile-find-rule-perl-perl \
       libgd-perl \
       libhtml-scrubber-perl \
       libjson-perl \
       liblocale-maketext-lexicon-perl \
       libmail-sender-perl \
       libmime-tools-perl \
       libnet-ip-perl \
       libnet-ldap-perl \
       libnet-oauth-perl \
       libossp-uuid-perl \
       libpadwalker-perl \
       libpath-class-perl \
       libphp-serialization-perl \
       libsoap-lite-perl \
       libsql-abstract-perl \
       libstring-shellquote-perl \
       libtemplate-perl \
       libtext-csv-perl \
       libtimedate-perl \
       libuuid-tiny-perl \
       libxml-parser-perl \
       libxml-writer-perl \
       libapache2-reload-perl \
       make \
       netpbm \
       preview-latex-style \
       texlive \
       texlive-latex-extra \
       libc6-dev \
       git \
       mysql-client \
    && apt-get clean \
    && rm -fr /var/lib/apt/lists/* /tmp/*


# Perl module installs

RUN curl -Lk https://cpanmin.us | perl - App::cpanminus \
    && cpanm install XML::Parser::EasyTree Iterator Iterator::Util Pod::WSDL Array::Utils HTML::Template XMLRPC::Lite Mail::Sender Email::Sender::Simple Data::Dump Statistics::R::IO \
    && rm -fr ./cpanm /root/.cpanm /tmp/*

RUN mkdir -p $APP_ROOT/courses $APP_ROOT/libraries $APP_ROOT/webwork2 $APP_ROOT/pg  $APP_ROOT/libraries/webwork-open-problem-library

COPY VERSION /tmp

# The next block would install pg from Git. Disabled for developers who
# may edit the core pg codebase:

#RUN WEBWORK_VERSION=`cat /tmp/VERSION|sed -n 's/.*\(develop\)'\'';/\1/p' && cat /tmp/VERSION|sed -n 's/.*\([0-9]\.[0-9]*\)'\'';/PG\-\1/p'` \
#    && curl -fSL https://github.com/openwebwork/pg/archive/${WEBWORK_VERSION}.tar.gz -o /tmp/${WEBWORK_VERSION}.tar.gz     \
#    && tar xzf /tmp/${WEBWORK_VERSION}.tar.gz      \
#    && mv pg-${WEBWORK_VERSION} $APP_ROOT/pg       \
#    && rm /tmp/${WEBWORK_VERSION}.tar.gz           \
#    && cd $APP_ROOT/pg/lib/chromatic               \
#    && gcc color.c -o color                        \
#    && chown www-data $APP_ROOT/pg/lib/chromatic   \
#    && chmod -R u+w   $APP_ROOT/pg/lib/chromatic



# color.c compiled above if pg was installed, as are directory settings for $APP_ROOT/pg/lib/chromatic




# Block to include webwork2 in the container, when needed, instead of  getting it from a bind mount.
#    Uncomment when needed, and set the correct branch name on the following line.
#ENV WEBWORK_BRANCH=develop   # need a valid branch name from https://github.com/openwebwork/webwork2
#RUN curl -fSL https://github.com/openwebwork/webwork2/archive/${WEBWORK_BRANCH}.tar.gz -o /tmp/${WEBWORK_BRANCH}.tar.gz \
#    && cd /tmp \
#    && tar xzf /tmp/${WEBWORK_BRANCH}.tar.gz \
#    && mv webwork2-${WEBWORK_BRANCH} $APP_ROOT/webwork2 \
#    && rm -rf /tmp/${WEBWORK_BRANCH}.tar.gz /tmp/webwork2-${WEBWORK_BRANCH}

# The next block would install the OPL from Git. Disabled for developers who
# use an external OPL tree.

#RUN curl -fSL https://github.com/openwebwork/webwork-open-problem-library/archive/master.tar.gz -o /tmp/opl.tar.gz \
#    && tar xzf /tmp/opl.tar.gz \
#    && mv webwork-open-problem-library-master $APP_ROOT/libraries/webwork-open-problem-library \
#    && rm /tmp/opl.tar.gz 

# MathJax

RUN curl -fSL https://github.com/mathjax/MathJax/archive/master.tar.gz -o /tmp/mathjax.tar.gz \
    && tar xzf /tmp/mathjax.tar.gz \
    && mv MathJax-master $APP_ROOT/MathJax \
    && rm /tmp/mathjax.tar.gz 

#  Moved down
#RUN echo "PATH=$PATH:$APP_ROOT/webwork2/bin" >> /root/.bashrc

COPY . $APP_ROOT/webwork2

# Various setup work:

RUN cd $APP_ROOT/webwork2/courses.dist        \
    && cp *.lst $APP_ROOT/courses/            \
    && cp -R modelCourse $APP_ROOT/courses/   \
    && cd $APP_ROOT/webwork2/conf \
    && cp webwork.apache2.4-config.dist webwork.apache2.4-config \
    && cp $APP_ROOT/webwork2/conf/webwork.apache2.4-config /etc/apache2/conf-enabled/webwork.conf \
    && a2dismod mpm_event \
    && a2enmod mpm_prefork \
    && sed -i -e 's/Timeout 300/Timeout 1200/' /etc/apache2/apache2.conf \
    && sed -i -e 's/MaxRequestWorkers     150/MaxRequestWorkers     20/' \
        -e 's/MaxConnectionsPerChild   0/MaxConnectionsPerChild   100/' \
        /etc/apache2/mods-available/mpm_prefork.conf \
    && cp $APP_ROOT/webwork2/htdocs/favicon.ico /var/www/html \
    && sed -i -e 's/^<Perl>$/\
      PerlPassEnv WEBWORK_URL\n\
      PerlPassEnv WEBWORK_ROOT_URL\n\
      PerlPassEnv WEBWORK_DB_DSN\n\
      PerlPassEnv WEBWORK_DB_USER\n\
      PerlPassEnv WEBWORK_DB_PASSWORD\n\
      PerlPassEnv WEBWORK_SMTP_SERVER\n\
      PerlPassEnv WEBWORK_SMTP_SENDER\n\
      PerlPassEnv WEBWORK_TIMEZONE\n\
      \n<Perl>/' /etc/apache2/conf-enabled/webwork.conf     \
   && cd $APP_ROOT/webwork2/ \
   && chown www-data DATA ../courses htdocs/tmp htdocs/applets logs tmp  \
   && chmod -R u+w DATA ../courses htdocs/tmp htdocs/applets logs tmp  \
   && rm /tmp/VERSION \
   && echo "PATH=$PATH:$APP_ROOT/webwork2/bin" >> /root/.bashrc

ENV WEBWORK_DB_DSN=DBI:mysql:${WEBWORK_DB_NAME}:${WEBWORK_DB_HOST}:${WEBWORK_DB_PORT} 

#  Moved down
#RUN echo "PATH=$PATH:$APP_ROOT/webwork2/bin" >> /root/.bashrc

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80 
EXPOSE 443

WORKDIR $APP_ROOT

# NSW - local to also add in DokuWiki support
RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        tzdata apt-utils locales debconf-utils vim telnet \
        apache2 \
        php7.0-fpm php7.0-cli php-apcu php7.0-gd php7.0-xml php7.0-curl php7.0-zip php7.0-json \
        php7.0-cgi php7.0 php7.0-readline php7.0-sqlite libapache2-mod-php7.0 php7.0-opcache \
        wget ssl-cert ca-certificates file libsasl2-modules xml-core \
    && apt-get clean \
    && rm -fr /var/lib/apt/lists/* /tmp/*


COPY preseed.txt /tmp/preseed.txt
COPY dw.conf             /etc/apache2/sites-available/dw.conf
COPY apache2.conf        /etc/apache2/apache2.conf

COPY 000-default.conf    /etc/apache2/sites-available/000-default.conf
COPY default-ssl.conf    /etc/apache2/sites-available/default-ssl.conf
COPY locale.gen          /etc/locale.gen



RUN echo $TZ > /etc/timezone \
    && rm /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && debconf-set-selections /tmp/preseed.txt \
    && /usr/sbin/locale-gen \
    && mkdir -p $APACHE_RUN_DIR $APACHE_LOCK_DIR $APACHE_LOG_DIR \
    && mkdir -p /var/www/html/faq /var/www/html/faq_english /var/www/html/staff \
    && chown www-data:www-data -R /var/www/html/faq /var/www/html/faq_english /var/www/html/staff \
    && chmod 755 /var/www/html/faq /var/www/html/faq_english /var/www/html/staff \
    && mkdir /etc/ssl/2016  \
    && cd /etc/apache2/sites-enabled && ln -s ../sites-available/dw.conf . \
    && a2enmod ssl && a2ensite default-ssl \ 
    && a2enmod proxy_fcgi setenvif && a2enconf php7.0-fpm \
    && a2enmod rewrite 

# Back to main WW file


CMD ["apache2", "-DFOREGROUND"]
