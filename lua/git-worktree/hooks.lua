---@mod git-worktree.hooks hooks

local M = {}

---@enum git-worktree.hooks.type
M.type = {
    CREATE = 'CREATE',
    DELETE = 'DELETE',
    SWITCH = 'SWITCH',
}

local hooks = {
    [M.type.CREATE] = {},
    [M.type.DELETE] = {},
    [M.type.SWITCH] = {},
}
local count = 0

---@alias git-worktree.hooks.cb.create fun(path: string, branch: string, upstream: string)
---@alias git-worktree.hooks.cb.delete fun(path: string)
---@alias git-worktree.hooks.cb.switch fun(path: string, prev_path: string)

--- Registers a hook
---
--- Each hook type takes a callback a different function
---@param type git-worktree.hooks.type
---@param cb function
---@overload fun(type: 'CREATE', cb: git-worktree.hooks.cb.create): string
---@overload fun(type: 'DELETE', cb: git-worktree.hooks.cb.delete): string
---@overload fun(type: 'SWITCH', cb: git-worktree.hooks.cb.switch): string
M.register = function(type, cb)
    count = count + 1
    local hook_id = type .. '_' .. tostring(count)
    hooks[type][hook_id] = cb
    return hook_id
end

--- Emits an event and calls all the hook callbacks registered
---@param type git-worktree.hooks.type
---@param ... any
function M.emit(type, ...)
    for _, hook in pairs(hooks[type]) do
        hook(...)
    end
end

local Path = require('plenary.path')

--- Built in hooks
---
--- You can register them yourself using `hooks.register`
---
--- <code>
--- hooks.register(
---     hooks.type.SWTICH,
---     hooks.builtins.update_current_buffer_on_switch,
--- )
--- </code>
M.builtins = {
    ---@type git-worktree.hooks.cb.switch
    update_current_buffer_on_switch = function(_, prev_path)
        local config = require('git-worktree.config')
        if prev_path == nil then
            vim.cmd(config.update_on_change_command)
        end

        local cwd = vim.loop.cwd()
        local current_buf_name = vim.api.nvim_buf_get_name(0)
        if not current_buf_name or current_buf_name == '' then
            vim.cmd(config.update_on_change_command)
        end

        local name = Path:new(current_buf_name):absolute()
        local start1, _ = string.find(name, cwd .. Path.path.sep, 1, true)
        if start1 ~= nil then
            return
        end

        local start, fin = string.find(name, prev_path, 1, true)
        if start == nil then
            vim.cmd(config.update_on_change_command)
        end

        local local_name = name:sub(fin + 2)

        local final_path = Path:new({ cwd, local_name }):absolute()

        if not Path:new(final_path):exists() then
            vim.cmd(config.update_on_change_command)
        end

        local bufnr = vim.fn.bufnr(final_path, true)
        vim.api.nvim_set_current_buf(bufnr)
    end,
}

return M
