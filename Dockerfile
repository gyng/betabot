FROM ruby:2.7-alpine3.12

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

COPY Gemfile Gemfile.lock .bundle /app/
RUN bundle install --without development test --jobs=3 --retry=3

ENV RACK_ENV production
ENV LANG C.UTF-8
EXPOSE $PORT_WEB
EXPOSE $PORT_SYNC_LISTENER

COPY . /app
RUN bundle install --without development test --jobs=3 --retry=3
CMD ["bundle", "exec", "ruby", "start_bot.rb"]
