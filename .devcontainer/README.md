# DevContainer for ComputerAdaptiveTesting.jl

This directory contains the development container configuration for ComputerAdaptiveTesting.jl, based on the [Claude Code reference implementation](https://github.com/anthropics/claude-code/tree/main/.devcontainer).

## Features

- **Julia 1.11**: Latest stable Julia version with full development environment
- **Claude Code Pattern**: Follows the same structure as Claude's reference devcontainer
- **Security**: Includes firewall initialization for secure development
- **Modern Shell**: Zsh with Oh My Zsh, Git integration, and history search
- **Enhanced Git**: Git Delta for improved diffs and GitLens integration
- **VS Code Extensions**: Pre-configured with Julia language support and development tools
- **Persistent Storage**: Command history and Julia packages persist across rebuilds

## Quick Start

1. **Prerequisites**: Install VS Code and the Dev Containers extension
2. **Open**: Open this repository in VS Code
3. **Reopen in Container**: Command Palette → "Dev Containers: Reopen in Container"
4. **Wait**: The container will build and set up the environment automatically (first build takes ~10 minutes)

## What's Included

### Architecture (Claude Code Pattern)
- **Custom Dockerfile**: Multi-stage build with Julia base image
- **Security-first**: Network capabilities and firewall initialization
- **User-based**: Runs as `julia` user (not root) for security
- **Persistent volumes**: Separate volumes for command history and Julia depot
- **Workspace mounting**: Project mounted to `/workspace` following Claude pattern

### VS Code Extensions
- Julia Language Support with full IntelliSense
- GitLens for enhanced Git integration
- Code Spell Checker
- Markdown support with linting
- JSON support
- Jupyter support

### Shell Environment
- **Zsh** with Oh My Zsh (robbyrussell theme)
- **Git integration** with status in prompt
- **History search** with arrow keys
- **Persistent command history** across container restarts
- **SSH agent** support

### Development Tools
- **Claude Code CLI**: Full Claude Code experience in the container
- **Git Delta**: Beautiful diffs with syntax highlighting
- **GitHub CLI** for repository management
- **fzf**: Fuzzy finder for command line
- **Standard Unix tools**: less, vim, nano, man pages

### Julia Environment
- **Project instantiation**: Main dependencies automatically installed
- **Registry resolution**: Avoids local path issues by resolving from Julia General registry
- **Startup script**: Automatic loading of development conveniences
- **Depot persistence**: Julia packages cached across container rebuilds

### Security Features
- **Firewall initialization**: Restricts network access to essential services
- **Julia infrastructure**: Pre-configured access to Julia package registry, GitHub, etc.
- **Network capabilities**: Required for firewall management
- **Allowlist approach**: Only permitted domains/IPs are accessible

## Usage

### Running Tests
```bash
# In the container terminal (Zsh)
julia --project=test test/runtests.jl
```

### Building Documentation
```bash
julia --project=docs docs/make.jl
```

### Interactive Development
```bash
# Start Julia REPL with project activated
julia --project=.

# Install additional development tools as needed
julia --project=. -e "using Pkg; Pkg.add([\"Revise\", \"OhMyREPL\", \"BenchmarkTools\"])"
```

### Git Workflow
```bash
# Enhanced Git experience with Delta
git diff           # Beautiful syntax-highlighted diffs
git log --oneline  # Clean commit history
gh pr create       # Create pull requests via CLI
```

### Claude Code Usage

The container is configured to support Claude Code. Installation requires Node.js/npm:

```bash
# Install Node.js and npm first (if not already installed)
sudo apt-get update && sudo apt-get install -y nodejs npm

# Install Claude Code CLI
sudo npm install -g @anthropic-ai/claude-code

# Use Claude Code within the container
claude              # Start interactive Claude session
claude "Explain this Julia function" < src/MyModule.jl
claude --help       # See all available options

# Example: Get help with Julia development
claude "How can I optimize this Julia code for performance?"
```

**Note**:
- The firewall configuration may need to be adjusted to allow npm package downloads
- Claude Code requires proper API authentication setup
- Installation may require temporarily disabling the firewall or adding package repository domains to the allowlist

## File Structure

- `devcontainer.json` - Main container configuration (Claude Code pattern)
- `Dockerfile` - Custom Julia development image with security features
- `post-create.sh` - Setup script run after container creation
- `init-firewall.sh` - Security initialization (adapted from Claude reference)
- `startup.jl` - Julia startup script for development convenience
- `README.md` - This documentation

## Key Differences from Simple Devcontainer

This implementation follows the Claude Code reference pattern with several advantages:

1. **Security-first**: Firewall and network restrictions
2. **Better shell**: Zsh with full Git integration vs basic bash
3. **Enhanced Git**: Delta for beautiful diffs, GitLens integration
4. **User-based**: Runs as `julia` user vs root
5. **Persistent storage**: Separate volumes for different data types
6. **Build caching**: Optimized Docker layers for faster rebuilds

## Customization

You can customize the development environment by:

1. **Adding VS Code extensions**: Edit the `extensions` array in `devcontainer.json`
2. **Modifying firewall rules**: Update `init-firewall.sh` to allow additional domains
3. **Installing additional packages**: Modify `post-create.sh`
4. **Changing Julia settings**: Update the `settings` in `devcontainer.json`

## Troubleshooting

### Container won't start
- Check Docker is running and you have the necessary permissions
- Try rebuilding: Command Palette → "Dev Containers: Rebuild Container"

### Network connectivity issues
- Check firewall rules in `init-firewall.sh`
- Firewall initialization failures are non-fatal but may limit network access

### Julia packages not installing
- The environment resolves packages from the Julia General registry
- Local Manifest.toml is removed to avoid path conflicts
- First-time package installation takes longer due to compilation

### Slow startup
- First build takes ~10 minutes due to installing development tools
- First Julia package installation takes additional time for compilation
- Subsequent starts are much faster due to Docker layer caching and Julia precompilation

## Performance Tips

1. **Package precompilation** is cached in persistent Julia depot volume
2. **Docker build caching** speeds up container rebuilds
3. **Command history persistence** maintains your workflow across sessions
4. **Optimized package resolution** avoids local path conflicts

## Security Notes

This devcontainer includes security features following the Claude Code pattern:

- **Firewall restrictions**: Only essential domains are accessible
- **Network capabilities**: Required for firewall management (NET_ADMIN, NET_RAW)
- **Julia infrastructure**: Pre-configured access to necessary Julia services
- **Non-root user**: Runs as `julia` user for reduced privilege

## Contributing

If you improve this devcontainer setup, please:
1. Update this README with your changes
2. Test with `devcontainer up --workspace-folder .`
3. Submit a pull request following the project's contribution guidelines
