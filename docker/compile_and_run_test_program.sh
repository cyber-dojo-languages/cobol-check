#!/bin/sh

# cobol-check calls this once per program under test, passing the test program
# it has just generated: the learner's program with their test cases merged
# into it. It compiles that and runs it, and what the run prints on stdout is
# the TESTSUITE report, per test case and then counted. cobol-check relays
# that report to its own stdout.
#
# Nothing else goes through cobol-check, for two reasons. It ignores the exit
# status of this script, so a test program that will not compile, or that
# stops before reporting, would leave nothing behind but whatever it printed,
# and another program's report could then be the only summary in the output.
# And it drops the last character of what it relays from stderr, so a
# learner's debug line ending in 42 would arrive ending in 4. So stderr, and
# the reason any test program did not finish, are kept in files below, which
# cyber-dojo.sh prints after cobol-check exits, and fails the run if the
# second is not empty.
#
# cobol-check's own linux script cannot be used: it has CRLF line endings, so
# its #!/bin/sh names an interpreter that does not exist.

readonly TEST_PROGRAM="$1"
readonly REPORT=/tmp/cobol-check/report
readonly STDERR=/tmp/cobol-check/stderr-of-test-programs
readonly NOT_FINISHED=/tmp/cobol-check/why-a-test-program-did-not-finish

cd "$(dirname "${TEST_PROGRAM}")"

# cyber-dojo.sh has already compiled the learner's own programs, so a compile
# error here comes from a test case, such as a misspelled field name. cobc
# names the generated file, but quotes the offending line beside the error.
#
# -debug turns on cobc's runtime checks, so a subscript out of range, for
# example, stops the test program with a message naming the field, instead of
# quietly reading or writing whatever memory lies beyond the table.
if ! cobc -x -debug -o test_program "${TEST_PROGRAM}" 2> /tmp/cobol-check/cobc.stderr; then
  cat /tmp/cobol-check/cobc.stderr >> "${NOT_FINISHED}"
  echo 'A test case did not compile.' >> "${NOT_FINISHED}"
  exit 1
fi

# The test program sets its exit status to 4 when a test case fails and leaves
# it at 0 when none do, and it ends by counting the test cases it ran. Any
# other status, or no count, means it stopped before finishing, for example at
# a STOP RUN or a runtime error in the program under test.
./test_program > "${REPORT}" 2>> "${STDERR}"
readonly STATUS=$?
cat "${REPORT}"
if [ "${STATUS}" != 0 ] && [ "${STATUS}" != 4 ]; then
  echo "A test program stopped with exit status ${STATUS} before it finished." >> "${NOT_FINISHED}"
elif ! grep -q 'TEST CASES WERE EXECUTED' "${REPORT}"; then
  echo 'A test program stopped before it reported its test cases.' >> "${NOT_FINISHED}"
fi
