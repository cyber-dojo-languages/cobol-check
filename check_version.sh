#!/usr/bin/env bash
set -Eeu

readonly MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly REGEX="image_name\": \"(.*)\""
readonly JSON=`cat ${MY_DIR}/docker/image_name.json`
[[ ${JSON} =~ ${REGEX} ]]
readonly IMAGE_NAME="${BASH_REMATCH[1]}"

# Written down here so the gate fails when a rebuild picks up a different
# cobol-check. Reading it from the image instead would compare the image
# against itself and pass whatever the move brought in.
readonly EXPECTED=0.2

# Asks the installed jar at the path a kata's cyber-dojo.sh runs it from, so
# the gate also fails when the jar is not there. Matching on the leading
# major.minor lets a patch release through and stops only a minor or major move.
readonly ACTUAL=$(docker run --rm ${IMAGE_NAME} sh -c 'java -jar /opt/cobol-check/cobol-check.jar --version 2>&1')

if echo "${ACTUAL}" | grep -q "ersion ${EXPECTED}"; then
  echo "VERSION CONFIRMED as ${EXPECTED}"
else
  echo "VERSION EXPECTED: ${EXPECTED}"
  echo "VERSION   ACTUAL: ${ACTUAL}"
  exit 42
fi
