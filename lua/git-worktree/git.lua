local Job = require('plenary.job')
local Path = require('plenary.path')
local Log = require('git-worktree.logger')

---@class GitWorktreeGitOps
local M = {}

-- A lot of this could be cleaned up if there was better job -> job -> function
-- communication.  That should be doable here in the near future
---
---@param path_str string path to the worktree to check
---@param branch string? branch the worktree is associated with
---@param cb any
function M.has_worktree(path_str, branch, cb)
    local found = false
    local path

    if path_str == '.' then
        path_str = vim.loop.cwd()
    end

    path = Path:new(path_str)
    if not path:is_absolute() then
        path = Path:new(string.format('%s' .. Path.path.sep .. '%s', vim.loop.cwd(), path_str))
    end
    path = path:absolute()

    Log.debug('has_worktree: %s %s', path, branch)

    local job = Job:new {
        command = 'git',
        args = { 'worktree', 'list', '--porcelain' },
        on_stdout = function(_, line)
            if line:match('^worktree ') then
                local current_worktree = Path:new(line:match('^worktree (.+)$')):absolute()
                Log.debug('current_worktree: "%s"', current_worktree)
                if path == current_worktree then
                    found = true
                    return
                end
            elseif branch ~= nil and line:match('^branch ') then
                local worktree_branch = line:match('^branch (.+)$')
                Log.debug('worktree_branch: %s', worktree_branch)
                if worktree_branch == 'refs/heads/' .. branch then
                    found = true
                    return
                end
            end
        end,
        cwd = vim.loop.cwd(),
    }

    job:after(function()
        Log.debug('calling after')
        cb(found)
    end)

    Log.debug('Checking for worktree %s', path)
    job:start()
end

--- @return string|nil
function M.gitroot_dir()
    local job = Job:new {
        command = 'git',
        args = { 'rev-parse', '--path-format=absolute', '--git-common-dir' },
        cwd = vim.loop.cwd(),
        on_stderr = function(_, data)
            Log.error('ERROR: ' .. data)
        end,
    }

    local stdout, code = job:sync()
    if code ~= 0 then
        Log.error(
            'Error in determining the git root dir: code:'
                .. tostring(code)
                .. ' out: '
                .. table.concat(stdout, '')
                .. '.'
        )
        return nil
    end

    return table.concat(stdout, '')
end

--- @return string|nil
function M.toplevel_dir()
    local job = Job:new {
        command = 'git',
        args = { 'rev-parse', '--path-format=absolute', '--show-toplevel' },
        cwd = vim.loop.cwd(),
        on_stderr = function(_, data)
            Log.error('ERROR: ' .. data)
        end,
    }

    local stdout, code = job:sync()
    if code ~= 0 then
        Log.error(
            'Error in determining the git root dir: code:'
                .. tostring(code)
                .. ' out: '
                .. table.concat(stdout, '')
                .. '.'
        )
        return nil
    end

    return table.concat(stdout, '')
end

