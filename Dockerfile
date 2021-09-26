# syntax=docker/dockerfile:1

## NODE_VER can be overwritten on build with --build-arg
## Pinned version tag from https://hub.docker.com/_/node
ARG NODE_VER=16-alpine

############################################################
## STAGE ONE
## Build btc-rpc-explorer
##############################################################
FROM node:${NODE_VER} as explorer-builder

## SET BTC-RPC-EXPLORER RELEASE VERSION
## https://github.com/janoside/btc-rpc-explorer/releases
ARG EXPLORER_VER=3.2.0

## INSTALL DEPENDENCIES
RUN apk --no-cache add --update \
    python3 \
    alpine-sdk \
    wget

## MAKE DIRECTORY FOR NODE APP
RUN mkdir /app && chmod go+rX,u+rwX /app

## DOWNLOAD SOURCE, EXTRACT AND MOVE INTO APP FOLDER
RUN wget https://github.com/janoside/btc-rpc-explorer/archive/refs/tags/v${EXPLORER_VER}.tar.gz && \
    tar -xzf v${EXPLORER_VER}.tar.gz && \
    mv /btc-rpc-explorer-${EXPLORER_VER}/* /app

## SET WORKING DIR TO SOURCE FILES
WORKDIR /app

## NPM INSTALL
RUN npm install npm@latest --global && \
    npm install --production

############################################################
## STAGE TWO
## Put it all together
##############################################################
FROM node:${NODE_VER} as release

## SET CONFIG STORAGE LOCATION
ENV CONFIG_DIR=/btc-rpc-explorer
ENV BTC_CORE_DIR=/bitcoin

# SET PRODUCTION NODE ENVIRONMENT
ARG NODE_ENV=production
ENV NODE_ENV $NODE_ENV

## CREATE NON-ROOT USER FOR SECURITY
RUN addgroup --gid 10001 --system nonroot && \
    adduser  --uid 10000 --system --ingroup nonroot --home /home/nonroot nonroot

## MAKE DIRECTORIES
RUN mkdir -p ${CONFIG_DIR} && chown -R nonroot:nonroot ${CONFIG_DIR} && chmod go+rX,u+rwX ${CONFIG_DIR} &&\
    mkdir -p ${BTC_CORE_DIR} && chown -R nonroot:nonroot ${BTC_CORE_DIR} && chmod go+rX,u+rwX ${BTC_CORE_DIR} &&\
    mkdir -p /etc/btc-rpc-explorer && chown -R nonroot:nonroot /etc/btc-rpc-explorer && chmod go+rX,u+rwX /etc/btc-rpc-explorer &&\
    mkdir -p /app && chown -R nonroot:nonroot /app && chmod go+rX,u+rwX /app

## INSTALL DEPENDENCIES
RUN apk --no-cache add --update \
    tini bind-tools \
    su-exec shadow \
    bash

## COPY FROM BUILDER
COPY --from=explorer-builder --chown=nonroot:nonroot /app /app

## UPDATE PATH
ENV PATH /app/node_modules/.bin:$PATH

## COPY ENTRY POINT
COPY --chown=nonroot:nonroot --chmod=go+rX,u+rwX entrypoint.sh /usr/local/bin

## COPY CONFIG FILE
COPY --chown=nonroot:nonroot ./btc-rpc-explorer.env* /tmp

## CONTAINER ENV VARIABLES
## Different to app env so they don't supersede config file
ENV PUID= \
    PGID= \
    OVERWRITE_CONFIG="false" \
    LOG_CONFIG="false" \
    DEBUGGER="BRE:app,BRE:error" \
    BASEURL=/ \
    COIN="BTC" \
    HOST="127.0.0.1" \
    PORT="3002" \
    BITCOIND_HOST="127.0.0.1" \
    BITCOIND_PORT="8332" \
    BITCOIND_USER= \
    BITCOIND_PASS= \
    BITCOIND_COOKIE="/bitcoin/.cookie" \
    BITCOIND_RPC_TIMEOUT="5000" \
    ADDRESS_API="blockcypher.com" \
    ELECTRUM_SERVERS= \
    ELECTRUM_TXINDEX= \
    RPC_CONCURRENCY="2" \
    NO_INMEMORY_RPC_CACHE="true" \
    REDIS_HOST= \
    REDIS_PORT="6379" \
    COOKIE_SECRET= \
    DEMO=true \
    SLOW_DEVICE_MODE="false" \
    PRIVACY_MODE="true" \
    NO_RATES="true" \
    BASIC_AUTH_PASSWORD= \
    SSO_TOKEN_FILE= \
    SSO_LOGIN_REDIRECT_URL= \
    RPC_ALLOWALL="true" \
    RPC_BLACKLIST= \
    GANALYTICS_TRACKING= \
    SENTRY_URL= \
    IPSTACK_APIKEY= \
    MAPBOX_APIKEY= \
    FILESYSTEM_CACHE_DIR= \
    PLAUSIBLE_ANALYTICS_DOMAIN= \
    PLAUSIBLE_ANALYTICS_SCRIPT_URL= \
    OLD_SPACE_MAX_SIZE="2048" \
    NOTXINDEX_SEARCH_DEPTH="3" \
    UI_THEME="dark" \
    UI_HOME_PAGE_LATEST_BLOCKS_COUNT="10" \
    UI_BLOCKS_PAGE_BLOCK_COUNT="50"

## RUN ENTRYPOINT SCRIPT
ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]

VOLUME [ "${CONFIG_DIR}" ]

## SET WORKING DIRECTORY TO NODE APP
WORKDIR /app

## START NODE APP
CMD [ "node", "./bin/www" ]

## EXPOSE PORT
EXPOSE 3002