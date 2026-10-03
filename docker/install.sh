#!/bin/sh -eu

# cobol-check is a java program. It reads a COBOL program and its test suites,
# merges them into one test program, and has cobc compile and run that. So the
# image needs a JRE beside the GnuCOBOL the base image provides.

readonly GNUCOBOL_VERSION=$(sed --quiet 's/.*"gnucobol":"\([0-9.]*\)".*/\1/p' /versions.json)

if [ -z "${GNUCOBOL_VERSION}" ]; then
  echo '/versions.json has no gnucobol property' >&2
  exit 1
fi

apk update

# Alpine packages each java major version on its own, as
# openjdk<major>-jre-headless, so the newest is resolved from the index rather
# than written down here, where it would pin the image to whichever release
# was current when someone last edited this file. The sort is a version sort
# so that a future 100 comes after 99 instead of before it.
readonly JRE_PACKAGE=$(apk search --quiet openjdk \
  | grep -E '^openjdk[0-9]+-jre-headless$' \
  | sort --version-sort \
  | tail -n 1)

if [ -z "${JRE_PACKAGE}" ]; then
  echo 'Found no openjdk<major>-jre-headless package in the alpine index' >&2
  exit 1
fi

apk add "${JRE_PACKAGE}"

# cobol-check publishes each release as a zip committed to its repository's
# build/distributions directory, on its default branch, rather than as a
# GitHub release. Its GitHub releases stop at a 2021 pre-release. So the newest
# is resolved by listing that directory and taking the highest version.
readonly REPO=openmainframeproject/cobol-check
readonly BRANCH=Developer
readonly LISTING_URL="https://api.github.com/repos/${REPO}/contents/build/distributions?ref=${BRANCH}"

readonly COBOL_CHECK_VERSION=$(wget -q -O - "${LISTING_URL}" \
  | grep -o '"name": *"cobol-check-[0-9.]*\.zip"' \
  | sed 's/.*cobol-check-\([0-9.]*\)\.zip"/\1/' \
  | sort --version-sort \
  | tail -n 1)

if [ -z "${COBOL_CHECK_VERSION}" ]; then
  echo "Found no cobol-check-<version>.zip listed at ${LISTING_URL}" >&2
  exit 1
fi

readonly ZIP_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/build/distributions/cobol-check-${COBOL_CHECK_VERSION}.zip"
wget -q -O /tmp/cobol-check.zip "${ZIP_URL}"

# Only the jar is kept from the zip. Its config.properties writes generated
# files into the kata, and its linux script has CRLF line endings and cannot
# be run, so this image supplies its own of each.
mkdir -p /opt/cobol-check/scripts
unzip -q -o /tmp/cobol-check.zip "bin/cobol-check-${COBOL_CHECK_VERSION}.jar" -d /tmp/cobol-check-zip
mv "/tmp/cobol-check-zip/bin/cobol-check-${COBOL_CHECK_VERSION}.jar" /opt/cobol-check/cobol-check.jar
rm -rf /tmp/cobol-check.zip /tmp/cobol-check-zip

mv config.properties /opt/cobol-check/config.properties
mv compile_and_run_test_program.sh /opt/cobol-check/scripts/compile_and_run_test_program.sh
chmod 0644 /opt/cobol-check/cobol-check.jar /opt/cobol-check/config.properties
chmod 0755 /opt/cobol-check/scripts/compile_and_run_test_program.sh

# Read by check_version.sh. Each tool is asked rather than an index, so the
# numbers recorded are ones the image can run, and running cobol-check here
# also proves the jar starts under this JRE before any kata does.
readonly JAVA_VERSION=$(java -version 2>&1 | sed --quiet '1s/.*version "\([0-9][0-9.]*\)".*/\1/p')
readonly RAN_VERSION=$(java -jar /opt/cobol-check/cobol-check.jar --version 2>&1 \
  | sed --quiet 's/.*[Vv]ersion \([0-9][0-9.]*[0-9]\).*/\1/p' | head -n 1)

if [ "${RAN_VERSION}" != "${COBOL_CHECK_VERSION}" ]; then
  echo "cobol-check reports version '${RAN_VERSION}', expected ${COBOL_CHECK_VERSION}" >&2
  exit 1
fi

echo "{\"gnucobol\":\"${GNUCOBOL_VERSION}\",\"java\":\"${JAVA_VERSION}\",\"cobol_check\":\"${COBOL_CHECK_VERSION}\"}" > /versions.json

rm -rf /var/cache/apk/*
