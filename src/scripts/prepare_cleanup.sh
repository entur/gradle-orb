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
  echo "No new cache entry will be created"
  GRADLE_PROPERTIES="$GRADLE_DIRECTORY/gradle.properties"
  echo "org.gradle.cache.cleanup=false" >> $GRADLE_PROPERTIES
else
  gradleWrapperMainVersion="$(cat gradle/wrapper/gradle-wrapper.properties | grep distributionUrl | cut -d'-' -f 2 | cut -d'.' -f 1)"
  if [ "$gradleWrapperMainVersion" -ge "8" ]; then
    # for gradle 8+ - https://docs.gradle.org/current/userguide/init_scripts.html#sec:using_an_init_script
    GRADLE_INIT_DIRECTORY="$GRADLE_DIRECTORY/init.d"
    if [[ ! -e $GRADLE_INIT_DIRECTORY ]]; then
      mkdir -p $GRADLE_INIT_DIRECTORY
    fi
    echo "beforeSettings { settings -> settings.caches {downloadedResources.removeUnusedEntriesAfterDays = 1}}" > $GRADLE_INIT_DIRECTORY/cleanup.gradle
  fi
fi
