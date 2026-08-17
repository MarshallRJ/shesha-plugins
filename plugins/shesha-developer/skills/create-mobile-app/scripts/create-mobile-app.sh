#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

prompt() {
  local var_name="$1"
  local label="$2"
  local hint="$3"
  local validator="$4"
  local secret="${5:-false}"

  while true; do
    echo -e "${CYAN}${label}${NC}"
    [[ -n "$hint" ]] && echo -e "  ${YELLOW}(${hint})${NC}"
    if [[ "$secret" == "true" ]]; then
      read -r -s -p "> " value
      echo
    else
      read -r -p "> " value
    fi

    if eval "$validator" "$value"; then
      printf -v "$var_name" '%s' "$value"
      echo -e "  ${GREEN}✓ OK${NC}"
      break
    else
      echo -e "  ${RED}✗ Invalid — please try again${NC}"
    fi
    echo
  done
}

validate_name() {
  [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]
}

validate_namespace() {
  [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*\.)+[a-zA-Z]{2,}$ ]]
}

validate_base_url() {
  [[ "$1" =~ ^/ ]]
}

validate_full_url() {
  [[ "$1" =~ ^https?:// ]]
}

validate_nonempty() {
  [[ -n "$1" ]]
}

validate_email() {
  [[ "$1" =~ ^[^@]+@[^@]+\.[^@]+$ ]]
}

validate_path() {
  [[ -n "$1" ]]
}

echo
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Shesha Mobile App Generator          ${NC}"
echo -e "${CYAN}========================================${NC}"
echo

prompt APP_NAME \
  "App name" \
  "alphanumeric and hyphens, e.g. my-app" \
  validate_name

prompt NAMESPACE \
  "Namespace (package identifier)" \
  "domain format, e.g. com.mycompany.app" \
  validate_namespace

prompt BASE_URL \
  "BASE_URL (API base path)" \
  "starts with /, e.g. /" \
  validate_base_url

prompt HOME_URL \
  "HOME_URL (home screen URL)" \
  "full URL, e.g. https://myapp.com" \
  validate_full_url

prompt ONBOARD_URL \
  "ONBOARD_URL (onboarding URL)" \
  "full URL, e.g. https://myapp.com/onboard" \
  validate_full_url

prompt GOOGLE_MAPS_KEY \
  "Google Maps API key" \
  "non-empty string" \
  validate_nonempty

prompt MAPBOX_ACCESS_KEY \
  "Mapbox access token" \
  "non-empty string" \
  validate_nonempty

prompt NPM_USER \
  "npm username" \
  "your npm registry username" \
  validate_nonempty

prompt NPM_PASS \
  "npm password / token" \
  "input is hidden" \
  validate_nonempty \
  true

prompt NPM_EMAIL \
  "npm email" \
  "valid email address" \
  validate_email

prompt SDK_DIR \
  "SDK directory path" \
  "absolute or relative path, e.g. /path/to/sdk or /" \
  validate_path

echo
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "  name            = ${APP_NAME}"
echo -e "  namespace       = ${NAMESPACE}"
echo -e "  BASE_URL        = ${BASE_URL}"
echo -e "  HOME_URL        = ${HOME_URL}"
echo -e "  ONBOARD_URL     = ${ONBOARD_URL}"
echo -e "  GOOGLE_MAPS_KEY = ${GOOGLE_MAPS_KEY}"
echo -e "  MAPBOX_ACCESS_KEY = ${MAPBOX_ACCESS_KEY}"
echo -e "  npmUser         = ${NPM_USER}"
echo -e "  npmPass         = ****"
echo -e "  npmEmail        = ${NPM_EMAIL}"
echo -e "  sdkDir          = ${SDK_DIR}"
echo

read -r -p "Proceed? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo
echo -e "${CYAN}Running npx sheshamobile-create ...${NC}"
echo

npx sheshamobile-create \
  "name=${APP_NAME}" \
  "namespace=${NAMESPACE}" \
  "BASE_URL=${BASE_URL}" \
  "HOME_URL=${HOME_URL}" \
  "ONBOARD_URL=${ONBOARD_URL}" \
  "GOOGLE_MAPS_KEY=${GOOGLE_MAPS_KEY}" \
  "MAPBOX_ACCESS_KEY=${MAPBOX_ACCESS_KEY}" \
  "npmUser=${NPM_USER}" \
  "npmPass=${NPM_PASS}" \
  "npmEmail=${NPM_EMAIL}" \
  "sdkDir=${SDK_DIR}"

echo
echo -e "${GREEN}Done!${NC}"
