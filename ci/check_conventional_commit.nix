# Checks if PR title follows conventional commit (for squashing clean commits)
# Checks if commit history in a PR follows conventional commit

pkgs: {
  onPrTitle ? true,
  onHistory ? true,
  prnum ? "$PR_NUMBER",
  base_ref ? "$FORGEJO_BASE_REF",
  token ? "$FORGEJO_TOKEN",
  repo ? "$FORGEJO_REPOSITORY",
  server ? "$FORGEJO_SERVER_URL",
  addCurlOpts ? [],
  debug ? false,
}: let
  jq = "${pkgs.jq}/bin/jq";
  cog = "${pkgs.cocogitto}/bin/cog -vv";

  curlOpts = [
    "-s"
    "-H \"Authorization: Bearer ${token}\""
  ] ++ addCurlOpts;
  curl = "curl ${builtins.concatStringsSep " " curlOpts}";

  checkPr = ''
    got=$(${curl} "${server}/api/v1/repos/${repo}/pulls/${prnum}")
    if ! title=$(echo "$got" | ${jq} -e ".title" --raw-output); then
      echo "[*] Unable to get the title for the PR ${prnum}"
      exit 1;
    fi
    ${cog} verify "$title"
  '';

  checkHistory = ''
    ${cog} check origin/${base_ref}..HEAD
  '';

  cogConfig = ''
  from_latest_tag = false
  ignore_merge_commits = false
  ignore_fixup_commits = true
  disable_changelog = false
  disable_bump_commit = false
  generate_mono_repository_global_tag = true
  generate_mono_repository_package_tags = true
  branch_whitelist = []
  skip_ci = "[skip ci]"
  skip_untracked = false
  pre_bump_hooks = []
  post_bump_hooks = []
  pre_package_bump_hooks = []
  post_package_bump_hooks = []

  [git_hooks]

  [commit_types]

  [changelog]
  path = "CHANGELOG.md"
  authors = []

  [bump_profiles]

  [packages]
  '';

in pkgs.writeShellScript "check_conventional_commit" (''
  set -e
  ${if debug then "set -x" else ""}
  ERRCODE=0

  git fetch origin

  git config user.name "CI"
  git config user.email "ci@ci.ci"

  cat << EOF > cog.toml
  ${cogConfig}
  EOF

  if ! ${curl} "${server}/api/v1/version"; then
    echo "[!] API of server '${server}' unreachable"
    exit 1;
  fi

  got=$(${curl} "${server}/api/v1/repos/${repo}")
  if ! echo "$got" | ${jq} -e ".id" ; then
    echo "[!] Cannot access repository '${repo}' details from the server"
    exit 1;
  fi
'' + "\n"
  + (if onPrTitle then checkPr else "") + "\n"
  + (if onHistory then checkHistory else "")
)
