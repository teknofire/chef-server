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

### Informing everyone of a pending release

- [ ] Announce your intention to drive the release to #cft-announce and #chef-server on slack.
    - The #cft-announce should be post-promote.
    - Copying the discourse post link (what link?) to the channels above should suffice.

### Getting the build to be released into current with a minor/major version bump

- Create a new branch from the latest master branch ? <----
- Update the contents of the file VERSION to the version to be released if minor version needs to be bumped rather than just the patch [what about major version?].
For updating just the patch verion, [insert 'skip this section, and' ?] refer the the section below on #Preparing for the release
- Update the release notes with the version, date and context.
  https://github.com/chef/chef-server/wiki/Pending-Release-Notes
- Update CHANGELOG.md ? <-----
- Run all the tasks for 'Updating Ruby Gems' and 'Updating Erlang Dependencies' from dev-docs/FrequentTasks.md.
- Make sure the omnibus build is into current channel. [explain?] <-----
  (This is triggered by expeditor once the build and tests in buildkite go through ok once a commit is merged to master)
QUESTION: when/where does the merge to master happen? where is this step?
One approach is to enter the following into a bash shell, where _version_ is the version number of the new release:
```
$ mixlib-install download chef-server -c current -a x86_64 -p ubuntu -l 16.04 -v <version>
```
Starting download https://packages.chef.io/files/current/chef-server/14.1.0/ubuntu/16.04/chef-server-core_14.1.0-1_amd64.deb
- Make sure the habitat builds are passing. [pipeline? and when/where is this build kicked off?] <-----
Chef / [chef/chef-server:master] habitat/build / master 
Monitor the chef-server-notify slack channel for current progress ? <-----

[insert this info somewhere, if appropriate. these sentences aren't necessary supposed to go together:
Automatically upon merge, a build is kicked-off on the Chef / [chef/chef-server:master] omnibus/release pipeline.
The release pipeline runs automatically on merge after expeditor bumps the version...]

### Testing the Release

Every merge to chef-server master must be built, and this build (master branch) must be tested with the Umbrella automated integration test pipeline: https://buildkite.com/chef/chef-umbrella-master-chef-server.
The integration test run for the tag being shipped must be successful.

QUESTION: i noticed the last release we ran a FULL Umbrella pipeline test:
Chef / [chef/umbrella:master] chef-server-full
https://buildkite.com/chef/chef-umbrella-master-chef-server-full
do we need to clarify here that the FULL umbrella pipeline needs to be run?

Step-by-step:

- Navigate your web browser to https://buildkite.com/chef/chef-umbrella-master-chef-server
- Select 'New Build'.
- Leave 'Branch' set to 'master'.
- Select 'Options' to expand the 'Environment Variables' field.
- Enter `UPGRADE_VERSION=<build record>` into the 'Options | Environment Variables' field, where _build record_ is the version number string of the omnibus/adhoc build you wish to test (for example 13.1.64+20201234567890).
CLARIFICATION: this step should just be performed on master? so delete the previous two 'Options' and 'UPGRADE_VERSION=' steps?
- Optionally, fill-in the 'Message' field with something descriptive, for example the version number string of the build record.
- Select 'Create Build'.

Currently (02/21), the Umbrella pipeline does not perform a test login to Chef Manage, so this should be done manually by picking a representative Azure scenario and a representative AWS scenario:

- NOTE: NOT SURE IF THESE INSTRUCTIONS ARE CORRECT.
question: is this a local build or a buildkite build?
if local, we'll need instructions for that.
- Ensure that your chosen scenario installs the Chef Manage add-on.  This is normally done by default, but can be explicitly enabled by setting the option `ENABLE_ADDON_CHEF_MANAGE=true`.
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
- Hit the server via `http://<hostname>` where hostname is the DNS name of the emphemeral machine obtained in an earlier step.
- Enter the username and password to test the login.  The username and password are stored in the following script: https://github.com/chef/chef-server/blob/master/terraform/common/files/add_user.sh.
Currently (02/21) the username is janedoe and the password is abc123.

[insert necessary (azure?) manual testing instructions here]

Any failures must be fixed before shipping a release, unless they are "known failures" or expected. Note that no changes other than CHANGELOG/RELEASE_NOTES changes should land on master between testing and releasing since we typically tag HEAD of master. If something large does land on master, the release tag you create should point specifically at the build that you tested. The git SHA of the build you are testing can be found in /opt/opscode/version-manifest.json.

### Preparing for the release

- [ ] Check RELEASE_NOTES.md to ensure that it describes the
  most important user-facing changes in the release. This file should
  form the basis of the post to Discourse that comes in a later step.

### Building and Releasing the Release

- [ ] Select a version from the `current` channel that you wish to promote to `stable`. Make sure that this version has gone through the upgrade testing.
- [ ] Use expeditor to promote the build:

        /expeditor promote chef/chef-server:master VERSION

  Please do this in the `#chef-server-notify` room.  Once this is
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
