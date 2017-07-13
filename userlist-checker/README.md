userlist-checker
================
This is simple script that checks state of userlists and can report problems in
them. Idea is that we are running various versions of updater for all userlists.
This should catch syntax errors in userlists. It can potentially also discover
problems with package dependencies as in such case updater would fail too.

Idea is that userlists should be readable for all live versions of updater-ng.
This means latest version in target branch, version currently in deploy and even
version shipped from factory.
