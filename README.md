# Repo Browser

## Development Requirements

- [Nushell](https://www.nushell.sh/) (obviously 😀)
- [Just](https://github.com/casey/just) (for dev tasks)

## Command List

- [x] go
  - [x] Navigate to a given repository or active base repository directory if no repository name given
- [x] search
  - [x] Search for saved repositories by (regex) pattern. Default case insensitive.
  - [x] List repositories with current git branch
- [ ] init
  - [ ] Initialize a configuration file via a prompt wizard
- [ ] add
  - [x] Add a new repository by parameters
  - [ ] Add a new repository by prompt wizard
- [ ] remove
  - [ ] Remove an existing repository configuration by parameters
  - [ ] Remove an existing repository configuration by prompt wizard
- [ ] info
  - [ ] Get detailed information about a given repository
- [ ] remote
  - [ ] Open the web location of the remote repository source
- [ ] act
  - [x] Initial act functionality
  - [ ] Add global actions
  - [ ] Filter available actions by current selected repo
