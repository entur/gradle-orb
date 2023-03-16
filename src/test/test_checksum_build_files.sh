rm -rf /tmp/repo
mkdir /tmp/repo

cp ./src/scripts/checksum_build_files.sh /tmp/repo

cd /tmp/repo

git init
git config --global init.defaultBranch master
echo "Test project" > README.md
echo "1" > build.gradle
git add .
git commit -m "Commit 1"

echo "2" > build.gradle
git add .
git commit -m "Commit 2"

echo "3" > build.gradle
git add .
git commit -m "Commit 3"

echo "4" > build.gradle
git add .
git commit -m "Commit 4"

export PARAM_CHECKSUM_FILES=build.gradle
./checksum_build_files.sh

# now test that file changes were detected
lastHash=$(cat /tmp/git_last_hash)
lastPreviousFirstHash=$(cat /tmp/git_last_previous_first_hash)
lastPreviousSecondHash=$(cat /tmp/git_last_previous_second_hash)
lastPreviousThirdHash=$(cat /tmp/git_last_previous_third_hash)

echo "Last hash was $lastHash"

if [ "$(git rev-list --count $lastHash)" -ne "4" ]; then
  echo "Last hash not as expected $(git rev-list --count $lastHash)"
  exit 1
fi
if [ "$(git rev-list --count $lastPreviousFirstHash)" -ne "3" ]; then
  echo "Last previous first hash not as expected"
  exit 1
fi
if [ "$(git rev-list --count $lastPreviousSecondHash)" -ne "2" ]; then
  echo "Last previous second hash not as expected"
  exit 2
fi
if [ "$(git rev-list --count $lastPreviousThirdHash)" -ne "1" ]; then
  echo "Last previous third hash not as expected"
  exit 3
fi


