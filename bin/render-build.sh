#!/usr/bin/env bash
# Build command de Render: instala dependencias, prepara la BD y compila assets.
set -e

bundle install --jobs 4 --retry 3

# Compila assets (requiere un valor de SECRET_KEY_BASE; Render lo inyecta).
export SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(bin/rails secret)}"
bin/rails assets:precompile

# Crea la BD y corre las migraciones/seed si es necesario.
bin/rails db:prepare