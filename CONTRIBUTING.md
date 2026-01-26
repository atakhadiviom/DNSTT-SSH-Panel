# Contributing to DNSTT SSH Panel

Thank you for your interest in contributing to DNSTT SSH Panel! This document provides guidelines and instructions for contributing.

## How to Contribute

### Reporting Bugs

1. Check existing [issues](../../issues) to avoid duplicates
2. Use the bug report template
3. Include:
   - Ubuntu/OS version
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant logs (`journalctl -u dnstt-server`)

### Suggesting Features

1. Open a feature request issue
2. Describe the use case
3. Explain how it benefits users

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes
4. Test on Ubuntu 24.04 LTS
5. Commit with clear messages:
   ```bash
   git commit -m "feat: add new feature description"
   ```
6. Push and create PR

## Code Style

### Bash Scripts

- Use `shellcheck` for linting
- Add comments for complex logic
- Use functions for reusability
- Follow existing formatting style
- Quote variables: `"$variable"`
- Use `[[ ]]` for conditionals

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `refactor:` Code refactoring
- `test:` Testing
- `chore:` Maintenance

## Testing

Before submitting:

1. Test installer on clean Ubuntu 24.04
2. Verify all panel functions work
3. Check service starts correctly
4. Test client connections

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
