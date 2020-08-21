
# gradle-orb
This orb clones the official [CircleCI Gradle] orb interface, but applies a different caching strategy. 

In a nutshell, it __detects previous build file changes via the git history__, so that it can restore the previous Gradle cache regardless of what changed in the latest commit.

In contrast, the official CircleCI orb restores the previous Gradle cache via a hash of the build files, so all changes to the build files (even whitespace changes) result in a cache miss. 

Typical use-case:

 * single-module projects with frequent tweaks to the Gradle build, i.e.
   * functional changes in the build files themselves
   * dependency bumping

Advantages:

 * Improves build time when the Gradle build files themselves are updated, as (most) dependencies are already in the cache
 * Less traffic for artifact repositories (i.e. Maven central, JCenter, your own private Artifactory etc.)

Disadvantages:

  * Best __suited for single-module projects__, as the orb also saves the cache
    on build fails (when all dependencies might not have been resolved for multi-module
    projects). 
       * Alternatively resolve all submodule dependencies before compiling / testing
   *  Uses internal Gradle classes to delete unused dependencies. 
      * The cache job might break on a future version of the Gradle wrapper. If so, it is trivial to (temporarily) revert to the official Gradle orb.

Bugs, feature suggestions and help requests can be filed with the [issue-tracker].

## Usage
Import the orb

```yaml
orbs:
  gradle: entur/gradle-orb@0.0.x
```

where `x` is the latest version from [the orb registry](https://circleci.com/orbs/registry/orb/entur/gradle-orb).

## Compatibility
This orb uses a few internal Gradle classes to delete unused dependencies from the cache, thus keeping it from growing too big and consequently consuming additional time for cache persist / restore. 

| Orb version  | Official Orb Version | Gradle version(s) |
| ------------- | ------------- | -- |
| 0.0.1  | 2.2.0  | 6.6 |

## Troubleshooting
If the cache is corrupted, update the cache key, so that the previous state is not restored - as in the official Gradle orb.

[issue-tracker]:               https://github.com/entur/gradle-orb
[CircleCI Gradle]:             https://circleci.com/orbs/registry/orb/circleci/gradle?version=2.2.0


