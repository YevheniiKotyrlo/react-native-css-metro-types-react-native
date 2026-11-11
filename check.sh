#!/usr/bin/env bash
# Type-checks metro.config.ts, a Metro config typed through react-native-css/metro, as a Node program ("types":
# ["node"], skipLibCheck: false). Exits 1 while the program loads React Native's declarations, 0 once it loads none and
# metro.config.ts type-checks, and 2 when a step fails or the program does not load react-native-css/metro's
# declarations.
set -uo pipefail

cd "$(dirname "$0")" || exit 2

readonly METRO_ENTRY='node_modules/react-native-css/dist/typescript/module/src/metro/index.d.ts'
readonly REACT_NATIVE_ENTRY='node_modules/react-native/types_generated/index.d.ts'

package_version() {
  node -p "require('./node_modules/$1/package.json').version" 2>/dev/null || printf 'not installed'
}

if [ -f package-lock.json ]; then
  install_command=(npm ci --ignore-scripts --no-audit --no-fund)
else
  install_command=(npm install --ignore-scripts --no-audit --no-fund)
fi
if ! "${install_command[@]}" >install.log 2>&1; then
  tail -n 20 install.log
  echo "SUMMARY: step failed: ${install_command[*]} (install.log)"
  exit 2
fi

system_name=$(uname -s) || exit 2
node_version=$(node --version) || exit 2
npm_version=$(npm --version) || exit 2
package_versions=""
for package in react-native-css react-native typescript @types/node; do
  version=$(package_version "$package") || exit 2
  package_versions+=", $package $version"
done
echo "System: $system_name, node $node_version, npm $npm_version$package_versions"

npx --no-install tsc -p tsconfig.json --pretty false --explainFiles >compiler-output.txt 2>&1
compiler_status=$?
if [ "$compiler_status" -gt 2 ] || ! grep -q -E '/lib\.es5\.d\.ts$' compiler-output.txt; then
  tail -n 20 compiler-output.txt
  echo "SUMMARY: step failed: tsc exited $compiler_status without listing its files (compiler-output.txt)"
  exit 2
fi
if ! grep -q -x -F "$METRO_ENTRY" compiler-output.txt; then
  echo "SUMMARY: step failed: the program did not load $METRO_ENTRY"
  exit 2
fi

error_count=$(grep -c ': error TS' compiler-output.txt)
globals_errors=$(grep -E '^node_modules/(@types/node|@types/react|react-native)/[^(]+\([0-9]+,[0-9]+\): error TS' compiler-output.txt)
config_errors=$(grep -E '^metro\.config\.ts\(' compiler-output.txt)

if grep -q -x -F "$REACT_NATIVE_ENTRY" compiler-output.txt; then
  head -n 5 <<<"$globals_errors"
  echo "$REACT_NATIVE_ENTRY"
  grep -A 1 -x -F "$REACT_NATIVE_ENTRY" compiler-output.txt | grep -m 1 'Imported via "react-native" from file .node_modules/react-native-css/'
  globals_count=0
  if [ -n "$globals_errors" ]; then
    globals_count=$(grep -c '' <<<"$globals_errors")
  fi
  echo "SUMMARY: defect: react-native-css/metro's declarations load React Native's, and the program has $error_count errors, $globals_count of them in the global declarations of @types/node, @types/react and React Native"
  exit 1
fi
if [ -n "$config_errors" ] || [ "$error_count" -gt 0 ]; then
  grep ': error TS' compiler-output.txt | head -n 20
  echo "SUMMARY: step failed: the program loads no React Native declaration, but has $error_count errors"
  exit 2
fi
echo "SUMMARY: fixed: react-native-css/metro's declarations load no React Native declaration, and metro.config.ts type-checks"
exit 0
