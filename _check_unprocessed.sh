#!/bin/bash
cd /c/my-wiki || exit 1
blob=$(cat wiki/*.md)
for r in raw/*; do
  name=$(basename "$r")
  if [ "$name" = ".gitkeep" ]; then continue; fi
  case "$blob" in
    *"$name"*) ;;
    *) echo "UNPROCESSED: $name" ;;
  esac
done
