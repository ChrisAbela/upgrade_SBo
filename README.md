A BASH Script to assist in resolving dependencies for slackbuild updates.

It depends exclusively on well maintained sbopkg queue files.

Prepare a list of packages to upgrade in upgrade.sqf of the queue directory.

Run the script

The resulting queue.sqf should contain the packages to upgrade in sequence.

Packages that are not installed would be Commented out with a # 
