#!/bin/bash
set -eo pipefail

# Set config file variable
EXP_CONFIG_FILE=${CONFIG_DIR}/btc-rpc-explorer.env

##############################################################################
## Map container runtime PUID & PGID
##############################################################################
map_user(){
  ## https://github.com/magenta-aps/docker_user_mapping/blob/master/user-mapping.sh
  ## https://github.com/linuxserver/docker-baseimage-alpine/blob/3eb7146a55b7bff547905e0d3f71a26036448ae6/root/etc/cont-init.d/10-adduser
  ## https://github.com/haugene/docker-transmission-openvpn/blob/master/transmission/userSetup.sh

  ## Set puid & pgid to run container, fallback to defaults
  PUID=${PUID:-10000}
  PGID=${PGID:-10001}

  ## If uid or gid is different to existing modify nonroot user to suit
  if [ ! "$(id -u nonroot)" -eq "$PUID" ]; then usermod -o -u "$PUID" nonroot ; fi
  if [ ! "$(id -g nonroot)" -eq "$PGID" ]; then groupmod -o -g "$PGID" nonroot ; fi
  echo "Tor set to run as nonroot with uid:$(id -u nonroot) & gid:$(id -g nonroot)"

  ## Make sure volumes directories match nonroot
  chown -R nonroot:nonroot \
    ${CONFIG_DIR} \
    /etc/btc-rpc-explorer \
    /app
  echo "Enforced ownership of ${CONFIG_DIR} to nonroot:nonroot"
  
  ## Make sure volume permissions are correct
  chmod -R go=rX,u=rwX \
    ${CONFIG_DIR} \
    /etc/btc-rpc-explorer \
    /app
  echo "Enforced permissions for ${CONFIG_DIR} to go=rX & u=rwX"

  ## Export to the rest of the bash script
  export PUID
  export PGID

}

##############################################################################
## Display TOR torrc config in log
##############################################################################
echo_config(){
  echo -e "\\n====================================- START ${EXP_CONFIG_FILE} -====================================\\n"
  cat $EXP_CONFIG_FILE
  echo -e "\\n=====================================- END ${EXP_CONFIG_FILE} -=====================================\\n"
}

