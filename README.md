# atlassian-debian

A simple script, a folder named debian and the ability to build a package out of the tar.gz-distribution of Atlassian software.

This has currently been tested with Atlassian Confluence 5.7.4.
Maybe I'll add scripts for the other great software as well.

Feel free to use, share and contribute.

## Thank you note

[Nick Cammorato](https://github.com/cammoraton) performed the hard work. He created the scripts I've have as a base. You can find them [here](https://github.com/cammoraton/confluence-package-deb) creating a nice Tomcat 6 instance for you.

## Requirements

* An Ubuntu/Debian build environment. The output will help figuring out if something is missing.
* The tar.gz for Linux by Atlassian.

## What it does

Clone the repo, take a look at the script, create a folder named `setup-files`, copy your download in it and give it a try.

In the end you'll have a debian package within the ./tmp folder. MySQL J connector included and some changes made to the configuration of Confluence:

* Confluence home set to `/var/opt/confluence``
* `setenv.sh` with 1,5 GB Heap instead of 1 GB
* `JRE_HOME` is set to /opt/java_current

A post function will automatically download the latest Oracle Java 8 and put it into `/opt` while the installation is being performed.

Confluence will be installed into `/opt/confluence`.

## Todo

* Make it pretty
* Do the same for JIRA, Bamboo, Stash and Bamboo
* Test it!
* Create a repo? Atlassian, am I allowed to do so? (Asking seems like a good idea.)
* Check if all apps are fine with Java 8. Maybe change the install script.