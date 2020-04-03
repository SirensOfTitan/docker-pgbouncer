FROM debian:buster-slim as build

# Install dependencies
ARG PGBOUNCER_VERSION
WORKDIR /var/pgbouncer
RUN apt-get update \
  && apt-get install --no-install-recommends -y build-essential libevent-dev ca-certificates pkg-config openssl wget libssl-dev
RUN wget http://www.pgbouncer.org/downloads/files/$PGBOUNCER_VERSION/pgbouncer-$PGBOUNCER_VERSION.tar.gz \
  && wget http://www.pgbouncer.org/downloads/files/$PGBOUNCER_VERSION/pgbouncer-$PGBOUNCER_VERSION.tar.gz.sha256 -O - | sha256sum -c - \
  && tar -zxf pgbouncer-$PGBOUNCER_VERSION.tar.gz

# Build the application
RUN cd pgbouncer-$PGBOUNCER_VERSION \
  && ./configure --prefix=/var/pgbouncer \
  && make \
  && make install

# Copy library dependencies
RUN ldd /var/pgbouncer/bin/pgbouncer | tr -s '[:blank:]' '\n' | grep '^/' | \
  xargs -I % sh -c 'mkdir -p $(dirname deps%); cp % deps%;'

FROM busybox:glibc
COPY --from=build /var/pgbouncer/bin/pgbouncer /usr/bin/pgbouncer
COPY --from=build /var/pgbouncer/deps /
COPY --from=build /etc/ssl/certs /etc/ssl/certs

RUN adduser -D -S postgres \
  && mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer \
  && chown postgres /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer \
  && ln -sT /etc/ssl /usr/ssl
USER postgres
VOLUME /etc/pgbouncer
EXPOSE 5432
CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
