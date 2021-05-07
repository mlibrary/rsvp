#!/bin/bash
RBENV_VERSION="2.6.6"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BUNDLE_GEMFILE="$SCRIPT_DIR"/Gemfile
TEMP_HOME="$SCRIPT_DIR"/.bundle
HOME=$TEMP_HOME RBENV_VERSION=$RBENV_VERSION BUNDLE_GEMFILE=$BUNDLE_GEMFILE bundle exec "$SCRIPT_DIR"/query.rb $*
