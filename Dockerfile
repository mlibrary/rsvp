FROM ruby:2.6

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
    libtiff-tools exiftool netpbm

RUN gem install bundler

ENV APP_PATH /usr/src/app
RUN mkdir -p $APP_PATH
WORKDIR $APP_PATH
COPY Gemfile Gemfile.lock ./
RUN bundle install