function M.has_branch(branch, opts, cb)
    local found = false
    local args = { 'branch', '--format=%(refname)' }
    opts = opts or {}
    for _, opt in ipairs(opts) do
        args[#args + 1] = opt
    end

    local job = Job:new {
        command = 'git',
        args = args,
        on_stdout = function(_, data)
            local current = data:match('^refs/heads/(.+)') or data:match('^refs/remotes/(.+)')
            found = found or current == branch
        end,
        cwd = vim.loop.cwd(),
    }

    -- TODO: I really don't want status's spread everywhere... seems bad
    job:after(function()
        cb(found)
    end):start()
end

--- @param path string
--- @param branch string?
--- @param found_branch boolean
--- @param upstream string
--- @param found_upstream boolean
--- @return Job
function M.create_worktree_job(path, branch, found_branch, upstream, found_upstream)
    local worktree_add_cmd = 'git'
    local worktree_add_args = { 'worktree', 'add' }

    if branch == nil then
        table.insert(worktree_add_args, '-d')
        table.insert(worktree_add_args, path)
    else
        if not found_branch then
            table.insert(worktree_add_args, '-b')
            table.insert(worktree_add_args, branch)
            table.insert(worktree_add_args, path)

            if found_upstream and branch ~= upstream then
                table.insert(worktree_add_args, '--track')
                table.insert(worktree_add_args, upstream)
            end
        else
            table.insert(worktree_add_args, path)
            table.insert(worktree_add_args, branch)
        end
    end

    return Job:new {
        command = worktree_add_cmd,
        args = worktree_add_args,
        cwd = vim.loop.cwd(),
        on_start = function()
            Log.debug(worktree_add_cmd .. ' ' .. table.concat(worktree_add_args, ' '))
        end,
    }
end

--- @param path string
--- @param force boolean
--- @return Job
function M.delete_worktree_job(path, force)
    local worktree_del_cmd = 'git'
    local worktree_del_args = { 'worktree', 'remove', path }

    if force then
        table.insert(worktree_del_args, '--force')
    end

    return Job:new {
        command = worktree_del_cmd,
        args = worktree_del_args,
        cwd = vim.loop.cwd(),
        on_start = function()
            Log.debug(worktree_del_cmd .. ' ' .. table.concat(worktree_del_args, ' '))
        end,
    }
end

--- @param path string
--- @return Job
function M.fetchall_job(path)
    return Job:new {
        command = 'git',
        args = { 'fetch', '--all' },
        cwd = path,
        on_start = function()
            Log.debug('git fetch --all (This may take a moment)')
        end,
    }
end

--- @param path string
--- @param branch string
--- @param upstream string
--- @return Job
function M.setbranch_job(path, branch, upstream)
    local set_branch_cmd = 'git'
    local set_branch_args = { 'branch', branch, string.format('--set-upstream-to=%s', upstream) }
    return Job:new {
        command = set_branch_cmd,
        args = set_branch_args,
        cwd = path,
        on_start = function()
            Log.debug(set_branch_cmd .. ' ' .. table.concat(set_branch_args, ' '))
        end,
    }
end

--- @param path string
--- @param branch string
--- @param upstream string
--- @return Job
function M.setpush_job(path, branch, upstream)
    -- TODO: How to configure origin???  Should upstream ever be the push
    -- destination?
    local set_push_cmd = 'git'
    local set_push_args = { 'push', '--set-upstream', upstream, branch, path }
    return Job:new {
        command = set_push_cmd,
        args = set_push_args,
        cwd = path,
        on_start = function()
            Log.debug(set_push_cmd .. ' ' .. table.concat(set_push_args, ' '))
        end,
    }
end

--- @param path string
--- @return Job
function M.rebase_job(path)
    return Job:new {
        command = 'git',
        args = { 'rebase' },
        cwd = path,
        on_start = function()
            Log.debug('git rebase')
        end,
    }
end

--- @param path string
--- @return string|nil
function M.parse_head(path)
    local job = Job:new {
        command = 'git',
        args = { 'rev-parse', '--abbrev-ref', 'HEAD' },
        cwd = path,
        on_start = function()
            Log.debug('git rev-parse --abbrev-ref HEAD')
        end,
    }

    local stdout, code = job:sync()
    if code ~= 0 then
        Log.error('Error in parsing the HEAD: code:' .. tostring(code) .. ' out: ' .. table.concat(stdout, '') .. '.')
        return nil
    end

    return table.concat(stdout, '')
end

--- @param path string
--- @return string|nil
function M.current_branch(path)
    local job = Job:new {
        command = 'git',
        args = { 'branch', '--show-current' },
        cwd = path,
        on_start = function()
            Log.debug('git branch --show-current')
        end,
    }

    local stdout, code = job:sync()
    if code ~= 0 then
        Log.error(
            'Error in getting current branch: code:' .. tostring(code) .. ' out: ' .. table.concat(stdout, '') .. '.'
        )
        return nil
    end

    return table.concat(stdout, '')
end

--- @param branch string
--- @return Job|nil
function M.delete_branch_job(branch)
    local root = M.gitroot_dir()
    if root == nil then
        return nil
    end

    local default = M.parse_head(root)
    if default == branch then
        print('Refusing to delete default branch')
        return nil
    end

    return Job:new {
        command = 'git',
        args = { 'branch', '-D', branch },
        cwd = M.gitroot_dir(),
        on_start = function()
            Log.debug('git branch -D')
        end,
    }
end

return M
