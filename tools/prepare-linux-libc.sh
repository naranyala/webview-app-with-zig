#!/usr/bin/env bash
set -euo pipefail

config_file="$1"
output_dir="${config_file%/*}/crt"
compiler="${CC:-cc}"
objcopy_bin="${OBJCOPY:-objcopy}"
crt1_path="$($compiler -print-file-name=crt1.o)"
system_crt_dir="$(cd "${crt1_path%/*}" && pwd -P)"

if [[ ! -f "$crt1_path" ]]; then
  printf 'error: could not locate crt1.o using %s\n' "$compiler" >&2
  exit 1
fi

mkdir -p "$output_dir"
for crt_file in crt1.o Scrt1.o rcrt1.o gcrt1.o crti.o crtn.o; do
  source_file="$system_crt_dir/$crt_file"
  if [[ -f "$source_file" ]]; then
    "$objcopy_bin" \
      --remove-section=.sframe \
      --remove-section=.rela.sframe \
      "$source_file" "$output_dir/$crt_file"
  fi
done

# Keep only the basic system libraries visible from the isolated crt directory.
for library in libc libm libpthread libdl librt libutil; do
  source_file="$system_crt_dir/$library.so"
  if [[ ! -e "$source_file" ]]; then
    for versioned in "$system_crt_dir/$library.so".*; do
      if [[ -e "$versioned" ]]; then
        source_file="$versioned"
        break
      fi
    done
  fi
  if [[ -e "$source_file" ]]; then
    ln -sfn -- "$source_file" "$output_dir/$library.so"
  fi
done

printf 'include_dir=/usr/include\n' > "$config_file"
printf 'sys_include_dir=/usr/include\n' >> "$config_file"
printf 'crt_dir=%s\n' "$output_dir" >> "$config_file"
printf 'msvc_lib_dir=\n' >> "$config_file"
printf 'kernel32_lib_dir=\n' >> "$config_file"
printf 'gcc_dir=\n' >> "$config_file"
