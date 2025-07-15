local git_worktree = require('git-worktree')
local Git = require('git-worktree.git')
local Snacks = require('snacks')
local uv = vim.uv or vim.loop

local force_next_deletion = false

---@module "snacks-worktree"
local snacks_worktree = {}

-- Switch to the selected worktree
-- @param picker Snacks.picker
-- @param item Snacks.picker.Item
-- @return nil
local switch_worktree = function(picker, item)
    local worktree_path = item.path
    if worktree_path == nil then
        vim.print('no worktree selected')
    end

    picker:close()
    git_worktree.switch_worktree(worktree_path)
end

-- Toggle the forced deletion of the next worktree
-- @return nil
local toggle_forced_deletion = function()
    -- redraw otherwise the message is not displayed when in insert mode
    if force_next_deletion then
        print('The next deletion will not be forced')
        vim.fn.execute('redraw')
    else
        print('The next deletion will be forced')
        vim.fn.execute('redraw')
        force_next_deletion = true
    end
end

-- Confirm the deletion of a worktree
-- @param item snacks.picker.Item
-- @param proceed fun(val: string)
-- @return nil
local confirm_worktree_deletion = function(item, proceed)
    local prompt = 'Delete worktree %q?'
    if force_next_deletion then
        prompt = 'Force deletion of worktree %q?'
    end
    Snacks.picker.select({ 'Yes', 'No' }, { prompt = (prompt):format(item.path) }, function(_, idx)
        if idx ~= 1 then
            print("Didn't delete worktree")
            return
        end
        proceed()
    end)
end

-- Confirm the deletion of a branch
-- @return boolean: whether the deletion is confirmed
local confirm_branch_deletion = function()
    local confirmed = vim.fn.input('Worktree deleted, now force deletion of branch? [y/n]: ')

    if string.sub(string.lower(confirmed), 0, 1) == 'y' then
        return true
    end

    print("Didn't delete branch")
    return false
end

local delete_success_handler = function(opts)
    opts = opts or {}
    force_next_deletion = false
    if opts.branch ~= nil and opts.branch ~= 'HEAD' and confirm_branch_deletion() then
        local delete_branch_job = Git.delete_branch_job(opts.branch)
        if delete_branch_job ~= nil then
            delete_branch_job:after_success(vim.schedule_wrap(function()
                print('Branch deleted')
            end))
            delete_branch_job:start()
        end
    end
end

-- Handler for failed deletion
-- @return nil
local delete_failure_handler = function()
    print('Deletion failed, use <C-f> to force the next deletion')
end

-- Delete the selected worktree
-- @param picker Snacks.picker
-- @param item Snacks.picker.Item
-- @return nil
local delete_worktree = function(picker, item)
    if not item then
        Snacks.notify.warn('No worktree to delete', { title = 'Snacks Picker' })
    end
    confirm_worktree_deletion(item, function()
        local worktree_path = item.path
        picker:close()
        if worktree_path ~= nil then
            git_worktree.delete_worktree(worktree_path, force_next_deletion, {
                on_failure = delete_failure_handler,
                on_success = delete_success_handler,
            })
        end
    end)
end

-- Create a prompt to get the path of the new worktree
-- @param cb fun(path: string): the callback to call with the path
-- @return nil
local create_input_prompt = function(cb)
    vim.ui.input({
        prompt = 'Path to subtree',
    }, cb)
end

function snacks_worktree.create_worktree()
    Snacks.picker {
        all = false,
        finder = 'git_branches',
        format = 'git_branch',
        preview = 'git_log',
        confirm = function(picker, item)
            if not item then
                print('No item provided')
            end
            local branch = item.branch
            picker:close()
            create_input_prompt(function(name)
                if name == '' then
                    name = branch
                end
                git_worktree.create_worktree(name, branch)
            end)
        end,
    }
end

local finder = function(opts, ctx)
    local args = { 'worktree', 'list' }
    local cwd = vim.fs.normalize(opts and opts.cwd or uv.cwd() or '.') or nil
    cwd = Snacks.git.get_root(cwd)
    local current = Git.toplevel_dir()
    return require('snacks.picker.source.proc').proc({
        opts,
        {
            cwd = cwd,
            cmd = 'git',
            args = args,
            ---@param item snacks.picker.finder.Item
            transform = function(item)
                item.cwd = cwd
                local fields = vim.split(string.gsub(item.text, '%s+', ' '), ' ')
                item.path = fields[1]
                item.current = current == item.path
                item.sha = fields[2]
                item.branch = fields[3]
                if item.sha == '(bare)' then
                    return false
                end
            end,
        },
    }, ctx)
end

local format = function(item, _)
    local a = Snacks.picker.util.align
    local ret = {} ---@type snacks.picker.Highlight[]
    if item.current then
        ret[#ret + 1] = { a('', 2), 'SnacksPickerGitBranchCurrent' }
    else
        ret[#ret + 1] = { a('', 2) }
    end
    ret[#ret + 1] = { a(item.branch, 30, { truncate = true }), 'SnacksPickerGitBranch' }
    ret[#ret + 1] = { a(item.sha, 8, { truncate = true }), 'SnacksPickerGitCommit' }
    ret[#ret + 1] = { ' ' }
    ret[#ret + 1] = { a(item.path, 100, { truncate = true }), 'SnacksPickerDirectory' }
    return ret
end

function snacks_worktree.pick_git_worktree()
    if not Snacks then
        return
    end
    local config = {
        all = false,
        preview = 'none',
        finder = finder,
        format = format,
        layout = {
            preview = false,
        },
        confirm = switch_worktree,
        actions = {
            delete_worktree = delete_worktree,
            toggle_forced_deletion = toggle_forced_deletion,
        },
        win = {
            input = {
                keys = {
                    ['<c-d>'] = { 'delete_worktree', mode = { 'n', 'i' } },
                    ['<c-f>'] = { 'toggle_forced_deletion', mode = { 'n', 'i' } },
                },
            },
        },
        ---@param picker snacks.Picker
        on_show = function(picker)
            for i, item in ipairs(picker:items()) do
                if item.current then
                    picker.list:view(i)
                    Snacks.picker.actions.list_scroll_center(picker)
                    break
                end
            end
        end,
    }

    Snacks.picker.pick(config)
end

return snacks_worktree
