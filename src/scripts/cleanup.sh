echo "success" > /tmp/build_status
# should the cache be cleaned?

GRADLE_DIRECTORY="$HOME/.gradle"
GRADLE_CACHE_DIRECTORY="$GRADLE_DIRECTORY/caches"
if [[ ! -e $GRADLE_CACHE_DIRECTORY ]]; then
  echo "No cache directory, so no cleanup needed"
  exit 0
fi

if [[ -f /tmp/empty_cache ]]; then
  echo "No cache was restored, so no cleanup needed"
  # clean up
  rm /tmp/empty_cache
  exit 0
fi

if [ -f "$GRADLE_CACHE_DIRECTORY/last_success_hash" ]; then
  if cmp -s "$GRADLE_CACHE_DIRECTORY/last_success_hash" /tmp/git_last_hash ; then
    echo "Cache does not need cleanup"
    exit 0
  fi
fi

# cd into directory so that gradlew command is available
if [ -n "${PARAM_APP_DIRECTORY}" ]; then
  cd "$PARAM_APP_DIRECTORY" || exit 1
fi

# is this gradle 8+?
gradleWrapperMainVersion="$(cat gradle/wrapper/gradle-wrapper.properties | grep distributionUrl | cut -d'-' -f 2 | cut -d'.' -f 1)"
if [ "$gradleWrapperMainVersion" -ge "8" ]; then
    # make it so the built-in GC runs

    # https://docs.gradle.org/current/userguide/init_scripts.html#sec:using_an_init_script
    GRADLE_INIT_DIRECTORY="$GRADLE_DIRECTORY/init.d"
    if [[ ! -e $GRADLE_INIT_DIRECTORY ]]; then
      mkdir -p $GRADLE_INIT_DIRECTORY
    fi
    
    gradleWrapperMinorVersion="$(cat gradle/wrapper/gradle-wrapper.properties | grep distributionUrl | cut -d'-' -f 2 | cut -d'.' -f 2)"
    if [ "$gradleWrapperMainVersion" -gt "8" ] || [ "$gradleWrapperMinorVersion" -ge "8" ]; then
      echo "Clean cache for gradle >= 8.8"

      echo -e "beforeSettings { settings -> settings.caches {\nbuildCache.removeUnusedEntriesAfterDays = 1\ndownloadedResources.removeUnusedEntriesAfterDays = 1\nreleasedWrappers.removeUnusedEntriesAfterDays = 1\nsnapshotWrappers.removeUnusedEntriesAfterDays = 1\ncreatedResources.removeUnusedEntriesAfterDays = 1\ncleanup = Cleanup.ALWAYS\n}}" > $GRADLE_INIT_DIRECTORY/cache-settings.gradle

    else
      echo "Clean cache for gradle 8.0 - 8.7"
      # https://docs.gradle.org/8.0-rc-3/userguide/directory_layout.html#dir:gradle_user_home:configure_cache_cleanup
      echo -e "beforeSettings { settings -> settings.caches {\ndownloadedResources.removeUnusedEntriesAfterDays = 1\nreleasedWrappers.removeUnusedEntriesAfterDays = 1\nsnapshotWrappers.removeUnusedEntriesAfterDays = 1\ncreatedResources.removeUnusedEntriesAfterDays = 1\ncleanup = Cleanup.ALWAYS\n}}" > $GRADLE_INIT_DIRECTORY/cache-settings.gradle
    fi
    
    cat  $GRADLE_INIT_DIRECTORY/cache-settings.gradle

    # work in subdirectory due to https://github.com/gradle/gradle/issues/29377
    GRADLE_ORB_TEMP_DIRECTORY=/tmp/gradle-orb

    if [[ ! -e $GRADLE_ORB_TEMP_DIRECTORY ]]; then
      rm -rf $GRADLE_ORB_TEMP_DIRECTORY
    fi
    mkdir $GRADLE_ORB_TEMP_DIRECTORY
    
    # create dummy build files
    touch $GRADLE_ORB_TEMP_DIRECTORY/settings.gradle
    touch $GRADLE_ORB_TEMP_DIRECTORY/cleanup.gradle
    
    CURRENT_DIRECTORY=$(pwd)
    
    cd $GRADLE_ORB_TEMP_DIRECTORY || exit # exit due to shellcheck
    echo "A new cache entry will be created, cleaning files not accessed during the last 24 hours.."
    $CURRENT_DIRECTORY/gradlew -b cleanup.gradle projects --info --stacktrace 
    # clean up
    rm $GRADLE_INIT_DIRECTORY/cache-settings.gradle
    rm -rf $GRADLE_ORB_TEMP_DIRECTORY
    exit 0
