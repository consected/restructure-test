# Test and Develop ReStructure

A Dockerfile and scripts to build a development environment in a container or run the full test suite
for [ReStructure](https://github.com/consected/restructure).

## Configuration

Clone this repo:

    git clone https://github.com/consected/restructure-test

Copy `shared/build-vars-sample.sh` to `shared/build-vars.sh` and edit it with your details.

Set up a file `shared/.netrc` to include login credentials to any private git repos (the original source
and optionally the production repo) to allow the container to clone, pull and push your code. The file
contents should look like:

    machine github.com login mygithubid password myplaintextpassword

If the repos are public, just run the following to create an empty file:

    touch shared/.netrc

Protect the plaintext file with:

    chmod 600 shared/.netrc

If you use `.netrc` for your git authentication anyway, then a symlink will suffice:

    ln -s ~/.netrc ./shared/.netrc

Ensure that `build-vars.sh` and `.netrc` are not committed to source control. Check the `.gitignore` file.

## Install FUSE

FUSE must be installed on the host machine for the container to be able to access. Check if it is present:

    modprobe fuse

If not, install it with one of the following:

### Ubuntu, Debian, etc

    sudo apt install fuse

### CentOS, Amazon Linux 2

    sudo yum install fuse fuse-libs fuse-devel

### Mac

See macFUSE: <https://osxfuse.github.io/>

## Run the test suite

Run the test suite according to the settings in `shared/build-vars.sh` with:

    ./test.sh

Optionally, add the argument 'clean' to clean up the source and database before running the tests

    ./test.sh clean

The container will exit at the end of the test suite.

## Get log of failing specs

Simply run:

    ./get-failing-specs.sh

or to use `less` pager interactively:

    ./get-failing-specs.sh less

Of course, piping the result works:

    ./get-failing-specs.sh | grep Error

## Start and attach to an existing container

Run the following to connect to an existing test or development environment container for debugging or development:

    ./run.sh

This will run enter bash interactively within the container. Use it directly, SSH or connect through VSCode

Optionally, add arguments representing an alternative command to run and return immediately.

    ./run.sh ls -a /output/restructure

Add 'interactive' as the first argument to force interactive operation.
For example, to run `less` allowing user interaction:

    ./run.sh interactive less -r output/restructure/tmp/failing_specs.log

## Setup a development environment

Run the following to set up a dev environment, which you can subsequently connect to through SSH or VSCode Docker Containers:

    ./setup-dev.sh

Optionally, add the argument 'clean' to clean up the source and database before starting the setup

    ./setup-dev.sh clean

The `setup-dev.sh` command only needs to be run once. Feel free to use `./run.sh` to quickly restart a container that
has already been set up.

## Cleaning up

To remove **restructure-test** containers and images, run:

     ./clean.sh only

To clean and rebuild, run:

     ./clean.sh rebuild

## License

BSD 3-Clause License

This code is property of Harvard University
and made available as open source under the BSD-3 license
(<https://opensource.org/licenses/BSD-3-Clause>).

Copyright 2020 Harvard University
