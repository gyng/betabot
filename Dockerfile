FROM ruby:2.3.1-alpine

ARG PORT_SYNC_LISTENER=15555
ARG PORT_WEB=80

WORKDIR /app

RUN apk --update add --virtual build-dependencies \
    build-base \
    ruby-dev \
    sqlite-dev \
  && apk --update add \
    imagemagick \
    sqlite-libs \
  && gem install bundler --no-ri --no-rdoc

COPY Gemfile Gemfile.lock /app/
RUN bundle install --without development test

ENV RACK_ENV production
EXPOSE $PORT_WEB
EXPOSE $PORT_SYNC_LISTENER

COPY . /app
RUN bundle install --without development test
CMD ["bundle", "exec", "ruby", "start_bot.rb"]