##############################################################################
## TEMPLATE CONFIG
## Template config file based on environmental variations
##############################################################################
template_config(){

  ## Optional logging
  if [[ -n "${DEBUGGER}" ]]; then
    sed -i "/#DEBUG=.*/c\DEBUG=${DEBUGGER}" $EXP_CONFIG_FILE
    echo "Updated debug setting..."
  fi

  ## The explorer base url
  if [[ -n "${BASEURL}" ]]; then
    sed -i "/#BTCEXP_BASEURL=.*/c\BTCEXP_BASEURL=${BASEURL}" $EXP_CONFIG_FILE
    echo "Updated baseurl..."
  fi

  ## The active coin
  if [[ -n "${COIN}" ]]; then
    sed -i "/#BTCEXP_COIN=.*/c\BTCEXP_COIN=${COIN}" $EXP_CONFIG_FILE
    echo "Updated coin..."
  fi

  ## Explorer host IP for binding
  if [[ -n "${HOST}" ]]; then
    sed -i "/#BTCEXP_HOST=.*/c\BTCEXP_HOST=${HOST}" $EXP_CONFIG_FILE
    echo "Updated explorer host IP for binding..."
  fi

  ## Explorer host port for binding
  if [[ -n "${PORT}" ]]; then
    sed -i "/#BTCEXP_PORT=.*/c\BTCEXP_PORT=${PORT}" $EXP_CONFIG_FILE
    echo "Updated explorer host port for binding..."
  fi

  ## Bitcoin core RPC IP address
  if [[ -n "${BITCOIND_HOST}" ]]; then
    sed -i "/#BTCEXP_BITCOIND_HOST=.*/c\BTCEXP_BITCOIND_HOST=${BITCOIND_HOST}" $EXP_CONFIG_FILE
    echo "Updated bitcoin core rpc host IP..."
  fi

  ## Bitcoin core RPC port
  if [[ -n "${BITCOIND_PORT}" ]]; then
    sed -i "/#BTCEXP_BITCOIND_PORT=.*/c\BTCEXP_BITCOIND_PORT=${BITCOIND_PORT}" $EXP_CONFIG_FILE
    echo "Updated bitcoin core rpc port..."
  fi

  ## Bitcoin core RPC username
  if [[ -n "${BITCOIND_USER}" ]]; then
    sed -i "/#BTCEXP_BITCOIND_USER=.*/c\BTCEXP_BITCOIND_USER=${BITCOIND_USER}" $EXP_CONFIG_FILE
    echo "Updated bitcoin core rpc username..."
  fi

  ## Bitcoin core RPC password
  if [[ -n "${BITCOIND_PASS}" ]]; then
    sed -i "/#BTCEXP_BITCOIND_PASS=.*/c\BTCEXP_BITCOIND_PASS=${BITCOIND_PASS}" $EXP_CONFIG_FILE
    echo "Updated bitcoin core rpc password..."
  fi

  ## Bitcoin core RPC cookie location
  if [[ -n "${BITCOIND_COOKIE}" ]]; then
    sed -i "/#BTCEXP_BITCOIND_COOKIE=.*/c\BTCEXP_BITCOIND_COOKIE=${BITCOIND_COOKIE}" $EXP_CONFIG_FILE
    echo "Updated bitcoin core rpc cookie location..."
  fi

  ## Bitcoin core RPC timeout on call
  if [[ -n "${BITCOIND_RPC_TIMEOUT}" ]]; then
    sed -i "/#BTCEXP_BITCOIND_RPC_TIMEOUT=.*/c\BTCEXP_BITCOIND_RPC_TIMEOUT=${BITCOIND_RPC_TIMEOUT}" $EXP_CONFIG_FILE
    echo "Updated bitcoin core rpc timeout..."
  fi

  ## Bitcoin API to use when looking up tx lists and balances
  if [[ -n "${ADDRESS_API}" ]]; then
    sed -i "/#BTCEXP_ADDRESS_API=.*/c\BTCEXP_ADDRESS_API=${ADDRESS_API}" $EXP_CONFIG_FILE
    echo "Updated address api for tx lists and balances..."
  fi

  ## Optional Electrum Protocol Servers
  if [[ -n "${ELECTRUM_SERVERS}" ]]; then
    sed -i "/#BTCEXP_ELECTRUM_SERVERS=.*/c\BTCEXP_ELECTRUM_SERVERS=${ELECTRUM_SERVERS}" $EXP_CONFIG_FILE
    echo "Updated optional Electrum Protocol Servers..."
  fi

  if [[ -n "${ELECTRUM_TXINDEX}" ]]; then
    sed -i "/#BTCEXP_ELECTRUM_TXINDEX=.*/c\BTCEXP_ELECTRUM_TXINDEX=${ELECTRUM_TXINDEX}" $EXP_CONFIG_FILE
    echo "Updated optional Electrum TX Index..."
  fi

  ## Number of concurrent RPC requests
  if [[ -n "${RPC_CONCURRENCY}" ]]; then
    sed -i "/#BTCEXP_RPC_CONCURRENCY=.*/c\BTCEXP_RPC_CONCURRENCY=${RPC_CONCURRENCY}" $EXP_CONFIG_FILE
    echo "Updated Bitcoin Core api concurrency..."
  fi

  ## Disable app's in-memory RPC caching to reduce memory usage
  if [[ -n "${NO_INMEMORY_RPC_CACHE}" ]]; then
    sed -i "/#BTCEXP_NO_INMEMORY_RPC_CACHE=.*/c\BTCEXP_NO_INMEMORY_RPC_CACHE=${NO_INMEMORY_RPC_CACHE}" $EXP_CONFIG_FILE
    echo "Updated in-memory caching option..."
  fi

  ## Optional redis server for RPC caching
  if [[ -n "${REDIS_HOST}" ]]; then
    sed -i "/#BTCEXP_REDIS_URL=.*/c\BTCEXP_REDIS_URL=redis://${REDIS_HOST}:${REDIS_PORT}" $EXP_CONFIG_FILE
    echo "Updated redis server location..."
  fi

  ## Cookie hash
  if [[ -n "${COOKIE_SECRET}" ]]; then
    sed -i "/#BTCEXP_COOKIE_SECRET=.*/c\BTCEXP_COOKIE_SECRET=${COOKIE_SECRET}" $EXP_CONFIG_FILE
    echo "Updated cookie secret..."
  fi

  ## Whether public-demo aspects of the site are active
  if [[ -n "${DEMO}" ]]; then
    sed -i "/#BTCEXP_DEMO=.*/c\BTCEXP_DEMO=${DEMO}" $EXP_CONFIG_FILE
    echo "Updated demo setting..."
  fi

  ## Set to false to enable resource-intensive features
  if [[ -n "${SLOW_DEVICE_MODE}" ]]; then
    sed -i "/#BTCEXP_SLOW_DEVICE_MODE=.*/c\BTCEXP_SLOW_DEVICE_MODE=${SLOW_DEVICE_MODE}" $EXP_CONFIG_FILE
    echo "Updated slow device mode..."
  fi

  ## Privacy mode disables: Exchange-rate queries, IP-geolocation queries
  if [[ -n "${PRIVACY_MODE}" ]]; then
    sed -i "/#BTCEXP_PRIVACY_MODE=.*/c\BTCEXP_PRIVACY_MODE=${PRIVACY_MODE}" $EXP_CONFIG_FILE
    echo "Updated privacy mode..."
  fi

  ## Don't request currency exchange rates
  if [[ -n "${NO_RATES}" ]]; then
    sed -i "/#BTCEXP_NO_RATES=.*/c\BTCEXP_NO_RATES=${NO_RATES}" $EXP_CONFIG_FILE
    echo "Updated no rates setting..."
  fi

  ## Password protection for site via basic auth (enter any username, only the password is checked)
  if [[ -n "${BASIC_AUTH_PASSWORD}" ]]; then
    sed -i "/#BTCEXP_BASIC_AUTH_PASSWORD=.*/c\BTCEXP_BASIC_AUTH_PASSWORD=${BASIC_AUTH_PASSWORD}" $EXP_CONFIG_FILE
    echo "Updated basic authentication password..."
  fi

  ## Password protection for site via basic auth (enter any username, only the password is checked)
  if [[ -n "${SSO_TOKEN_FILE}" ]]; then
    sed -i "/#BTCEXP_SSO_TOKEN_FILE=.*/c\BTCEXP_SSO_TOKEN_FILE=${SSO_TOKEN_FILE}" $EXP_CONFIG_FILE
    echo "Updated SSO token location..."
  fi

  ## URL of an optional external SSO provider
  if [[ -n "${SSO_LOGIN_REDIRECT_URL}" ]]; then
    sed -i "/#BTCEXP_SSO_LOGIN_REDIRECT_URL=.*/c\BTCEXP_SSO_LOGIN_REDIRECT_URL=${SSO_LOGIN_REDIRECT_URL}" $EXP_CONFIG_FILE
    echo "Updated SSO redirect url..."
  fi

  ## Enable to allow access to all RPC methods
  if [[ -n "${RPC_ALLOWALL}" ]]; then
    sed -i "/#BTCEXP_RPC_ALLOWALL=.*/c\BTCEXP_RPC_ALLOWALL=${RPC_ALLOWALL}" $EXP_CONFIG_FILE
    echo "Updated allow all RPC methods..."
  fi

  ## Custom RPC method blacklist
  if [[ -n "${RPC_BLACKLIST}" ]]; then
    sed -i "/#BTCEXP_RPC_BLACKLIST=.*/c\BTCEXP_RPC_BLACKLIST=${RPC_BLACKLIST}" $EXP_CONFIG_FILE
    echo "Updated RPC method blacklist..."
  fi

  ## Google analytics API key
  if [[ -n "${GANALYTICS_TRACKING}" ]]; then
    sed -i "/#BTCEXP_GANALYTICS_TRACKING=.*/c\BTCEXP_GANALYTICS_TRACKING=${GANALYTICS_TRACKING}" $EXP_CONFIG_FILE
    echo "Updated Google analytics tracking key..."
  fi

  ## Sentry URL and API key
  if [[ -n "${SENTRY_URL}" ]]; then
    sed -i "/#BTCEXP_SENTRY_URL=.*/c\BTCEXP_SENTRY_URL=${SENTRY_URL}" $EXP_CONFIG_FILE
    echo "Updated Sentry URL API and key..."
  fi

  ## IP Stack API Key
  if [[ -n "${IPSTACK_APIKEY}" ]]; then
    sed -i "/#BTCEXP_IPSTACK_APIKEY=.*/c\BTCEXP_IPSTACK_APIKEY=${IPSTACK_APIKEY}" $EXP_CONFIG_FILE
    echo "Updated IP Stack API key..."
  fi

  ## Map Box API Key
  if [[ -n "${MAPBOX_APIKEY}" ]]; then
    sed -i "/#BTCEXP_MAPBOX_APIKEY=.*/c\BTCEXP_MAPBOX_APIKEY=${MAPBOX_APIKEY}" $EXP_CONFIG_FILE
    echo "Updated Map Box API key..."
  fi

  ## Optional value for a directory for filesystem caching
  if [[ -n "${FILESYSTEM_CACHE_DIR}" ]]; then
    sed -i "/#BTCEXP_FILESYSTEM_CACHE_DIR=.*/c\BTCEXP_FILESYSTEM_CACHE_DIR=${FILESYSTEM_CACHE_DIR}" $EXP_CONFIG_FILE
    echo "Updated cache directory..."
  fi

  ## Optional analytics
  if [[ -n "${PLAUSIBLE_ANALYTICS_DOMAIN}" ]] && [[ -n "${PLAUSIBLE_ANALYTICS_SCRIPT_URL}" ]]; then
    sed -i "/#BTCEXP_PLAUSIBLE_ANALYTICS_DOMAIN=.*/c\BTCEXP_PLAUSIBLE_ANALYTICS_DOMAIN=${PLAUSIBLE_ANALYTICS_DOMAIN}" $EXP_CONFIG_FILE
    sed -i "/#BTCEXP_PLAUSIBLE_ANALYTICS_SCRIPT_URL=.*/c\BTCEXP_PLAUSIBLE_ANALYTICS_SCRIPT_URL=${PLAUSIBLE_ANALYTICS_SCRIPT_URL}" $EXP_CONFIG_FILE
    echo "Updated Plausible analytics..."
  fi

  ## Optional value for "max_old_space_size"
  if [[ -n "${OLD_SPACE_MAX_SIZE}" ]]; then
    sed -i "/#BTCEXP_OLD_SPACE_MAX_SIZE=.*/c\BTCEXP_OLD_SPACE_MAX_SIZE=${OLD_SPACE_MAX_SIZE}" $EXP_CONFIG_FILE
    echo "Updated max old space..."
  fi

  ## The number of recent blocks to search for transactions when txindex is disabled
  if [[ -n "${NOTXINDEX_SEARCH_DEPTH}" ]]; then
    sed -i "/#BTCEXP_NOTXINDEX_SEARCH_DEPTH=.*/c\BTCEXP_NOTXINDEX_SEARCH_DEPTH=${NOTXINDEX_SEARCH_DEPTH}" $EXP_CONFIG_FILE
    echo "Updated recent block search depth..."
  fi

  ## UI theme
  if [[ -n "${UI_THEME}" ]]; then
    sed -i "/#BTCEXP_UI_THEME=.*/c\BTCEXP_UI_THEME=${UI_THEME}" $EXP_CONFIG_FILE
    echo "Updated UI theme..."
  fi

  ## Set the number of recent blocks shown on the homepage.
  if [[ -n "${UI_HOME_PAGE_LATEST_BLOCKS_COUNT}" ]]; then
    sed -i "/#BTCEXP_UI_HOME_PAGE_LATEST_BLOCKS_COUNT=.*/c\BTCEXP_UI_HOME_PAGE_LATEST_BLOCKS_COUNT=${UI_HOME_PAGE_LATEST_BLOCKS_COUNT}" $EXP_CONFIG_FILE
    echo "Updated recent block count..."
  fi

  ## Set the number of blocks per page on the browse-blocks page.
  if [[ -n "${UI_BLOCKS_PAGE_BLOCK_COUNT}" ]]; then
    sed -i "/#BTCEXP_UI_BLOCKS_PAGE_BLOCK_COUNT=.*/c\BTCEXP_UI_BLOCKS_PAGE_BLOCK_COUNT=${UI_BLOCKS_PAGE_BLOCK_COUNT}" $EXP_CONFIG_FILE
    echo "Updated browse blocks page count..."
  fi

}

