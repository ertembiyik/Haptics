#!/bin/sh
set -eu

if [ -z "${GOOGLE_SERVICE_INFO_PLIST_SOURCE:-}" ]; then
  echo "error: GOOGLE_SERVICE_INFO_PLIST_SOURCE is not set for ${TARGET_NAME}."
  exit 1
fi

if [ ! -f "${GOOGLE_SERVICE_INFO_PLIST_SOURCE}" ]; then
  echo "error: Missing GoogleService-Info.plist for ${TARGET_NAME}: ${GOOGLE_SERVICE_INFO_PLIST_SOURCE}"
  echo "error: Download the matching Firebase plist and place it at that path before building."
  exit 1
fi

destination_dir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "${destination_dir}"
cp "${GOOGLE_SERVICE_INFO_PLIST_SOURCE}" "${destination_dir}/GoogleService-Info.plist"
