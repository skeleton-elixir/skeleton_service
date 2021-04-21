FROM elixir:1.11

RUN export MIX_ENV=test

RUN apt-get -o Acquire::Max-FutureTime=86400 update -y
RUN apt-get install -y inotify-tools

WORKDIR /app

COPY . .

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get