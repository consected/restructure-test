# Build ReStructure

A Dockerfile and scripts to build [ReStructure](https://github.com/consected/restructure) and
commit it to a repository. Deployable code is made available, and the latest version
(in the source `version.txt`) will be upversioned.

## The Process

The build process performs the following

- gets the latest version from a specified remote branch in the _dev_ repo
- bundles and packages gems for production deployment in `vendor/cache`
- installs Javascript components based on the YARN packages in `yarn.lock`
- precompile Javascript and CSS assets from project code and YARN installed node_modules
- sets up an app database, and migrates it to the current version
- updates a section marked `## Unreleased` in the `CHANGELOG.md` to the new version and date
- run [Brakeman](https://brakemanscanner.org/) tests to enforce static code analysis
- run [bundle-audit](https://github.com/rubysec/bundler-audit) to prevent insecure gems being deployed
- runs a subset of the rspec tests to validate the build
- commits and pushes the built and tagged version back to the repo
  (and / or an alternative _production_ repo if specified)

## Setup the Docker image

    docker image build .

You may need to clear the output director to get started:

    sudo rm -rf output/restructure*

If you receive strange merge conflicts during build, this can also often resolve them.

If you get an error that yum can't find a repository due to no space, you may need to clean up docker. This will
clean everything!

    docker system prune -a
    docker volume rm $(docker volume ls -f dangling=true -q)

## Configuration

Copy `build-vars-sample.sh` to `build-vars.sh` and edit it with your details.

To commit the built version to a different _production_ repo, specify the `PROD_REPO_URL`
environment variable with the URL to the repo.

To prevent the built version being pushed to the _dev_ repo, specify `ONLY_PUSH_TO_PROD_REPO=true`

To prevent built assets (Javascript, CSS, packaged gems) being pushed to the _dev_ repo,
specify `ONLY_PUSH_ASSETS_TO_PROD_REPO=true`. They will continue to be pushed to the _production_
repo if it is being used.

Set up a file `shared/.netrc` to include login credentials to any private git repos (the original source
and optionally the production repo) to allow the container to clone, pull and push your code. The file
contents should look like:

    machine github.com login mygithubid password myplaintextpassword
    machine hostname.of.prod.repo login prodrepouserid password anotherplaintextpassword

Protect the plaintext file with:

    chmod 600 shared/.netrc

If you use `.netrc` for your git authentication anyway, then a symlink will suffice:

    ln -s ~/.netrc ./.netrc

Ensure that `build-vars.sh` and `.netrc` are not committed to source control. Check the `.gitignore` file.

Build the container with:

    ./build.sh

## Run a build

Run the build process according to the settings in `shared/build-vars.sh` with:

    docker run --volume="$(pwd)/shared:/shared" --volume="$(pwd)/output:/output"  consected/restructure-build

On a successful build, the `output` directory will contain a sub-directory `restructure`
containing built and deployable code. The file `shared/build_version.txt` will show the new version.

## License

BSD 3-Clause License

This code is property of Harvard University
and made available as open source under the BSD-3 license
(https://opensource.org/licenses/BSD-3-Clause).

Copyright 2020 Harvard University
