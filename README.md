# gradle-orb
This orb clones the official [CircleCI Gradle] orb interface, adding a __proper incremental cache__ which also __works when the build files are updated__.

Typical use-case:

 * projects with frequent tweaks to the Gradle build, i.e.
   * functional changes in the build files themselves
   * dependency bumping

Advantages:

 * Improves build time when the Gradle build files themselves are updated, as (most) dependencies are already in the cache
 * Much less traffic for artifact repositories (i.e. Maven central, your own private Artifactory etc.)

Disadvantages:

 *  Uses internal Gradle classes to delete unused dependencies for Gradle versions < 8. For Gradle version >= 8 it uses the built in cache cleanup strategy (with 1 day retention of unused dependencies).
      
Bugs, feature suggestions and help requests can be filed with the [issue-tracker].

## Usage
Import the orb

```yaml
orbs:
  gradle: entur/gradle-orb@0.x.x
```

where `x` is the latest version from [the orb registry](https://circleci.com/orbs/registry/orb/entur/gradle-orb).

### Default executor
To use the default executor, [Docker Hub credentials](https://circleci.com/docs/2.0/private-images/) must be set as the environment variables `$DOCKERHUB_LOGIN` and `$DOCKERHUB_PASSWORD`.

## Compatibility

### Gradle < 8
For Gradle version < 8, this orb uses a few internal Gradle classes to delete unused dependencies from the cache. While these internal classes have not changed in the later versions of Gradle, this approach is somewhat brittle and generally needs testing for each Gradle version.

| Orb version   | Official Orb Version | Gradle version(s)            |
| ------------- | -------------------- | ---------------------------- |
| 0.0.1         | 2.2.0                | 6.6                          |
| 0.0.4         | 2.2.0                | 6.6, 6.6.1, (possibly 6.7.0) |
| 0.0.5         | 2.2.0                | 6.6, 6.6.1, 6.7.0            |
| 0.0.6         | 2.2.0                | up to 7.2.x                  |
| 0.0.7         | 2.2.0                | 7.3.x                        |
| 0.0.8         | 2.2.0                | 7.3.x                        |
| 0.0.9         | 3.0.0                | 7.x                          |

Note that 7.x support is now deprecated.

### Gradle >= 8
For Gradle >= 8, the orb uses the 'officially endorsed' method of cleaning up the cache.

| Orb version   | Official Orb Version | Gradle version(s)            |
| ------------- | -------------------- | ---------------------------- |
| 0.0.9         | 3.0.0                | 8.0-8.7                      |
| 0.1.0         | 3.0.0                | 8.0-8.8                      |
| 0.2.1         | 3.0.0                | 8.0-8.9+                     |

## Caching strategy
In a nutshell, this orb __detects previous build file changes via the git history__, so that it can restore the previous Gradle cache regardless of what changed in the latest commit.

In contrast, the official CircleCI orb restores the previous Gradle cache via a __hash of the build files__, so __all changes to the build files (even whitespace changes) result in a cache miss__ and the cache must be populated from scratch.

The caching strategy tries to handle both successful and failing builds as good as possible. The CircleCI caches are immutable, so once a cache is written, it cannot be modified, a new cache key must be created (and the cache persisted).

Permutations: 

 * Git commit
   * build files
   * source files (excluding build files)
 * Build status
   * Success
   * Failure

The cache will be saved in two states: 

 * a _success_ cache is saved on the first successful build after the build files has been updated.
 * a _failure_ cache is saved on the first failed build after the build files has been updated, if a corresponding _success_ cache does not already exists.

So in other words, when the build files are updated, a cache is always created. Ununsed dependencies are purged before saving the _success_ cache.

If the `.circleci/config.yml` or Gradle wrapper version is updated, the cache is wiped.

### Single-commit use-cases

##### Single commit, single-step workflow

| Commit  | Build status | Expected outcome |
| ------------- | ------------- | -- |
| Source files  | Success  | Previous _success_ or _failure_ cache restored, no new cache created |
| Source files  | Failure  | Previous _success_ or _failure_ cache restored, no new cache created |
| Build files  | Success  | Previous _success_ or _failure_ cache restored, ununsed dependencies purged, new _success_ cache created |
| Build files, source files  | Success  | Previous _success_ or _failure_ cache restored, ununsed dependencies purged, new _success_ cache created |

##### Single commit, multi-step workflow

| # | Commit | Step | Depends on | Build status | Expected outcome |
| ------------- | -- | -- |------------- | -- | -- |
| 1. | Build files  | STEP1 | - | Success  | Previous _success_ or _failure_ cache restored, new ___success_ cache D__ created |
|  |   | STEP2  |  STEP1 | Success | ___success_ cache #D__ restored, no new cache created |

### Multi-commit use-cases
##### Bumping dependencies breaks compilation, fixes.

| # | Commit | Build status | Expected outcome |
| ------------- | ------------- | -- | -- |
| 1. | Build files  | Failure  | Previous _success_ or _failure_ cache restored, new ___failure_ cache A__ created |
| 2. | Source files  | Failure  | ___failure_ cache #A__ restored, no new cache created |
| 3. | Source files  | Success  | ___failure_ cache #A__ restored, ununsed dependencies purged, new ___success_ cache #B__  created |
| 4. | Source files  | Success  | ___success_ cache #B__ restored, no new cache created |

##### Bumping dependencies, break unit tests later

| # | Commit | Build status | Expected outcome |
| ------------- | ------------- | -- | -- |
| 1. | Build files  | Success  | Previous _success_ or _failure_ cache restored, new ___success_ cache C__ created |
| 2. | Source files  | Failure  | ___success_ cache #C__ restored, no new cache created |

## Troubleshooting
If the cache is corrupted, update the cache key, so that the previous state is not restored - as in the official Gradle orb.

# Releasing a new version of this orb
Release does not run on the master branch, rather is triggered by creating a tag.

[issue-tracker]:               https://github.com/entur/gradle-orb
[CircleCI Gradle]:             https://circleci.com/orbs/registry/orb/circleci/gradle


