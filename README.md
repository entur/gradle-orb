
# gradle-orb
A Circle CI orb using Git to control Gradle caching. Supports two patterns:

 * master - feature
 * master - develop - feature

## Usage
Import the orb

```yaml
orbs:
  owasp: entur/gradle@0.0.x
```

where `x` is the latest version from [the orb registry](https://circleci.com/orbs/registry/orb/entur/gradle).

