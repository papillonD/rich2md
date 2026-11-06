#!/bin/zsh
# Converts each fixture and compares the result with the expected Markdown.
# expected/NAME.md uses the default flavor; expected/NAME.FLAVOR.md uses that flavor.
setopt null_glob
DIR="${0:A:h}"
BIN="$(mktemp -d)/rich2md"
swiftc -O "${DIR:h}/rich2md.swift" -o "$BIN" || exit 1

failed=0
for expected in "$DIR"/expected/*.md; do
  base="${expected:t:r}"
  name="${base%%.*}"
  flavor=markdown; [[ "$base" == *.* ]] && flavor="${base#*.}"
  input=( "$DIR"/fixtures/"$name".(html|rtf) )
  if output=$("$BIN" convert "${input[1]}" --flavor "$flavor") && [[ "$output" == "$(<"$expected")" ]]; then
    echo "ok    $base"
  else
    echo "FAIL  $base"
    diff -u "$expected" <(print -r -- "$output")
    failed=1
  fi
done
exit $failed
