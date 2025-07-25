# Checks if some TODOs are left unbound to an issue on the repository
# Should work for any Github-compatible forge API

pkgs: {
  ignoredFiles ? [],
  token ? "$FORGEJO_TOKEN",
  repo ? "$FORGEJO_REPOSITORY",
  server ? "$FORGEJO_SERVER_URL",
  addCurlOpts ? [],
  debug ? false,
}: let
  rg = "${pkgs.ripgrep}/bin/rg";
  jq = "${pkgs.jq}/bin/jq";
  filter_files = if builtins.length ignoredFiles > 0
    then "|${rg} -v " + (builtins.concatStringsSep "|" ignoredFiles)
    else "";
  curlOpts = [
    "-s"
    "-H \"Authorization: Bearer ${token}\""
  ] ++ addCurlOpts;
  curl = "curl ${builtins.concatStringsSep " " curlOpts}";
in pkgs.writeShellScript "check_todos" ''
  set -e
  ${if debug then "set -x" else ""}
  ERRCODE=0

  if ! ${curl} "${server}/api/v1/version"; then
    echo "[!] API of server '${server}' unreachable"
    exit 1;
  fi

  got=$(${curl} "${server}/api/v1/repos/${repo}")
  if ! echo "$got" | ${jq} -e ".id" ; then
    echo "[!] Cannot access repository '${repo}' details from the server"
    exit 1;
  fi

  ${rg} -n "TODO" ${filter_files} > all_todos
  cat all_todos \
    | ${rg} -o "\(#\d+\)" \
    | ${rg} -o "\d+" \
    | sort -u -n \
    > issues_to_check

  TODOS_LEFT=$(cat all_todos \
    | ${rg} -v "\(#\d+\)" \
    | cut -d ':' -f 1 \
    | sort -u \
    | tr '\n' ' '
  )

  set +e
  while read ISSUE; do
    got=$(${curl} "${server}/api/v1/repos/${repo}/issues/$ISSUE")
    if ! echo "$got" | ${jq} ".state" | ${rg} "\"open\"" 2>/dev/null 1>/dev/null
    then
      echo "[!] Issue $ISSUE is closed or missing"
      ERRCODE=1
    fi
  done < issues_to_check

  if ! [ -z "$TODOS_LEFT" ]; then
    echo "[!] Some TODOs are not linked to an existing issue"
    ${rg} -n "TODO" | ${rg} -v "\(#\d+\)" | ${rg} -v "IGNORE-TODO"
    ERRCODE=1
  fi

  rm -f all_todos issues_to_check
  exit $ERRCODE
''
