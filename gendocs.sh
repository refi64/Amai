#!/bin/bash

set -ex
sourcekitten doc --spm-module Amai > amai-docs.json
jazzy \
  --module Amai \
  --clean \
  --sourcekitten-sourcefile amai-docs.json \
  --hide-documentation-coverage \
  --author 'Ryan Gonzalez' \
  --author_url 'https://refi64.com' \
  --github_url 'https://github.com/kirbyfan64/Amai' \
  --readme index.md
