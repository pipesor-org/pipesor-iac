export default {
  extends: ['@commitlint/config-angular'],
  defaultIgnores: false,
  rules: {
    'subject-case': [2, 'always', 'lower-case'],
  },
};
