FROM oven/bun:1-debian

RUN apt-get update && apt-get install -y \
    tmux \
    jq \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .

EXPOSE 3333

CMD ["bun", "run", "src/index.ts"]
