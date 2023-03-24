# if the build has previously run successfully for this hash, we don't want to save another cache (which then would never be used, and would consume time and storage space)
if [ -f ~/.gradle/caches/last_success_hash ]; then
  if cmp -s ~/.gradle/caches/last_success_hash /tmp/git_last_hash ; then
    echo "Cache was saved after a previously successful build for the latest build file changes, creating another cache entry for the failed state is unnecessary."
    # emulate successful build (so that save is skipped)
    echo "success" > /tmp/build_status
  else
    echo "failure" > /tmp/build_status
  fi
else
  echo "failure" > /tmp/build_status
fi
