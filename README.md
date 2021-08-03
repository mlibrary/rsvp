# RSVP
![GitHub Workflow Status](https://img.shields.io/github/workflow/status/mlibrary/rsvp/Run%20CI)
## Ruby SIP Validation and Processing

## Overview

At its core RSVP manages a workflow of discrete stages for validating and
converting SIP shipments and their associated image files for
University of Michigan DCU.

## Installation

### 1. Set up development

The minimum Ruby version is 2.7.3.

```
$ git clone https://github.com/mlibrary/rsvp.git
$ cd rsvp
$ bundle install
```

On a server to which you do not have root access, this may be preferable:

```
mkdir -p vendor/bundle
bundle install --path vendor/bundle
```

For basic functionality when running outside Docker, the following packages
should be installed via Homebrew if running on Mac OS:
```
exiftool
libtiff
netpbm
```

RSVP uses Kakadu for JPEG2000 compression. For local use, the free version
should suffice for development purposes.


### 2. Set up Docker development

```
$ docker-compose build
```

### 3. Running tests

```
$ docker-compose run --rm test
$ docker-compose run --rm test bundle exec rubocop
```

or

```
$ bundle exec rake test
$ bundle exec rubocop
```
