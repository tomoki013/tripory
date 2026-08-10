#!/bin/bash
set -euo pipefail

# Release simulator builds stay available with an unset interstitial ID. A real
# archive must be fully configured and must never contain Google's test IDs.
if [[ "${CONFIGURATION:-}" != "Release" || "${ACTION:-}" != "install" ]]; then
  exit 0
fi

values=("${ADMOB_APP_ID:-}" "${ADMOB_BANNER_AD_UNIT_ID:-}" "${ADMOB_INTERSTITIAL_AD_UNIT_ID:-}")
labels=("ADMOB_APP_ID" "ADMOB_BANNER_AD_UNIT_ID" "ADMOB_INTERSTITIAL_AD_UNIT_ID")
for index in 0 1 2; do
  value="${values[$index]}"
  if [[ -z "$value" ]]; then
    echo "error: ${labels[$index]} is required for a Release archive."
    exit 1
  fi
  if [[ "$value" == *"3940256099942544"* ]]; then
    echo "error: ${labels[$index]} contains a Google test ID in Release."
    exit 1
  fi
done
