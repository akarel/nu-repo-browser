# Repo-browser Module

# -------- Constant value expressions ------------------------------------

const default_root_name = 'default'

def actions-definitions [] {
    #[ 'web' 'cmd' ]
    [
        { action: 'cmd', props: [ 'command' ] }
        { action: 'web', props: [ 'url' ] }
    ]
}

# -------- Value expressions ---------------------------------------------

def reponames [] {
    get-config | get repos | sort-by name | get name
}

def reporoots [] {
    get-config | get roots | transpose key val | get key | sort
}

def valid_actions [] {
    get-config | get repos |
        each {|r| ($r | select -i actions)} |
        filter {|a| not ($a.actions | is-empty)} |
        flatten actions --all | get key | uniq | sort
}

# -------- Helper functions ----------------------------------------------

def get-config [] {
    if ($env.REPO_BROWSER_CONFIG_FILE | path exists) {
        open $env.REPO_BROWSER_CONFIG_FILE
    } else {
        null
    }
}

def env-or-default [
    env_name: string      # The name of the environment variable
    default_value: string # Value to return if environment variable is empty or does not exist
] {
    if (($env_name in $env) and (not ($env | get $env_name | is-empty))) {
        $env | get $env_name
    } else {
        $default_value
    }
}

def format-repos [
    --with_git_status (-g): int = 0
] {
    if (not ($in | is-empty)) {
        let repo_tbl = ($in |
            select name relativePath |
            sort-by name |
            update relativePath {|row| ($'(ansi yellow_italic)($row.relativePath)(ansi reset)')} |
            move name --before relativePath)
        if ($with_git_status > 0) {
            $repo_tbl | insert branch {|row| (get-repo-branch-name $row.name | $'(ansi light_purple)($in)(ansi reset)')} | collect {||}
        } else {
            $repo_tbl
        }
    } else {
        echo "\r\n------------------\r\n    NO RESULTS     \r\n------------------"
    }
}

def get-root-path [name: string] {
    # TODO: Error handling if root does not exist
    get-config | get roots | transpose key val | where key == $name | first | get val
}

def get-repo-path [name: string] {
    let repo = (get-config | get repos | where name == $name | first)
    let rootPath = (get-root-path $repo.root)
    let repoPath = ([$rootPath $repo.relativePath] | path join)

    if ($repoPath | path exists) {
        $repoPath
    } else if ($rootPath | path exists) {
        $rootPath
    } else {
        $env.PWD
    }
}

def get-all-repo-paths [] {
    reponames | each {|r| ({ repo: $r, path: (get-repo-path $r) })}
}

def get-repo-branch-name [repo_name: string] {
    let repo = (get-config | get repos | where name == $repo_name | first)
    let repo_path = ([(get-root-path $repo.root) $repo.relativePath] | path join)
    mut git_branch = '----';
    enter $repo_path
        let result = (do -i { git branch --abbrev --show-current } | complete)
        if ($result | get stderr | is-empty) {
            $git_branch = ($result | get stdout)
        }
    dexit

    $git_branch | str trim -r -l
}

# -------- Exports -------------------------------------------------------

export-env {
    let home_path = ($nu | get 'home-path')
    # default config path values
    let default_config_path = ([$home_path '.config' 'nushell'] | path join)
    let default_config_file = 'repo-browser-config.json'

    let config_file_path = (env-or-default 'REPO_BROWSER_CONFIG_FILE' ([$default_config_path $default_config_file] | path join))
    let repo_root = (env-or-default 'REPO_BROWSER_ROOT' ($default_root_name))

    load-env {
        REPO_BROWSER_CONFIG_FILE: $config_file_path
        REPO_BROWSER_ROOT: $repo_root
    }
}

# Navigate to the given repository
export def --env go [
    name?: string@reponames # Repository name
    --enter (-e)            # Enter the repository directory in a new shell
] {
    let repo_dir = (if ($name | is-empty) {
        let defaultRootPath = (get-root-path $env.REPO_BROWSER_ROOT)

        if ($defaultRootPath | path exists) {
            $defaultRootPath
        } else {
            $env.PWD
        }
    } else {
        get-repo-path $name
    })

    if $enter {
        enter $repo_dir
    } else {
        cd $repo_dir
    }
}

