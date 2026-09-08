#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmdb="${TMDB_SOURCE:-/workspace/tmdb}"
xmltv="${XMLTV_SOURCE:-/workspace/xmltv-import}"
sagemc="${SAGEMC_SOURCE:-/workspace/sagemc}"
core="${CORE_SOURCE:-/work/sagetv}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for required in \
  "$tmdb/output/classes/org/opensagetv/vibe/tmdb/TmdbMetadataService.class" \
  "$xmltv/output/classes/xmltv/TmdbEnricher.class" \
  "$sagemc/.build/tmdb-adapter/classes/org/opensagetv/vibe/sagemc/tmdb/SageMcTmdb.class" \
  "$core/output/server/Sage.jar"; do
  test -s "$required" || { echo "ERROR: missing consumer-stress input: $required" >&2; exit 2; }
done

classpath="$tmdb/output/classes:$xmltv/output/classes:$sagemc/.build/tmdb-adapter/classes"
classpath="$classpath:$tmdb/output/packages/gson-2.14.0.jar:$tmdb/output/packages/sqlite-jdbc-3.53.2.1.jar"
classpath="$classpath:$core/output/server/Sage.jar"

javac -encoding UTF-8 --release 8 -classpath "$classpath" -d "$work/classes" \
  "$root/tests/tmdb-consumers/org/opensagetv/vibe/tmdb/CrossConsumerFixture.java" \
  "$root/tests/tmdb-consumers/xmltv/CrossConsumerStress.java"
java -classpath "$work/classes:$classpath" xmltv.CrossConsumerStress
