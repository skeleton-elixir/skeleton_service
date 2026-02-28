FROM elixir:1.19-slim AS build

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY config config
COPY lib lib
COPY priv priv

RUN mix compile

FROM build AS test

COPY test test

CMD ["mix", "test"]
