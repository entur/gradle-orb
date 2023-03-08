echo "success" > /tmp/build_status
# should the cache be cleaned?

GRADLE_DIRECTORY="$HOME/.gradle"
GRADLE_CACHE_DIRECTORY="$GRADLE_DIRECTORY/caches"
if [[ ! -e $GRADLE_CACHE_DIRECTORY ]]; then
  echo "No cache directory, so no cleanup needed"
  exit 0
fi

if [ -f "$GRADLE_CACHE_DIRECTORY/last_success_hash" ]; then
  if cmp -s "$GRADLE_CACHE_DIRECTORY/last_success_hash" /tmp/git_last_hash ; then
    echo "Cache does not need cleanup"
    exit 0
  fi
fi


# this is the first successful build with this particular set of build files
echo "Clean up cache for gradle"

GRADLE_PROPERTIES="$GRADLE_DIRECTORY/gradle.properties"
echo "org.gradle.cache.cleanup=true" >> $GRADLE_PROPERTIES

find $GRADLE_CACHE_DIRECTORY -maxdepth 2 -type f -name "gc.properties" -exec touch  -a -m -t 201512180130.09 "{}" \;

touch /tmp/settings.gradle
cat > /tmp/cleanup.gradle << 'endmsg'
System.out.println("Gradle script execution.")
endmsg
echo "A new cache entry will be created, deleting files not accessed during this build.."
./gradlew --stop
./gradlew -b /tmp/cleanup.gradle -Pdeadline=/tmp/git_last_hash --no-daemon

