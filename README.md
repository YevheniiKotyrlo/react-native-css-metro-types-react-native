# react-native-css/metro's declarations in a Node program

`metro.config.ts` types a Metro config through `react-native-css/metro` and is checked as a Node program
(`"types": ["node"]`, `skipLibCheck: false`). `@types/connect`, `@types/babel__core` and `@types/babel__traverse` are
installed so that Metro's own declarations type-check.

```sh
bash check.sh
```

It exits 1 while the program loads React Native's declarations, 0 once it loads none and `metro.config.ts`
type-checks, and 2 when a step fails.
