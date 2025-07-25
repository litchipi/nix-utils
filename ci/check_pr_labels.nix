# Checks if a PR has at least one label in the "category" list
# Ensure that a PR targetting a specific base branch doesn't contain a forbidden label
# Example:
#   forbidden = {
#     stable = [ "feature" ];  # Must never be an empty list
#   };
# Will fail if a PR with label `feature` tries to get merged in branch `stable`

pkgs: {
  forbidden ? {},
  categories ? [],
  prnum ? "$PR_NUMBER",
  base_ref ? "$FORGEJO_BASE_REF",
  token ? "$FORGEJO_TOKEN",
  repo ? "$FORGEJO_REPOSITORY",
  server ? "$FORGEJO_SERVER_URL",
  addCurlOpts ? [],
  debug ? false,
}: let
  rg = "${pkgs.ripgrep}/bin/rg";
  jq = "${pkgs.jq}/bin/jq";

  curlOpts = [
    "-s"
    "-H \"Authorization: Bearer ${token}\""
  ] ++ addCurlOpts;
  curl = "curl ${builtins.concatStringsSep " " curlOpts}";

  check_all_labels = ref: labels: builtins.concatStringsSep "\n" (builtins.map (lbl: ''
    if ${rg} "${lbl}" ./labels 1>/dev/null; then
      echo "[!] PR on ${ref} are not accepted from label ${lbl}"
    fi
  '') labels);

in pkgs.writeShellScript "check_conventional_commit" (''
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

  got=$(${curl} "${server}/api/v1/repos/${repo}/pulls/${prnum}")
  if ! echo "$got" | ${jq} ".labels[].name" --raw-output > labels; then
    echo "[!] Error while getting the labels for PR ${prnum}"
    exit 1;
  fi

  echo "Labels: $(cat ./labels)"

  if ! ${rg} "${builtins.concatStringsSep "|" categories}" ./labels; then
    echo "[!] PR ${prnum} is missing a category label"
    echo "Must be one of: ${builtins.concatStringsSep ", " categories}."
    exit 1;
  fi

'' + (builtins.concatStringsSep "\n\n" (pkgs.lib.attrsets.mapAttrsToList
  (ref: labels: ''
    if [[ "${base_ref}" == "${ref}" ]]; then
      ${check_all_labels ref labels}
    fi
  '')
  forbidden))
)