fi
# this is the first successful build with this particular set of build files
echo "Clean up cache for gradle < 8"
touch /tmp/settings.gradle
cat > /tmp/cleanup.gradle << 'endmsg'
import static org.gradle.internal.serialize.BaseSerializerFactory.*
import org.gradle.cache.internal.btree.BTreePersistentIndexedCache
import java.io.FileFilter
import org.gradle.internal.file.impl.DefaultDeleter
import java.nio.file.Files
def containsArtifacts(File parentDirectory, FileFilter fileFilter) {
    File[] files = parentDirectory.listFiles(fileFilter);
    if(files != null && files.length > 0) {
        return true;
    }
    FileFilter dirFilter = {f -> f.isDirectory()};
    File[] dirFiles = parentDirectory.listFiles(dirFilter);
    if(dirFiles != null && dirFiles.length > 0) {
        for(File dirFile : dirFiles) {
            if(containsArtifacts(dirFile, fileFilter)) {
                return true;
            }
        }
    }
    return false;
}
def isDependenciesTouched(File parentDirectory, BTreePersistentIndexedCache<File, Long> j, long deadline, FileFilter fileFilter) {
    Long journalTimestamp = j.get(parentDirectory);
    if(journalTimestamp != null) {
        if(journalTimestamp >= deadline) {
            if(containsArtifacts(parentDirectory, fileFilter)) {
                return true;
            }
        }
        return false;
    }
    long deleted = 0L;
    FileFilter dirFilter = {f -> f.isDirectory()};
    File[] dirFiles = parentDirectory.listFiles(dirFilter);
    if(dirFiles != null && dirFiles.length > 0) {
        for(File dirFile : dirFiles) {
            if(isDependenciesTouched(dirFile, j, deadline, fileFilter)) {
                return true;
            }
        }
    }
    return false;
}
def deleteFromDependencies(File parentDirectory, BTreePersistentIndexedCache<File, Long> j, long deadline, DefaultDeleter deleter, FileFilter fileFilter) {
    Long journalTimestamp = j.get(parentDirectory);
    if(journalTimestamp != null) {
        if(journalTimestamp < deadline) {
            if(containsArtifacts(parentDirectory, fileFilter)) {
                j.remove(parentDirectory)
                deleter.deleteRecursively(parentDirectory);
                File parent = parentDirectory.getParentFile();
                FileFilter siblingFilter = {f -> f.getName().startsWith(parentDirectory.getName())};
                File[] siblings = parent.listFiles(siblingFilter);
                if(siblings != null) {
                    for(File sibling : siblings) {
                        deleter.deleteRecursively(sibling);
                    }
                }
                return 1;
            }
        }
        return 0;
    }
    long deleted = 0L;
    FileFilter dirFilter = {f -> f.isDirectory()};
    File[] dirFiles = parentDirectory.listFiles(dirFilter);
    if(dirFiles != null && dirFiles.length > 0) {
        for(File dirFile : dirFiles) {
            deleted += deleteFromDependencies(dirFile, j, deadline, deleter, fileFilter);
        }
    }
    return deleted;
}
def isBuildCacheTouched(File parentDirectory, BTreePersistentIndexedCache<File, Long> j, long deadline) {
    FileFilter f = {f -> f.isFile() && f.getName().length() == 32};
    File[] fileFiles = parentDirectory.listFiles(f);
    if(fileFiles != null && fileFiles.length > 0) {
        for(File fileFile : fileFiles) {
            Long journalTimestamp = j.get(fileFile);
            if(journalTimestamp != null) {
                if(journalTimestamp >= deadline) {
                    return true
                }
            }
        }
    }
    return false;
}
def deleteFromBuildCache(File parentDirectory, BTreePersistentIndexedCache<File, Long> j, long deadline, DefaultDeleter deleter) {
    long deleted = 0L;
    FileFilter f = {f -> f.isFile() && f.getName().length() == 32};
    File[] fileFiles = parentDirectory.listFiles(f);
    if(fileFiles != null && fileFiles.length > 0) {
        for(File fileFile : fileFiles) {
            Long journalTimestamp = j.get(fileFile);
            if(journalTimestamp != null) {
                if(journalTimestamp < deadline) {
                    j.remove(fileFile)
                    fileFile.delete()
                    deleted++
                }
            }
        }
    }
    return deleted;
}
tasks.register("deleteOutdatedCacheEntries") {
    doLast {
        File journalFile = new File("${project.gradle.gradleUserHomeDir}/caches/journal-1/file-access.bin");
        BTreePersistentIndexedCache<String, Long> journal = new BTreePersistentIndexedCache<>(journalFile, FILE_SERIALIZER, LONG_SERIALIZER);
        DefaultDeleter deleter = new DefaultDeleter({0L}, {f -> Files.isSymbolicLink(f.toPath())}, false);
        File cachesDirectory = new File("${project.gradle.gradleUserHomeDir}/caches");
        FileFilter jarCacheFilter = {f -> f.getName().startsWith("jars-") || f.name.startsWith("modules-") || f.name.startsWith("transforms-") };
        File[] caches = cachesDirectory.listFiles(jarCacheFilter);
        File deadlineFile = new File(deadline);
        long lastModified = deadlineFile.lastModified();
        boolean wasDependenciesTouched = false;
        FileFilter touchedFileFilter = {f -> (f.getName().endsWith(".jar") && !f.getName().equals("cp_proj.jar") && !f.getName().equals("proj.jar") && !f.getName().equals("cp_settings.jar") && !f.getName().equals("settings.jar") ) || f.getName().endsWith(".aar") || f.getName().endsWith(".dex")};
        for(File cache : caches) {
            if(isDependenciesTouched(cache, journal, lastModified, touchedFileFilter)) {
                wasDependenciesTouched = true;
                break;
            }
        }
        boolean wasBuildCacheTouched = false;
        FileFilter buildCacheFilter = {f -> f.getName().startsWith("build-cache-") };
        File[] buildCaches = cachesDirectory.listFiles(buildCacheFilter);
        for(File cache : buildCaches) {
            if(isBuildCacheTouched(cache, journal, lastModified)) {
                wasBuildCacheTouched = true;
                break;
            }
        }
        if(wasDependenciesTouched || wasBuildCacheTouched) {
            // so assuming that a build has been run
            long deleted = 0;
            if(wasDependenciesTouched) {
                FileFilter fileFilter = {f -> (f.getName().endsWith(".jar") ) || f.getName().endsWith(".aar") || f.getName().endsWith(".dex")};
                for(File cache : caches) {
                    deleted += deleteFromDependencies (cache, journal, lastModified, deleter, fileFilter)
                    }
            }
            long deletedFromBuildCache = 0;
            if(wasBuildCacheTouched) {
                for(File cache : buildCaches) {
                    deletedFromBuildCache += deleteFromBuildCache(cache, journal, lastModified, deleter)
                }
            }
            println 'Deleted ' + deleted + ' cache entries and ' + deletedFromBuildCache + ' from build cache'
        } else {
            println 'No dependencies or caches were touched, so assuming build did not execute and current cache content is still relevant'
        }
        journal.close()
    }
}
endmsg
echo "A new cache entry will be created, deleting files not accessed during this build.."
./gradlew --stop
./gradlew -b /tmp/cleanup.gradle -Pdeadline=/tmp/git_last_hash --no-daemon deleteOutdatedCacheEntries