# Search saved repositories
export def search [
    filter?: string                   # Optional regex search
    --not (-n)                        # Invert the search (values that do not match the filter)
    --bypath (-p)                     # Search by repository relative path instead of by name
    --bysource (-s): string@reporoots # Search for repositories under a specific root
    --showgitbranch (-g)              # Shows a column with the repository's current git branch name
] {
    let repos = (get-config | get repos)
    let regexFilter = (["(?i)" $filter] | str join)
    let show_git = (if $showgitbranch { 1 } else { 0 })
    
    if ($filter | is-empty) {
        $repos | format-repos -g $show_git
    } else if $not and $bypath {
        $repos | where relativePath !~ $regexFilter | format-repos -g $show_git
    } else if $bypath {
        $repos | where relativePath =~ $regexFilter | format-repos -g $show_git
    } else if $not {
        $repos | where name !~ $regexFilter | format-repos -g $show_git
    } else if (not ($regexFilter | is-empty)) {
        $repos | where name =~ $regexFilter | format-repos -g $show_git
    }
}

# Add the current directory to the configured repositories.
export def add [
    name?: string                 # Access name of the repository
    --path (-p): string           # Path relativee to the default or provided root
    --root (-r): string@reporoots # Add repository to a specific root
] {
    # TODO: Validate root
    let repo_root = (if ($root | is-empty) { ($default_root_name) } else { $root })
    let root_path = (get-root-path $repo_root)
    let repo_path = ((if ($path | is-empty) { $env.PWD } else { $path }) | str replace -a $root_path '')

    let full_repo_path = ([$root_path $repo_path] | path join)

    if ($full_repo_path | path exists) {
        get-config |
        update repos {|| append {name: $name, relativePath: $repo_path, root: $repo_root}} |
        save -f $env.REPO_BROWSER_CONFIG_FILE
        echo $"\r\n(ansi green)'($name)' configuration added: ($full_repo_path)(ansi reset)\r\n"
    } else {
        echo $"\r\n(ansi red)($full_repo_path) is not a valid path. Could not add an entry for ($name).(ansi reset)\r\n"
    }
}

# Execute a configured action for a given repository.
export def --env act [
    action: string@valid_actions  # Action to perform
    --repo (-r): string@reponames # Repository name in which to perform the action
] {
    if (not (valid_actions | any { $in == $action})) {
        let span = (metadata $action).span
        error make { msg: "Invalid Command", label: { text: $"'($action)' is not a valid command", start: $span.start, end: $span.end } }
    }
    
    let all_repos = get-all-repo-paths

    if (not ($repo | is-empty)) and ($all_repos | any {|r| $r == $repo}) {
        let span = (metadata $repo).span
        error make { msg: "Invalid Repository", label: { text: $"'($repo)' is not a valid repository", start: $span.start, end: $span.end } }
    }

    let repo_name = (if (not ($repo | is-empty)) {
        $repo
    } else {
        $all_repos |
            filter {|r| ($env.PWD | str contains $r.path)} | 
            insert ln {|r| ($r.path | str length)} |
            sort-by ln -r |
            first |
            get repo
    })

    let repo_config = (get-config | get repos | where name == $repo_name | first)

    if ($repo_config | get -i actions | is-empty) or ($repo_config | get -i actions | filter {|x| $x.key == $action} | length) < 1 {
        let span = (metadata $action).span
        error make { msg: "Invalid Command", label: { text: $"($repo_name) does not contain a '($action)' command", start: $span.start, end: $span.end } }
    }

    let action_def = ($repo_config | get -i actions | filter {|x| $x.key == $action} | first)

    if ($action_def.type | str downcase) == 'cmd' {
        let parsed_cmd = ($action_def.command |
            str replace '<<relativePath>>' $repo_config.relativePath |
            str replace '<<name>>' $repo_config.name |
            str replace '<<root>>' $repo_config.root |
            str replace '<<repoPath>>' ($all_repos | where repo == $repo_config.name | first | get path) |
            str replace '<<rootPath>>' (get-root-path $repo_config.root))
        
        do -i { nu -c $parsed_cmd }
    } else if ($action_def.type | str downcase) == 'web' {
        do {|x| start $x} $action_def.url
    }
}
