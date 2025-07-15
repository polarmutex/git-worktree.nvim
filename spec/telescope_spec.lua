local git_harness = require('git-worktree.test.git_util')
local Job = require('plenary.job')

local cwd = vim.fn.getcwd()

-- Helper function to get command output like telescope.utils does
local function get_os_command_output(cmd)
    local job = Job:new {
        command = cmd[1],
        args = vim.list_slice(cmd, 2),
    }
    local output, code = job:sync()
    if code ~= 0 then
        return {}
    end
    return output
end

-- luacheck: globals working_dir master_dir
describe('[Telescope Extension]', function()
    after_each(function()
        vim.api.nvim_command('cd ' .. cwd)
    end)

    describe('[Worktree Listing]', function()
        describe('[non-bare repository]', function()
            before_each(function()
                working_dir, master_dir = git_harness.prepare_repo_normal_worktree(1)
            end)

            it('should include main repository in worktree list for non-bare repos', function()
                -- Get worktree list using the same command as telescope extension
                local output = get_os_command_output { 'git', 'worktree', 'list', '--porcelain' }

                -- Check if repository is bare
                local is_bare_output = get_os_command_output { 'git', 'rev-parse', '--is-bare-repository' }
                local is_bare = is_bare_output[1] == 'true'

                -- Should not be bare
                assert.are.same(false, is_bare)

                -- Parse the output to find worktrees
                local worktrees = {}
                local entry = {}

                for _, line in ipairs(output) do
                    if line == '' and entry.path then
                        table.insert(worktrees, { path = entry.path, branch = entry.branch })
                        entry = {}
                    else
                        local path = string.match(line, '^worktree%s+(.+)$')
                        if path then
                            entry.path = path
                        end
                        local branch = string.match(line, '^branch refs/heads/(.+)$')
                        if branch then
                            entry.branch = branch
                        end
                        local detached = string.match(line, '^detached$')
                        if detached then
                            entry.branch = detached
                        end
                    end
                end

                -- Should have at least 2 worktrees (main repo + featB worktree)
                assert.is_true(#worktrees >= 2)

                -- Find the main repository worktree
                local main_worktree = nil
                local feat_worktree = nil

                for _, wt in ipairs(worktrees) do
                    if wt.branch == 'master' then
                        main_worktree = wt
                    elseif wt.branch == 'featB' then
                        feat_worktree = wt
                    end
                end

                -- Both should exist
                assert.is_not_nil(main_worktree, 'Main repository worktree should be found')
                assert.is_not_nil(feat_worktree, 'Feature branch worktree should be found')

                -- Main worktree path should be the master_dir
                assert.are.same(master_dir, main_worktree.path)
            end)
        end)

        describe('[bare repository]', function()
            before_each(function()
                working_dir = git_harness.prepare_repo_bare()
            end)

            it('should be bare repository', function()
                -- Check if repository is bare
                local is_bare_output = get_os_command_output { 'git', 'rev-parse', '--is-bare-repository' }
                local is_bare = is_bare_output[1] == 'true'

                -- Should be bare
                assert.are.same(true, is_bare)
            end)
        end)
    end)
end)
