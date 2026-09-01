local git_harness = require('git-worktree.test.git_util')
local Hooks = require('git-worktree.hooks')
local Path = require('plenary.path')
local uv = vim.uv or vim.loop

local cwd = vim.fn.getcwd()

-- luacheck: globals repo_dir config git_worktree
describe('[Worktree]', function()
    local completed_create = false
    local completed_switch = false
    local completed_delete = false

    local reset_variables = function()
        completed_create = false
        completed_switch = false
        completed_delete = false
    end

    Hooks.register(Hooks.type.CREATE, function()
        completed_create = true
    end)
    Hooks.register(Hooks.type.DELETE, function()
        completed_delete = true
    end)
    Hooks.register(Hooks.type.SWITCH, function()
        completed_switch = true
    end)

    before_each(function()
        reset_variables()
        git_worktree = require('git-worktree')
    end)
    after_each(function()
        vim.api.nvim_command('cd ' .. cwd)
    end)

    -- luacheck: globals working_dir master_dir
    describe('[Switch]', function()
        describe('[bare repo]', function()
            before_each(function()
                working_dir, master_dir = git_harness.prepare_repo_bare_worktree(2)
            end)
            it('able to switch to worktree (relative path)', function()
                local wt = 'featB'
                local input_path = '../' .. wt
                local expected_path = working_dir .. Path.path.sep .. wt
                -- local prev_path = working_dir .. Path.path.sep .. 'master'
                require('git-worktree').switch_worktree(input_path)

                vim.fn.wait(10000, function()
                    return completed_switch
                end, 1000)

                assert.are.same(expected_path, uv.cwd())
            end)
        end)

        describe('[normal repo]', function()
            before_each(function()
                working_dir, master_dir = git_harness.prepare_repo_normal_worktree(1)
            end)
            it('able to switch to worktree (relative path)', function()
                local wt = 'featB'
                local input_path = '../' .. wt
                local expected_path = working_dir .. Path.path.sep .. wt
                -- local prev_path = working_dir .. Path.path.sep .. 'master'
                require('git-worktree').switch_worktree(input_path)

                vim.fn.wait(10000, function()
                    return completed_switch
                end, 1000)

                -- Check to make sure directory was switched
                assert.are.same(expected_path, uv.cwd())
            end)
        end)
    end)

    -- luacheck: globals working_dir master_dir
    describe('[CREATE]', function()
        describe('[bare repo]', function()
            before_each(function()
                working_dir, master_dir = git_harness.prepare_repo_bare_worktree(1)
            end)
            it('able to create a worktree (relative path)', function()
                local wt = 'featB'
                local input_path = '../' .. wt
                local expected_path = working_dir .. Path.path.sep .. wt
                -- local prev_path = working_dir .. Path.path.sep .. 'master'
                require('git-worktree').create_worktree(input_path, wt)

                vim.fn.wait(10000, function()
                    return completed_create and completed_switch
                end, 1000)

                -- Check to make sure directory was switched
                assert.are.same(expected_path, uv.cwd())
            end)
        end)
        describe('[normal repo]', function()
            before_each(function()
                working_dir, master_dir = git_harness.prepare_repo_normal_worktree(0)
            end)
            it('able to create a worktree (relative path)', function()
                local wt = 'featB'
                local input_path = '../' .. wt
                local expected_path = working_dir .. Path.path.sep .. wt
                -- local prev_path = working_dir .. Path.path.sep .. 'master'
                require('git-worktree').create_worktree(input_path, wt)

                vim.fn.wait(10000, function()
                    return completed_create and completed_switch
                end, 1000)

                -- Check to make sure directory was switched
                assert.are.same(expected_path, uv.cwd())
            end)
        end)
    end)

    -- luacheck: globals working_dir master_dir
    describe('[DELETE]', function()
        describe('[bare repo]', function()
            before_each(function()
                working_dir, master_dir = git_harness.prepare_repo_bare_worktree(2)
            end)
            it('able to create a worktree (relative path)', function()
                local wt = 'featB'
                local input_path = '../' .. wt
                require('git-worktree').delete_worktree(input_path, true)

                vim.fn.wait(10000, function()
                    return completed_delete
                end, 1000)

                -- Check to make sure directory was switched
                assert.are.same(master_dir, uv.cwd())
            end)
        end)
        describe('[normal repo]', function()
            before_each(function()
                working_dir, master_dir = git_harness.prepare_repo_normal_worktree(1)
            end)
            it('able to create a worktree (relative path)', function()
                local wt = 'featB'
                local input_path = '../' .. wt
                require('git-worktree').delete_worktree(input_path, wt)

                vim.fn.wait(10000, function()
                    return completed_delete
                end, 1000)

                -- Check to make sure directory was switched
                assert.are.same(master_dir, uv.cwd())
            end)
        end)
    end)
end)
