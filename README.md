# RSVP
![GitHub Workflow Status](https://img.shields.io/github/workflow/status/mlibrary/rsvp/Run%20CI)
## Ruby SIP Validation and Processing

## Initial setup

### 1. Set up development
```
$ git clone https://github.com/mlibrary/rsvp.git
$ cd rsvp
$ bundle install
```

### 2. Set up Docker development

```
$ docker-compose build
```

### 3. Running tests

```
$ docker-compose run test
```

or

```
$ bundle exec rake test
$ rubocop
```
