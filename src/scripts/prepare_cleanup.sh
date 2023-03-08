touch /tmp/git_last_hash
GRADLE_DIRECTORY="$HOME/.gradle"
if [[ ! -e $GRADLE_DIRECTORY ]]; then
  mkdir -p $GRADLE_DIRECTORY
fi
GRADLE_CACHE_DIRECTORY="$GRADLE_DIRECTORY/caches"
if [[ ! -e $GRADLE_CACHE_DIRECTORY ]]; then
  mkdir -p $GRADLE_CACHE_DIRECTORY
fi
echo "Folder sizes:"
du -h --max-depth=1 ~/.gradle/caches
if cmp -s "/tmp/git_last_previous_first_hash" "/tmp/git_last_hash" ; then
  echo "No new cache entry will be created, build files did not change."
  GRADLE_PROPERTIES="$GRADLE_DIRECTORY/gradle.properties"
fi

# project might contain multiple gradle build commands
# so do not clean up cache yet
echo "org.gradle.cache.cleanup=false" >> $GRADLE_PROPERTIES

