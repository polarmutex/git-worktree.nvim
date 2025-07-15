# git-worktree-nvim - Claude Development Context

## Project Overview

**git-worktree-nvim** is a mature Neovim plugin that provides seamless git worktree management from within Neovim. It enables developers to create, switch between, and delete git worktrees with minimal friction, supporting workflows where multiple branches are worked on simultaneously in separate directory trees.

## Architecture & Core Components

### Module Structure
```
lua/git-worktree/
├── init.lua          # Public API entry point
├── worktree.lua      # Core worktree operations logic
├── git.lua           # Git command abstraction layer
├── hooks.lua         # Event-driven hook system
├── config.lua        # Configuration management
├── logger.lua        # Logging utilities
└── test/             # Test utilities

lua/telescope/_extensions/git_worktree.lua  # Telescope integration
lua/snacks-worktree/init.lua                # Snacks.nvim integration
```

### Key Design Principles
- **No setup required**: Works out of the box without calling setup()
- **Hook-driven architecture**: Extensible event system for plugin integration
- **Multiple UI options**: Both Telescope and Snacks.nvim support
- **Robust error handling**: Comprehensive git command validation and error reporting

## Public API

### Core Functions
```lua
-- Main API (lua/git-worktree/init.lua)
require("git-worktree").create_worktree(path, branch, upstream)
require("git-worktree").switch_worktree(path)  
require("git-worktree").delete_worktree(path, force, opts)

-- Hook System (lua/git-worktree/hooks.lua)
local Hooks = require("git-worktree.hooks")
Hooks.register(Hooks.type.CREATE, function(path, branch, upstream) end)
Hooks.register(Hooks.type.SWITCH, function(path, prev_path) end)
Hooks.register(Hooks.type.DELETE, function(path) end)
```

### Telescope Integration
```vim
:Telescope git_worktree                    " List and switch worktrees
:Telescope git_worktree create_git_worktree " Create new worktree
```

## Configuration

Configuration is optional via `vim.g.git_worktree`:
```lua
vim.g.git_worktree = {
  change_directory_command = 'cd',           -- OS directory change command
  update_on_change_command = 'e .',          -- Vim command for buffer updates  
  clearjumps_on_change = true,               -- Clear jump list on worktree switch
  confirm_telescope_deletions = true,        -- Confirm deletions in telescope
  autopush = false,                          -- Auto-push worktrees to origin
}
```

## Dependencies

### Required
- **Neovim >= 0.9**
- **plenary.nvim**: Job management and path utilities

### Optional
- **telescope.nvim**: Primary UI interface
- **snacks.nvim**: Alternative picker interface (recently added)

## Development Environment

### Nix-based Workflow
- **Primary development**: Uses Nix flake for reproducible environment
- **Multiple Lua versions**: Supports various Neovim/Lua combinations
- **Dev shell**: `nix develop` provides complete development environment

### Quality Tools
- **Luacheck**: Lint with `luacheck lua/`
- **Stylua**: Format with `stylua lua/`
- **Pre-commit hooks**: Automated quality checks
- **Make targets**: `make lint`, `make test`

### Testing
- **Framework**: Plenary.nvim test harness with busted
- **Test files**: Located in `spec/` directory
- **Test utilities**: Custom git helpers in `lua/git-worktree/test/`
- **Run tests**: `make test` or `nvim --headless -c "PlenaryBustedDirectory spec/"`

## Key Implementation Details

### Git Operations (lua/git-worktree/git.lua)
- Uses plenary.nvim Job system for async git commands
- Comprehensive validation of worktree/branch existence
- Handles upstream tracking and branch creation
- Error handling with user-friendly messages

### Worktree Logic (lua/git-worktree/worktree.lua)
- Orchestrates directory changes and git operations
- Manages buffer updates and jump list clearing
- Handles validation and user confirmation flows
- Integrates with hook system for extensibility

### Hook System (lua/git-worktree/hooks.lua)
- Event types: CREATE, DELETE, SWITCH
- Built-in hooks for buffer management
- Allows plugin integrations and custom workflows

## Common Development Tasks

### Adding New Features
1. Implement core logic in `lua/git-worktree/worktree.lua`
2. Add git operations in `lua/git-worktree/git.lua` if needed
3. Update public API in `lua/git-worktree/init.lua`
4. Add hooks/events if applicable
5. Update telescope integration if UI changes needed
6. Write tests in `spec/`
7. Update documentation in `doc/git-worktree.txt`

### Debugging Issues
- Check git command execution in `git.lua`
- Verify hook execution in `hooks.lua`
- Test directory changes and buffer updates
- Use logging utilities for troubleshooting

### Testing Changes
```bash
# Lint code
make lint
luacheck lua/

# Run tests
make test
nvim --headless -c "PlenaryBustedDirectory spec/"

# Format code  
stylua lua/
```

## Recent Development Focus

### Recent Additions
- **Snacks.nvim integration**: Alternative to Telescope picker
- **Enhanced error handling**: Better user feedback and validation
- **Improved git operations**: More robust branch and upstream handling
- **Code quality**: Fixed linting issues and improved consistency

### Current Architecture Strengths
- Clear separation of concerns between modules
- Extensible hook system for customization
- Multiple UI options for different workflows
- Comprehensive testing coverage
- Professional development environment with Nix

## Integration Points

### With Other Plugins
- **Telescope**: Primary UI integration for worktree management
- **Snacks**: Alternative modern picker interface
- **LSP**: Works seamlessly with language servers across worktrees
- **File trees**: Integrates with nvim-tree, neo-tree via hooks

### With External Tools
- **Git**: Direct integration with git worktree commands
- **Shell**: Respects shell directory changes
- **File watchers**: Compatible with external file watching tools

## Performance Considerations

- **Async operations**: Git commands run asynchronously via plenary Jobs
- **Minimal startup impact**: No setup function required, lazy loading friendly
- **Efficient git queries**: Caches git repository information
- **Smart buffer management**: Only updates buffers when necessary

## Future Development Areas

### Potential Enhancements
- **Git worktree status**: Enhanced status reporting and validation
- **Worktree templates**: Predefined worktree creation templates
- **Integration improvements**: Better LSP server management across worktrees
- **Performance optimization**: Caching and background operations
- **UI enhancements**: Improved visual feedback and progress indicators

This CLAUDE.md provides comprehensive context for future development work on git-worktree-nvim. The plugin demonstrates excellent software engineering practices with clear architecture, comprehensive testing, and professional development tooling.