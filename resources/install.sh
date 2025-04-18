#!/bin/bash

# This script expected the following arguments
# 1. Github Personal Access Token

PAT_GIT="$1"

if [ $# -lt 1 ]; then
    echo "This script requires at least 1 argument (PAT_GIT), but none were passed."
    exit 1
fi

total_start_time=$(date +%s.%2N)

echo "[1/5]: Check for Zef updates and the current version installed:"

zef update
zef --version
raku --version

echo "[2/5]: Start installing external dependencies through Zef:"

external_start_time=$(date +%s.%2N)

zef install Digest::SHA1::Native --/test
zef install Cro::HTTP::Router --/test
zef install URI::Encode --/test
zef install Lingua::NumericWordForms --/test
zef install WWW::OpenAI --/test
zef install WWW::PaLM --/test
zef install WWW::Gemini --/test
zef install WWW::MistralAI --/test
zef install WWW::LLaMA --/test
zef install LLM::Functions --/test
zef install LLM::Prompts --/test
zef install LLM::RetrievalAugmentedGeneration --/test
zef install ML::FindTextualAnswer --/test
zef install LLM::Containerization --/test

external_end_time=$(date +%s.%2N)
echo "EXTERNAL: Installation time: $(echo "scale=2; $external_end_time - $external_start_time" | bc)s"

internal_start_time=$(date +%s.%2N)

#echo "[3/5]: Start cloning internal dependencies:"
echo "[3/5]: No internal dependencies."

#echo "[4/5]: Start installing internal cloned repositories through Zef:"
echo "[4/5]: No internal cloned repositories."

internal_end_time=$(date +%s.%2N)
echo "INTERNAL: Installation time: $(echo "scale=2; $internal_end_time - $internal_start_time" | bc)s"

#zef install . --/test

total_end_time=$(date +%s.%2N)
echo "[5/5] TOTAL: Installation time: $(echo "scale=2; $total_end_time - $total_start_time" | bc)s"