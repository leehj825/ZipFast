#!/usr/bin/env bash
# Host-JVM tests for the 7-Zip based ArchiveBridge (no Android SDK needed).
# Usage: android/engine-test/run_tests.sh   (needs JDK 11+, python3 with py7zr+pycdlib, network for Maven Central)
set -euo pipefail
cd "$(dirname "$0")"
V=16.02-2.01
LIB=.lib
mkdir -p "$LIB" .out
for a in sevenzipjbinding sevenzipjbinding-linux-amd64; do
  [ -f "$LIB/$a-$V.jar" ] || curl -fsS -o "$LIB/$a-$V.jar" "https://repo1.maven.org/maven2/net/sf/sevenzipjbinding/$a/$V/$a-$V.jar"
done
[ -d fixtures ] || python3 make_fixtures.py
CP="$LIB/sevenzipjbinding-$V.jar:$LIB/sevenzipjbinding-linux-amd64-$V.jar"
javac -nowarn -cp "$CP" -d .out ../app/src/main/java/com/zipfast/zipfast/engine/*.java BridgeTest.java
java -cp ".out:$CP" BridgeTest fixtures
