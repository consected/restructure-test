#!/bin/bash
# Return the failing specs log from the parallel test suite
# Add 'less' as the first argument to interactively use less to page the results
# Other arguments may specify other pagers / viewers, e.g. `more` - they must be available in the container
# otherwise pipe the result locally, such as
#     ./get-failing-specs.sh | more

cd -P -- "$(dirname -- "$0")"

if [ "$1" == 'less' ]; then
  ./container-actions.sh interactive less -r output/restructure/tmp/failing_specs.log
elif [ "$1" ]; then
  ./container-actions.sh interactive $@ output/restructure/tmp/failing_specs.log
else
  ./container-actions.sh cat output/restructure/tmp/failing_specs.log
fi
