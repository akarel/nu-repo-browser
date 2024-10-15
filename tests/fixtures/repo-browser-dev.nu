let config_file = (glob *-config.json | first)

with-env [REPO_BROWSER_CONFIG_FILE $config_file] {
    use ..\..\src\repo-browser.nu

    repo-browser add my:test
    ls
}
