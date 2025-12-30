# Contributing to VibeMobile

Thank you for your interest in contributing to VibeMobile! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and constructive in all interactions. We welcome contributors of all experience levels.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up the development environment (see README.md)
4. Create a new branch for your feature/fix

## Development Setup

### Prerequisites

- Node.js 18+
- Flutter 3.5+ (for desktop app)
- tmux
- Git

### Setting Up the Project

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/VibeMobile.git
cd VibeMobile

# Install web dependencies
cd web
npm install

# Install desktop dependencies (optional)
cd ../desktop
flutter pub get
```

### Running in Development

```bash
# Start web server + frontend with hot-reload
cd web
npm run dev

# Run desktop app
cd desktop
flutter run -d macos
```

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/add-file-preview` - New features
- `fix/websocket-reconnect` - Bug fixes
- `docs/update-api-docs` - Documentation
- `refactor/simplify-auth` - Code refactoring

### Code Style

#### TypeScript/JavaScript (web)

- Use TypeScript for all new code
- Follow existing code patterns
- Run `npm run lint` before committing
- Use meaningful variable and function names

#### Dart/Flutter (desktop)

- Follow Flutter/Dart style guidelines
- Use `flutter analyze` to check for issues
- Keep widgets focused and composable

### Commit Messages

Write clear, concise commit messages:

```
feat: Add file preview for markdown files

- Support .md files with syntax highlighting
- Add preview toggle button in file browser
- Cache rendered content for performance
```

Use conventional commit prefixes:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Tests
- `chore:` - Build/config changes

## Pull Requests

### Before Submitting

1. Ensure your code passes linting
2. Test your changes manually
3. Update documentation if needed
4. Rebase on the latest main branch

### PR Description

Include in your PR:
- Summary of changes
- Screenshots for UI changes
- Testing steps
- Related issues (if any)

### Review Process

1. A maintainer will review your PR
2. Address any feedback
3. Once approved, your PR will be merged

## Reporting Issues

### Bug Reports

Include:
- Steps to reproduce
- Expected behavior
- Actual behavior
- Environment (OS, Node version, etc.)
- Screenshots/logs if applicable

### Feature Requests

Include:
- Use case description
- Proposed solution
- Alternative approaches considered

## Project Structure

```
VibeMobile/
├── web/                # Node.js server + React frontend
│   ├── server/        # Express backend
│   └── src/           # React frontend
├── desktop/           # Flutter desktop app
├── scripts/           # Utility scripts
└── docs/              # Documentation
```

## Areas for Contribution

We especially welcome contributions in:

- **Bug fixes** - Check the issues labeled `bug`
- **Documentation** - Help improve guides and API docs
- **Testing** - Add test coverage
- **Accessibility** - Improve a11y support
- **Internationalization** - Add language support
- **Platform support** - Windows/Linux desktop apps

## Questions?

Feel free to open an issue for questions or join discussions on existing issues.

Thank you for contributing!
