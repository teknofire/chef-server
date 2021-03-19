# Chef Server Release Process

## Document Purpose

The purpose of this document is to describe the *current* release
process such that any member of the team can do a release. As we
improve the automation around the release process, the document should be updated such that it always has the exact steps required to release
Chef Server.

This document is NOT aspirational. We have a number of automation
tools that we intend to use to improve the release release process;
however, many are not fully integrated with our process yet. Do not
add them to this document until they are ready to be part of the
release process and can be used by any team member to perform a
release.

## Pre-requisites

In order to release, you will need the following accounts/permissions:

- Chef Software Inc. Slack account
- VPN account for Chef Software Inc.
- Account on [https://discourse.chef.io](https://discourse.chef.io) using your Chef email address
- Access to automate.chef.co

:warning: If it is a Friday -- do we really need that release today? :warning:

## THE PROCESS

@Prajakta Purohit
    the first thing to do would be make sure you have the umbrella pipelines running
    10:21
    we already have 14.1.0 -> 14.2.2
    10:22
    I think you need to run 14.0.65 -> 14.2.2
    10:22
    in the full pipeline.
    10:22
    and test manage login.
to know what to test, it appears we could look at last few stable releases for Chef Infra Server here: https://downloads.chef.io, and use those to test
INSTALL_VERSION -> UPGRADE_VERSION.

### Getting the build to be released into current with a minor/major version bump

- Create a new branch from the latest master branch. [QUESTION: or do we simply push commits directly to master?]
- Update the release notes with the version, date and context.  
https://github.com/chef/chef-server/wiki/Pending-Release-Notes
- Run all the tasks for 'Updating Ruby Gems' from dev-docs/FrequentTasks.md.  Note that some of this might have already been done by dependabot.
- Push branch, create PR.
- Bump the release version:
    - Apply the label _Expeditor: Bump Version Minor_ or _Expeditor: Bump Version Major_ to your PR to bump the version number of the release candidate. [QUESTION: can BOTH labels be applied?]
    - DOUBLE-CHECK the labels to confirm that they are correct.
- Merge to master.  
Additional context:  After a commit is merged to master, a build is automatically kicked-off on the Chef / [chef/chef-server:master] omnibus/release pipeline by expeditor after it bumps the version number.  After the build and tests in buildkite pass, expeditor should put the build artifact in Artifactory's current channel.
- Make sure the omnibus build to be promoted is present in Artifactory's current channel.  
One approach is to enter the following into a bash shell, where _version_ is the version number of the new release:
```
$ mixlib-install download chef-server -c current -a x86_64 -p ubuntu -l 16.04 -v <version>
Starting download https://packages.chef.io/files/current/chef-server/14.1.0/ubuntu/16.04/chef-server-core_14.1.0-1_amd64.deb
```
- Make sure the Habitat builds for master are passing.  
Chef / [chef/chef-server:master] habitat/build / master  
https://buildkite.com/chef/chef-chef-server-master-habitat-build

Monitor the chef-server-notify slack channel for current progress. [QUESTION: where does this sentence go, i.e. at what step do we monitor progress?  During the build?]

### Testing the Release

Every merge to chef-server master must be built, and this build must be tested with the full Umbrella automated integration test pipeline at https://buildkite.com/chef/chef-umbrella-master-chef-server-full.
The integration test run for the tag being shipped must be successful.

Step-by-step:

- Navigate your web browser to https://buildkite.com/chef/chef-umbrella-master-chef-server
- Select 'New Build'.
- Leave 'Branch' set to 'master'.
- Select 'Options' to expand the 'Environment Variables' field.
- Enter `INSTALL_VERSION=<version number>` into the 'Options | Environment Variables' field, where _version number_ is the stable  version number of the release you wish to test upgrading FROM (for example 14.0.65).
- Enter `UPGRADE_VERSION=<version number>` into the 'Options | Environment Variables' field, where _version number_ is the current version number of the release candidate you wish to test upgrading TO (for example 14.2.2).
- Optionally, fill-in the 'Message' field with something descriptive.
- Select 'Create Build'.

Currently (02/21), the Umbrella pipeline does not perform a test login to Chef Manage, so this should be done manually by picking representative AWS and Azure scenarios.

Typical scenario for AWS:
- Enter the following into a bash shell from within the Umbrella repo, where _version_ is the version number of the release candidate you are testing:
```
$ cd umbrella/chef-server/scenarios/aws
$ okta_aws --all
$ PLATFORM=ubuntu-18.04 INSTALL_VERSION=<version> UPGRADE_VERSION=<version> SCENARIO=standalone-fresh-install ENABLE_ADDON_PUSH_JOBS=false ENABLE_GATHER_LOGS_TEST=false ENABLE_PEDANT_TEST=false ENABLE_PSQL_TEST=false ENABLE_SMOKE_TEST=false ENABLE_IPV6=true make apply
```
- Obtain the DNS name of the ephemeral machine by observing the output of the boot-up.  A sample output is shown below:
```
null_resource.chef_server_config: Provisioning with 'remote-exec'...
null_resource.chef_server_config (remote-exec): Connecting to remote host via SSH...
null_resource.chef_server_config (remote-exec):   Host: ec2-34-212-122-231.us-west-2.compute.amazonaws.com
null_resource.chef_server_config (remote-exec):   User: ec2-user
null_resource.chef_server_config (remote-exec):   Password: false
null_resource.chef_server_config (remote-exec):   Private key: false
null_resource.chef_server_config (remote-exec):   Certificate: false
null_resource.chef_server_config (remote-exec):   SSH Agent: true
null_resource.chef_server_config (remote-exec):   Checking Host Key: false
null_resource.chef_server_config (remote-exec): Connected!
null_resource.chef_server_config (remote-exec): echo -e '
null_resource.chef_server_config (remote-exec): BEGIN INSTALL CHEF SERVER
```
- Navigate to `http://<hostname>` via web browser where _hostname_ is the DNS name of the emphemeral machine obtained in the previous step.
- Enter the username and password to test the login.  The username and password are stored in the following script:  
https://github.com/chef/chef-server/blob/master/terraform/common/files/add_user.sh.  
Currently (02/21) the username is janedoe and the password is abc123.
- Verify that the login is successful.
- Navigate to `http://<hostname>/id` via web browser where _hostname_ is the DNS name of the emphemeral machine obtained in the previous step.
- Login with the same user/password as the previous login step above.
- Select the 'signed in as <username>' link in the upper-left. Confirm that the email is grayed-out.
- Clean-up:
```
PLATFORM=ubuntu-18.04 INSTALL_VERSION=<version> UPGRADE_VERSION=<version> SCENARIO=standalone-fresh-install ENABLE_ADDON_PUSH_JOBS=false ENABLE_GATHER_LOGS_TEST=false ENABLE_PEDANT_TEST=false ENABLE_PSQL_TEST=false ENABLE_SMOKE_TEST=false ENABLE_IPV6=true make destroy
```
Typical scenario for Azure:
- Enter the following into a bash shell from within the Umbrella repo, where _version_ is the version number of the release candidate you are testing:
```
$ cd umbrella/chef-server/scenarios/azure
$ ARM_DEPT=Eng ARM_CONTACT=lbaker make create-resource-group
$ PLATFORM=ubuntu-18.04 INSTALL_VERSION=<version> UPGRADE_VERSION=<version> SCENARIO=external-postgresql ENABLE_ADDON_PUSH_JOBS=false ENABLE_GATHER_LOGS_TEST=false ENABLE_PEDANT_TEST=false ENABLE_PSQL_TEST=false ENABLE_SMOKE_TEST=false ENABLE_IPV6=true make apply
```
- Perform the same login process specified above for AWS.
- Clean-up:
```
PLATFORM=ubuntu-18.04 INSTALL_VERSION=<version> UPGRADE_VERSION=<version> SCENARIO=external-postgresql ENABLE_ADDON_PUSH_JOBS=false ENABLE_GATHER_LOGS_TEST=false ENABLE_PEDANT_TEST=false ENABLE_PSQL_TEST=false ENABLE_SMOKE_TEST=false ENABLE_IPV6=true make destroy
```

Any failures must be fixed before shipping a release, unless they are "known failures" or expected [INSERT PROCESS FOR KNOWN FAILURES HERE]. Note that no changes other than CHANGELOG/RELEASE_NOTES changes should land on master between testing and releasing since we typically tag HEAD of master. If something large does land on master, the release tag you create should point specifically at the build that you tested. The git SHA of the build you are testing can be found in /opt/opscode/version-manifest.json.

[insert blurb about consulting:
https://docs.google.com/spreadsheets/d/10LZszYuAIlrk1acy0GRhrZMd0YohLTQWmcNIdY6XuZU/edit#gid=0
use chef.io account]

### Informing everyone of a pending release

- [ ] Announce your intention to release to the following slack channels. Some announcements are done pre-promote.  Some are done post-promote.  
    - Announce pre-promote
Sample pre-promote announcement:  
We are planning to do a release of Chef Infra Server X.Y.Z shortly. Details can be found at: https://github.com/chef/chef-server/wiki/Pending-Release-Notes
        - #a2-release-coordinate
        - #chef-server
    - Announce post-promote  
Copying a discourse post link to the channels below should suffice:
https://discourse.chef.io/t/chef-infra-server-14-1-0-released/19616
        - #a2-release-coordinate
        - #chef-server
        - #cft-announce

(Per @PrajaktaPurohit - only for the post-release announce, Announce the intention for release in #a2-release-coordinate channel.
The link to discourse post can be found after release like: https://discourse.chef.io/t/chef-infra-server-14-1-0-released/19616)

### Preparing for the Release

- [ ] Check RELEASE_NOTES.md to ensure that it describes the
  most important user-facing changes in the release. This file should
  form the basis of the post to Discourse that comes in a later step.

### Building and Releasing the Release

- [ ] Select a version from the `current` channel that you wish to promote to `stable`. Make sure that this version has gone through the upgrade testing.
- [ ] Use expeditor to promote the build.  The expeditor command is of the form:

        /expeditor promote ORG/REPO:BRANCH VERSION

In practice it will look like:

        /expeditor promote chef/chef-server:master VERSION

Example:
```
/expeditor promote chef/chef-server:master 14.2.2
```

  Please do this in the `#chef-server-notify` channel.  Once this is
  done, the release is available to the public via the APT and YUM
  repositories and downloads.chef.io.

- [ ] Chef employees should already know a release is coming; however, as a
  courtesy, drop a message in the #cft-announce slack channel that the release
  is coming. Provide the release number and any highlights of the release.

- [ ] Write and then publish a Discourse post on https://discourse.chef.io
  once the release is live. This post should contain a link to the downloads
  page ([https://downloads.chef.io](https://downloads.chef.io)) and its contents
  should be based on the information that was added to the RELEASE_NOTES.md file
  in an earlier step. *The post should  be published to the Chef Release
  Announcements category on https://discourse.chef.io. If it is a security
  release, it should also be published to the Chef Security Announcements
  category.* Full details on the policy of making release announcements on
  Discourse can be found on the wiki under the Engineering section ->
  Policy and Processes -> Release Announcements and Security Alerts

Chef Infra Server is now released.

a sample release checklist in progress:

RELEASE CHECKLIST
- updated release notes and changelog                                          YES
- version file updated                                                         YES 
- omnibus build in current channel                                             YES
- full umbrella pipeline green                                                 testing - https://buildkite.com/chef/chef-umbrella-master-chef-server-full/builds/24#8b278561-477a-4548-a070-4e312a87608c
- manual login to chef-manage - AWS                                            YES
- manual login to chef-manage - azure                                          PENDING
- habitat build green                                                          PENDING
- announce pending release via slack (#a2-release-coordinate and #chef-server) PENDING
- do release                                                                   PENDING
- announce post-promote (#a2-release-coordinate, #chef-server, #cft-announce)  PENDING