##############################################################################
## Initialise docker image
##############################################################################
init(){
  echo -e "\\n====================================- INITIALISING BTC-RPC-EXPLORER -====================================\\n"

  ## Copy config file into bind-volume
  cp /tmp/btc-rpc-explorer.env* ${CONFIG_DIR}
  ## Don't remove tmp files incase we want to overwrite
  echo "Copied .env into ${CONFIG_DIR}..."

  template_config
  echo "Templated config..."

}


##############################################################################
## Main shell script function
##############################################################################
main() {

  ## Initialise container if there is no lock file
  if [[ ! -e $EXP_CONFIG_FILE.lock ]] || $OVERWRITE_CONFIG; then 
    init
    echo "Only run init once. Delete this file to re-init .env templating on container start up." > $EXP_CONFIG_FILE.lock
  else
    echo ".env already configured. Skipping config templating..."
  fi

  map_user

  ## Symbolic link config file
  ln -s ${EXP_CONFIG_FILE} /etc/btc-rpc-explorer/.env

  ## Echo config to log if set true
  if $LOG_CONFIG; then
    echo_config
  fi
}

## Call main function
main

echo -e "\\n====================================- STARTING BTC-RPC-EXPLORER -====================================\\n"
echo ''

## Execute dockerfile CMD as nonroot alternate gosu
su-exec "${PUID}:${PGID}" "$@"