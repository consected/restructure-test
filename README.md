# Build ReStructure

A Dockerfile and scripts to test [ReStructure](https://github.com/consected/restructure).

## Configuration

Clone this repo:

    git clone https://github.com/consected/restructure-test

Copy `build-vars-sample.sh` to `build-vars.sh` and edit it with your details.

Set up a file `shared/.netrc` to include login credentials to any private git repos (the original source
and optionally the production repo) to allow the container to clone, pull and push your code. The file
contents should look like:

    machine github.com login mygithubid password myplaintextpassword
    machine hostname.of.prod.repo login prodrepouserid password anotherplaintextpassword

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

## Build the container

Build (or rebuild) the container, and run the test suite with:

    ./test.sh clean

## Run a test

Run a test according to the settings in `shared/build-vars.sh` with:

    ./test.sh

At the end of the test suite, view the results:

    less -r output/restructure/tmp/failing_specs.log

## License

BSD 3-Clause License

This code is property of Harvard University
and made available as open source under the BSD-3 license
(<https://opensource.org/licenses/BSD-3-Clause>).

Copyright 2020 Harvard University
