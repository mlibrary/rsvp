#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BUNDLE_GEMFILE="$SCRIPT_DIR"/Gemfile
TEMP_HOME="$SCRIPT_DIR"/.bundle
HOME=$TEMP_HOME BUNDLE_GEMFILE=$BUNDLE_GEMFILE bundle exec "$SCRIPT_DIR"/shipments.rb $*
