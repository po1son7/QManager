# shellcheck shell=sh
# =============================================================================
# mirror.sh — Release mirror defaults (mainland-friendly fork)
# =============================================================================
# Intended workflow for this fork:
#   - Develop and tag releases on GitHub (default: po1son7/QManager, “mainland” fork).
#   - Sync each tag’s release attachments to Gitee (default: aowu2048/QManager)
#     so devices in CN can OTA without hitting GitHub.
#   - OTA defaults to mirror_type=gitee (Gitee API + Gitee download URLs).
#
# Sourced by OTA scripts. Uses UCI quecmanager.update.* when set, else defaults
# below. Do not execute this file directly.
#
# UCI (optional):
#   quecmanager.update.mirror_type         gitee | github | github_proxy
#   quecmanager.update.mirror_repo         Gitee owner/repo (e.g. aowu2048/QManager)
#   quecmanager.update.mirror_github_repo  GitHub owner/repo (e.g. po1son7/QManager)
#
# SSRF allow-list also accepts legacy dr-dolomite URLs so old staged/rollback links
# remain valid if a device was migrated from upstream.
# =============================================================================

qmirror_get_uci() {
  uci -q get "quecmanager.update.$1" 2>/dev/null
}

qmirror_type() {
  _mt=$(qmirror_get_uci mirror_type)
  [ -n "$_mt" ] && echo "$_mt" || echo "gitee"
}

qmirror_gitee_repo() {
  _mr=$(qmirror_get_uci mirror_repo)
  [ -n "$_mr" ] && echo "$_mr" || echo "aowu2048/QManager"
}

qmirror_github_repo() {
  _gr=$(qmirror_get_uci mirror_github_repo)
  [ -n "$_gr" ] && echo "$_gr" || echo "po1son7/QManager"
}

# Releases API URL (returns JSON array of releases, newest first when supported)
qmirror_api_url() {
  case "$(qmirror_type)" in
    gitee)
      echo "https://gitee.com/api/v5/repos/$(qmirror_gitee_repo)/releases?per_page=50&direction=desc"
      ;;
    github_proxy)
      echo "https://ghproxy.net/https://api.github.com/repos/$(qmirror_github_repo)/releases?per_page=50"
      ;;
    *)
      echo "https://api.github.com/repos/$(qmirror_github_repo)/releases?per_page=50"
      ;;
  esac
}

# Prefix for .../releases/download/<tag>/filename
qmirror_release_download_prefix() {
  case "$(qmirror_type)" in
    gitee)
      echo "https://gitee.com/$(qmirror_gitee_repo)/releases/download/"
      ;;
    github_proxy)
      echo "https://ghproxy.net/https://github.com/$(qmirror_github_repo)/releases/download/"
      ;;
    *)
      echo "https://github.com/$(qmirror_github_repo)/releases/download/"
      ;;
  esac
}

qmirror_tarball_url() {
  tag="$1"
  echo "$(qmirror_release_download_prefix)${tag}/qmanager.tar.gz"
}

qmirror_checksum_url() {
  tag="$1"
  echo "$(qmirror_release_download_prefix)${tag}/sha256sum.txt"
}

# SSRF allow-list for OTA downloads (tarball, checksum, rare raw build artifact)
qmirror_validate_release_asset_url() {
  url="$1"
  gitee_r=$(qmirror_gitee_repo)
  gh_r=$(qmirror_github_repo)
  gitee_p="https://gitee.com/${gitee_r}/releases/download/"
  gh_p="https://github.com/${gh_r}/releases/download/"
  prox_p="https://ghproxy.net/https://github.com/${gh_r}/releases/download/"
  legacy_p="https://github.com/dr-dolomite/QManager/releases/download/"
  raw_gitee="https://gitee.com/${gitee_r}/raw/"
  raw_gh="https://github.com/${gh_r}/raw/"
  raw_legacy="https://github.com/dr-dolomite/QManager/raw/"

  case "$url" in
    "${gitee_p}"*/qmanager.tar.gz | "${gitee_p}"*/sha256sum.txt) return 0 ;;
    "${gh_p}"*/qmanager.tar.gz | "${gh_p}"*/sha256sum.txt) return 0 ;;
    "${prox_p}"*/qmanager.tar.gz | "${prox_p}"*/sha256sum.txt) return 0 ;;
    "${legacy_p}"*/qmanager.tar.gz | "${legacy_p}"*/sha256sum.txt) return 0 ;;
    "${raw_gitee}"*/qmanager-build/qmanager.tar.gz) return 0 ;;
    "${raw_gh}"*/qmanager-build/qmanager.tar.gz) return 0 ;;
    "${raw_legacy}"*/qmanager-build/qmanager.tar.gz) return 0 ;;
  esac
  return 1
}
