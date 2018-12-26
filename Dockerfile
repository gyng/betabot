FROM ruby:2.6.0-rc2-alpine3.8

ARG PORT_SYNC_LISTENER=15555
ARG PORT_WEB=80

WORKDIR /app

RUN apk --update add --virtual build-dependencies \
    build-base \
    ruby-dev \
    sqlite-dev \
    openssl-dev \
  && apk --update add \
    imagemagick \
    sqlite-libs \
    openssl \
    git

COPY Gemfile Gemfile.lock /app/
RUN bundle install --without development test

ENV RACK_ENV production
ENV LANG C.UTF-8
EXPOSE $PORT_WEB
EXPOSE $PORT_SYNC_LISTENER

COPY . /app
RUN bundle install --without development test
CMD ["bundle", "exec", "ruby", "start_bot.rb"]
