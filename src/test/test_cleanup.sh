set -e

# smoke test gradle 8 cleanup

# generate real .gradle cache files
cd sample_app
./gradlew build

# run cleanup
./../src/scripts/cleanup.sh


