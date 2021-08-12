FROM ruby:2.7.4

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
    libtiff-tools exiftool netpbm

RUN gem install bundler

WORKDIR /tmp
RUN wget http://kakadusoftware.com/wp-content/uploads/KDU805_Demo_Apps_for_Linux-x86-64_200602.zip
RUN unzip -j -d kakadu KDU805_Demo_Apps_for_Linux-x86-64_200602.zip
RUN mv /tmp/kakadu/*.so /usr/local/lib
RUN mv /tmp/kakadu/kdu* /usr/local/bin
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/kakadu.conf
RUN ldconfig

ENV APP_PATH /usr/src/app
RUN mkdir -p $APP_PATH
WORKDIR $APP_PATH
COPY Gemfile Gemfile.lock ./
RUN bundle install
