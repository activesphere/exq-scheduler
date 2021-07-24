FROM buildpack-deps:jessie-curl

RUN curl -L https://github.com/Shopify/toxiproxy/releases/download/v2.1.4/toxiproxy-server-linux-amd64 -o /usr/bin/toxiproxy
RUN chmod +x /usr/bin/toxiproxy
RUN curl -L https://github.com/Shopify/toxiproxy/releases/download/v2.1.4/toxiproxy-cli-linux-amd64 -o /usr/bin/toxiproxy-cli
RUN chmod +x /usr/bin/toxiproxy-cli

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
