FROM httpd:2.4.59

USER root

# CIS Sezione 6.6: ModSecurity installation and configuration
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libapache2-mod-security2 \
        modsecurity-crs && \
    ln -sf /usr/lib/apache2/modules/mod_security2.so /usr/local/apache2/modules/mod_security2.so && \
    sed -i 's/^#LoadModule unique_id_module/LoadModule unique_id_module/' /usr/local/apache2/conf/httpd.conf && \
    echo "LoadModule security2_module modules/mod_security2.so" >> /usr/local/apache2/conf/httpd.conf && \
    rm -rf /var/lib/apt/lists/*

RUN cp /etc/modsecurity/modsecurity.conf-recommended /usr/local/apache2/conf/extra/modsecurity.conf && \
    cp /etc/modsecurity/unicode.mapping /usr/local/apache2/conf/extra/unicode.mapping && \
    cp -r /usr/share/modsecurity-crs /usr/local/apache2/conf/extra/modsecurity-crs && \
    cp /etc/modsecurity/crs/crs-setup.conf /usr/local/apache2/conf/extra/modsecurity-crs/crs-setup.conf && \
    mkdir -p /var/run/apache2/modsec /var/log/apache2 && \
    chown -R www-data:www-data /var/run/apache2/modsec /var/log/apache2 && \
    chmod 750 /var/run/apache2/modsec /var/log/apache2 && \
    sed -i \
        -e 's/^SecRuleEngine DetectionOnly/SecRuleEngine On/' \
        -e 's|^SecAuditLog .*|SecAuditLog /var/log/apache2/modsec_audit.log|' \
        -e 's|^SecTmpDir .*|SecTmpDir /var/run/apache2/modsec|' \
        -e 's|^SecDataDir .*|SecDataDir /var/run/apache2/modsec|' \
        /usr/local/apache2/conf/extra/modsecurity.conf

COPY conf/ciuismeglchuan.conf /usr/local/apache2/conf/extra/ciuismeglchuan.conf
RUN echo "Include conf/extra/ciuismeglchuan.conf" >> /usr/local/apache2/conf/httpd.conf

# CIS Sezione 2: Minimizzazione moduli Apache
RUN sed -i \
    # 2.1: Disabilita moduli authn/authz non necessari (mantiene solo authz_core e authz_host)
    -e 's/^\(LoadModule authn_.*\)/#\1/' \
    -e 's/^\(LoadModule authz_groupfile_module\)/#\1/' \
    -e 's/^\(LoadModule authz_user_module\)/#\1/' \
    # 2.2: Log Config Module Is Enabled
    -e 's/^#\(LoadModule log_config_module\)/\1/' \
    # 2.3: Disabilita moduli DAV non necessari
    -e 's/^\(LoadModule dav_.*\)/#\1/' \
    # 2.4: Disabilita il modulo status (espone un endpoint per il monitoraggio dello stato del server) non necessari
    -e 's/^\(LoadModule status_module\)/#\1/' \
    # 2.5: Disabilita moduli autoindex non necessari
    -e 's/^\(LoadModule autoindex_module\)/#\1/' \
    # 2.6: Disabilita moduli proxy non necessari (proxy e proxy_http verranno ricaricati in seguito quando si importa il file di configurazione ciuismeglchuan.conf)
    -e 's/^\(LoadModule proxy_*\)/#\1/' \
    # 2.7: Blocca il mapping di directory utente (UserDir) 
    -e 's/^\(LoadModule userdir_module\)/#\1/' \
    # 2.8: Info module (disabilitato)
    -e 's/^\(LoadModule info_module\)/#\1/' \
    # 2.9: Basic and Digest Authentication Modules Are Disabled
    -e 's/^\(LoadModule auth_basic_module\)/#\1/' \
    -e 's/^\(LoadModule auth_digest_module\)/#\1/' \
    # 2.10 (aggiuntivo): Moduli CGI e CGI daemon disabilitati (CGI e CGI daemon non sono necessari per il funzionamento di Apache)
    -e 's/^\(LoadModule cgid_module\)/#\1/' \
    -e 's/^\(LoadModule cgi_module\)/#\1/' \
    /usr/local/apache2/conf/httpd.conf

# CIS Sezione 3 (3.1 - 3.12): Account bloccato, ownership root:root, permessi e runtime dir + log directory
RUN usermod -L www-data \
    && mkdir -p /var/run/apache2/logs /etc/ssl/apache \
    && chown -R www-data:www-data /var/run/apache2 \
    && chmod 750 /var/run/apache2 \
    && chown root:www-data /etc/ssl/apache \
    && chmod 750 /etc/ssl/apache \
    && chown -R root:root /usr/local/apache2 \
    && chmod -R go-w /usr/local/apache2

# CIS Sezione 5.4/5.6: Rimozione pagine di benvenuto e file CGI di default (htdocs e cgi-bin)
RUN rm -rf /usr/local/apache2/htdocs/* /usr/local/apache2/cgi-bin/*

# CIS Sezione 5.15: Ascolto solo su interfaccia di rete selezionata 
RUN sed -i \
        -e 's/^Listen 80$/Listen 172.20.0.6:8080/' \
        -e 's/^#ServerName www.example.com:80/ServerName localhost/' \
        /usr/local/apache2/conf/httpd.conf && \
    rm -rf /usr/local/apache2/conf/original \
           /usr/local/apache2/conf/extra/httpd-*.conf 

# CIS Sezione 6.2: Log di errore su syslog
RUN sed -i 's|^ErrorLog .*|ErrorLog "syslog:local1"|' /usr/local/apache2/conf/httpd.conf

# CIS Sezione 6.3: Server Access Log configuration
RUN sed -i 's|CustomLog /proc/self/fd/1 common|CustomLog /proc/self/fd/1 combined|' /usr/local/apache2/conf/httpd.conf

# CIS Sezione 6.4: Log rotation (rotatelogs)
RUN sed -i 's#CustomLog /proc/self/fd/1 .*#CustomLog "|/usr/local/apache2/bin/rotatelogs -l -n 90 /var/run/apache2/logs/access.%Y.%m.%d.log 86400" combined#' /usr/local/apache2/conf/httpd.conf

# CIS Sezione 8.3: Rimozione contenuti di default (icons, htdocs, cgi-bin) per ridurre la superficie di attacco
RUN rm -rf /usr/local/apache2/icons \
           /usr/local/apache2/htdocs/* \
           /usr/local/apache2/cgi-bin/*

USER www-data