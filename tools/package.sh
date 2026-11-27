#!/bin/sh
# Empaqueta el addon en <dist>/Healsilus-<versión>.zip con la carpeta Healsilus/ dentro,
# lista para descomprimir en Interface\AddOns.
#
# Uso: tools/package.sh [versión esperada]
#   Si se pasa una versión (la etiqueta "v1.2.0" o "1.2.0"), debe coincidir con "## Version:" del TOC.
#
# Comprueba antes de empaquetar que cada fichero del TOC existe y que no hay ficheros .lua del addon fuera
# del TOC (el juego no los cargaría).
# Variables opcionales: DIST_DIRECTORY (carpeta de salida, por defecto dist/).
# Imprime en la salida estándar la ruta del zip creado; los errores van a la salida de error.
set -eu

root_directory=$(cd "$(dirname "$0")/.." && pwd)
dist_directory=${DIST_DIRECTORY:-"$root_directory/dist"}
toc_file="$root_directory/Healsilus.toc"
# Carpetas que forman el addon (las de código y Media, con el logo y los iconos).
addon_folders="Core Data Frames Auras UI Locales Media"

if [ ! -f "$toc_file" ]; then
  echo "error: TOC file not found: $toc_file" >&2
  exit 1
fi

version=$(tr -d '\r' < "$toc_file" | sed -n 's/^## Version:[[:space:]]*\([^[:space:]]*\).*$/\1/p')
if [ -z "$version" ]; then
  echo "error: no '## Version:' line in $toc_file" >&2
  exit 1
fi

if [ $# -gt 0 ]; then
  expected_version=${1#v}
  if [ "$expected_version" != "$version" ]; then
    echo "error: version $expected_version does not match the TOC version $version" >&2
    exit 1
  fi
fi

# Ficheros que carga el TOC (líneas que no son comentarios ni están vacías), con "/" como separador
# (\134 es la barra invertida en octal).
toc_entries=$(tr -d '\r' < "$toc_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^#/d' -e '/^$/d' | tr '\134' '/')
if [ -z "$toc_entries" ]; then
  echo "error: $toc_file does not list any file" >&2
  exit 1
fi

problems=0
for entry in $toc_entries; do
  if [ ! -f "$root_directory/$entry" ]; then
    echo "error: listed in the TOC but missing: $entry" >&2
    problems=1
  fi
done

for folder in $addon_folders; do
  if [ ! -d "$root_directory/$folder" ]; then
    echo "error: addon folder missing: $folder" >&2
    problems=1
  fi
done

lua_files=$(cd "$root_directory" && for folder in $addon_folders; do [ -d "$folder" ] && find "$folder" -type f -name '*.lua'; done | sort)
for lua_file in $lua_files; do
  listed=0
  for entry in $toc_entries; do
    if [ "$entry" = "$lua_file" ]; then
      listed=1
    fi
  done
  if [ "$listed" -eq 0 ]; then
    echo "error: Lua file not listed in the TOC (the game would never load it): $lua_file" >&2
    problems=1
  fi
done

if [ "$problems" -ne 0 ]; then
  exit 1
fi

mkdir -p "$dist_directory"
dist_directory=$(cd "$dist_directory" && pwd)
archive="$dist_directory/Healsilus-$version.zip"
rm -f "$archive"

# El zip siempre contiene la carpeta "Healsilus/", sea cual sea el nombre de la carpeta del repositorio.
staging_directory=$(mktemp -d)
trap 'rm -rf "$staging_directory"' EXIT
mkdir "$staging_directory/Healsilus"
cp "$toc_file" "$root_directory/README.md" "$staging_directory/Healsilus/"
for folder in $addon_folders; do
  cp -R "$root_directory/$folder" "$staging_directory/Healsilus/$folder"
done
(cd "$staging_directory" && zip -r -X -q "$archive" Healsilus -x '*.DS_Store')

echo "$archive"
