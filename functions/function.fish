
function _git-branch-updater_default-read
    read -p 'echo "$argv[1] (default: $argv[2]): "' -l value
    if test $status -ne 0
        exit $status
    end

    if [ "$value" = '' ]
        set value $argv[2]
    end
    echo $value
end

function git-branch-updater --description 'Update git branches with latest remote main branch'
    if test (count $argv) -eq 0 > /dev/null
        echo "Usage: git-branch-updater branch branch branch..."
        exit
    end

    if git status | grep 'git commit' > /dev/null
        echo "There is git diff. Please drop this diff to continue branches update."
        echo
        git status --short
        exit
    end


    echo "Update branches: "(string join ", " $argv)
    echo

    echo "Fetching remote branches..."
    git fetch --prune 2>&1 > /dev/null

    echo

    set remoteBranch (_git-branch-updater_default-read "Input target remote Branch name" "main")
    set remoteBranch (echo "origin/$remoteBranch")

    # store current HEAD, and back this HEAD later.
    set currentHEAD (git branch --contains | grep '*' | cut -d " " -f 2)
    if git branch --contains | grep 'HEAD detached' > /dev/null
        set currentHEAD (git rev-parse --short HEAD)
    end
    set currentHEAD (string trim $currentHEAD)
    echo "Current HEAD:" $currentHEAD

    # set updateMethod (_git-branch-updater_default-read "merge or rebase, which method do you want?" "merge")
    set updateMethod "merge"
    echo "Update method:" $updateMethod

    # switch branches + update from master
    echo "Start Updating"
    for branch in $argv
        set remoteTargetBranch (echo "origin/$branch")
        set tmpBranchName (echo "tmp_branch_updater__$branch")
        set -a tmpBranches $tmpBranchName
        echo -n $branch" ... "

        git switch -q -C $tmpBranchName $remoteTargetBranch 2>&1 > /dev/null
        set result (git $updateMethod -q --no-summary --no-progress --no-stat $remoteBranch 2>&1)
        if test $status -ne 0
            git reset --hard -q
            echo "Conflicted. Canceled update this branch."
            continue
        end

        # TODO: no-push option
        git push -q origin $tmpBranchName:$branch
        echo "OK"
    end

    # back to current head
    git switch -q $currentHEAD 2>&1 > /dev/null

    # remove all tmp branches
    echo -n "Removing local temporary branch ... "
    for branch in $tmpBranches
        git branch -d --force $branch 2>&1 > /dev/null
    end
    echo "OK"

    echo "Done!"
end
