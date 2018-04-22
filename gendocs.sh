#!/bin/bash

set -ex
# rm -rf docs
# git clone -b gh-pages https://github.com/kirbyfan64/amai docs
sourcekitten doc --spm-module Amai > amai-docs.json
jazzy \
  --clean \
  --module Amai \
  --sourcekitten-sourcefile amai-docs.json \
  --hide-documentation-coverage \
  --author 'Ryan Gonzalez' \
  --author_url 'https://refi64.com' \
  --github_url 'https://github.com/kirbyfan64/Amai' \
  --documentation pages/*.md \
  --readme index.md
