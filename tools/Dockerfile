# Entorno de desarrollo y de CI: LuaJIT (Lua 5.1, la versión del cliente de WoW), git (lo usa tools/check.lua),
# shellcheck y zip (empaquetado de releases).
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends luajit git ca-certificates shellcheck zip unzip \
 && rm -rf /var/lib/apt/lists/* \
 && git config --system --add safe.directory '*'

WORKDIR /addon
CMD ["sh", "-c", "luajit tools/check.lua && luajit tests/run.lua"]
