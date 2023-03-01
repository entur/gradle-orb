# find build files
buildFiles=$(find . -name "${PARAM_CHECKSUM_FILES}" | sed 's/.*/&/' | tr '\n' ' ')
# get the latest commit which modified the build files
lastHash=$(git log -n 1 --pretty=format:%H HEAD -- $buildFiles)
# do a check that there actually is more than one revision
if [ -n "$lastHash" ] && [ $(git rev-list --count HEAD) -gt "1" ]; then
  # check which previous revision was the last to modify the build files
  lastPreviousFirstHash=$(git log -n 1 --pretty=format:%H HEAD~1 -- $buildFiles)
  if [ "$lastPreviousFirstHash" = "$lastHash" ]; then
    echo "Build files did not update last commit"
  else
    echo "Build files did update last commit"
  fi
  if [ -n "$lastPreviousFirstHash" ] && [ "$(git rev-list --count $lastPreviousFirstHash)" -gt "1" ]; then
    lastPreviousSecondHash="$(git log -n 1 --pretty=format:%H $lastPreviousFirstHash~1 -- $buildFiles)"
    echo "Second last time build files updated at $lastPreviousSecondHash"
    if [ -n "$lastPreviousSecondHash" ] && [ "$(git rev-list --count $lastPreviousSecondHash)" -gt "1" ]; then
      lastPreviousThirdHash="$(git log -n 1 --pretty=format:%H $lastPreviousSecondHash~1 -- $buildFiles)"
      if [ -n "$lastPreviousThirdHash" ]; then
        echo "Third last time build files updated at $lastPreviousThirdHash"
      fi
    fi
  fi
else
  echo "Build files did update last commit"
fi
if [ -z "$lastPreviousFirstHash" ]; then
  lastPreviousFirstHash=$lastHash
fi
if [ -z "$lastPreviousSecondHash" ]; then
  lastPreviousSecondHash=$lastHash
fi
if [ -z "$lastPreviousThirdHash" ]; then
  lastPreviousThirdHash=$lastHash
fi
echo "$lastPreviousFirstHash" > /tmp/git_last_previous_first_hash
echo "$lastPreviousSecondHash" > /tmp/git_last_previous_second_hash
echo "$lastPreviousThirdHash" > /tmp/git_last_previous_third_hash
echo "$lastHash" > /tmp/git_last_hash
echo "success" > /tmp/build_status_success
echo "failure" > /tmp/build_status_failure
