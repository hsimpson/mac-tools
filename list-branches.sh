#!/bin/sh
# list all branches where I am the last commiter (exclude release, master, develop, main, and links with ->)

for repo in $(ls -1d *); do
	cd $repo
	# echo "Repo: $repo"
	branches=$(git branch -r | sed -r '/release|master|develop|main|->/d')

	if [ ! -z "$branches" ]; then
		for branch in $branches; do
			entry=$(git --no-pager show --no-patch --format='%ai on branch: %S by: %an' $branch | grep "$(git config user.name)")
			if [ ! -z "$entry" ]; then
				echo "$repo: $entry"
			fi
		done
	fi
	cd '..'
done
