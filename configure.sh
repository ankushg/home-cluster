#!/usr/bin/env bash

set -o errexit
set -o pipefail

# shellcheck disable=SC2155
export PROJECT_DIR=$(git rev-parse --show-toplevel)

# shellcheck disable=SC2155
export GPG_TTY=$(tty)

# shellcheck disable=SC1091
source "${PROJECT_DIR}/.config.env"

show_help() {
cat << EOF
Usage: $(basename "$0") <options>
    -h, --help                      Display help
    --verify                        Verify .config.env settings
EOF
}

main() {
    local verify=

    parse_command_line "$@"

    verify_binaries
    verify_nodes
    verify_metallb
    verify_gpg
    verify_git_repository
    verify_cloudflare

    if [[ "${verify}" == 1 ]]; then
        success
    else
        # generate sops configuration file
        envsubst < "${PROJECT_DIR}/tmpl/.sops.yaml" \
            > "${PROJECT_DIR}/.sops.yaml"

        # generate cluster settings
        envsubst < "${PROJECT_DIR}/tmpl/cluster/cluster-settings.yaml" \
            > "${PROJECT_DIR}/cluster/config/cluster-settings.yaml"

        envsubst < "${PROJECT_DIR}/tmpl/cluster/flux-cluster.yaml" \
            > "${PROJECT_DIR}/cluster/flux/flux-system/flux-cluster.yaml"

        #  generate cluster secrets
        envsubst < "${PROJECT_DIR}/tmpl/cluster/cluster-secrets.sops.yaml" \
            > "${PROJECT_DIR}/cluster/config/cluster-secrets.sops.yaml"
        envsubst < "${PROJECT_DIR}/tmpl/cluster/cert-manager-secret.sops.yaml" \
            > "${PROJECT_DIR}/cluster/core/cluster-issuers/secret.sops.yaml"
        envsubst < "${PROJECT_DIR}/tmpl/cluster/cloudflare-ddns-secret.sops.yaml" \
            > "${PROJECT_DIR}/cluster/apps/networking/cloudflare-ddns/secret.sops.yaml"
        envsubst < "${PROJECT_DIR}/tmpl/cluster/external-dns-secret.sops.yaml" \
            > "${PROJECT_DIR}/cluster/apps/networking/external-dns/secret.sops.yaml"

        # encrypt cluster secrets
        sops --encrypt --in-place "${PROJECT_DIR}/cluster/config/cluster-secrets.sops.yaml"
        sops --encrypt --in-place "${PROJECT_DIR}/cluster/core/cluster-issuers/secret.sops.yaml"
        sops --encrypt --in-place "${PROJECT_DIR}/cluster/apps/networking/cloudflare-ddns/secret.sops.yaml"
        sops --encrypt --in-place "${PROJECT_DIR}/cluster/apps/networking/external-dns/secret.sops.yaml"

        # generate terraform secrets
        envsubst < "${PROJECT_DIR}/tmpl/terraform/secret.sops.yaml" \
            > "${PROJECT_DIR}/provision/terraform/cloudflare/secret.sops.yaml"

        # encrypt terraform secrets
        sops --encrypt --in-place "${PROJECT_DIR}/provision/terraform/cloudflare/secret.sops.yaml"
    fi
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            --verify)
                verify=1
                ;;
            *)
                break
                ;;
        esac

        shift
    done

    if [[ -z "$verify" ]]; then
        verify=0
    fi
}

_has_binary() {
    command -v "${1}" >/dev/null 2>&1 || {
        _log "ERROR" "${1} is not installed or not found in \$PATH"
        exit 1
    }
}

_has_envar() {
    local option="${1}"
    # shellcheck disable=SC2015
    [[ "${!option}" == "" ]] && {
        _log "ERROR" "Unset variable ${option}"
        exit 1
    } || {
        _log "INFO" "Found variable '${option}' with value '${!option}'"
    }
}

_has_valid_ip() {
    local ip="${1}"
    local variable_name="${2}"

    if ! ipcalc "${ip}" | awk 'BEGIN{FS=":"; is_invalid=0} /^INVALID/ {is_invalid=1; print $1} END{exit is_invalid}' >/dev/null 2>&1; then
        _log "INFO" "Variable '${variable_name}' has an invalid IP address '${ip}'"
        exit 1
    else
        _log "INFO" "Variable '${variable_name}' has a valid IP address '${ip}'"
    fi
}

verify_gpg() {
    _has_envar "BOOTSTRAP_PERSONAL_KEY_FP"
    _has_envar "BOOTSTRAP_FLUX_KEY_FP"

    if ! gpg --list-keys "${BOOTSTRAP_PERSONAL_KEY_FP}" >/dev/null 2>&1; then
         _log "ERROR" "Invalid Personal GPG FP ${BOOTSTRAP_PERSONAL_KEY_FP}"
        exit 1
    else
        _log "INFO" "Found Personal GPG Fingerprint '${BOOTSTRAP_PERSONAL_KEY_FP}'"
    fi

    if ! gpg --list-keys "${BOOTSTRAP_FLUX_KEY_FP}" >/dev/null 2>&1; then
         _log "ERROR" "Invalid Flux GPG FP '${BOOTSTRAP_FLUX_KEY_FP}'"
        exit 1
    else
         _log "INFO" "Found Flux GPG Fingerprint '${BOOTSTRAP_FLUX_KEY_FP}'"
    fi
}

verify_binaries() {
    _has_binary "envsubst"
    _has_binary "flux"
    _has_binary "git"
    _has_binary "gpg"
    _has_binary "helm"
    _has_binary "ipcalc"
    _has_binary "jq"
    _has_binary "sops"
    _has_binary "ssh"
    _has_binary "task"
    _has_binary "k3sup"
    _has_binary "kubectl"
}


verify_metallb() {
    local ip_floor=
    local ip_ceil=
    _has_envar "BOOTSTRAP_METALLB_LB_RANGE"
    _has_envar "BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR"
    _has_envar "BOOTSTRAP_SVC_TRAEFIK_ADDR"

    ip_floor=$(echo "${BOOTSTRAP_METALLB_LB_RANGE}" | cut -d- -f1)
    ip_ceil=$(echo "${BOOTSTRAP_METALLB_LB_RANGE}" | cut -d- -f2)

    # TODO(configure.sh): More checks on valid IP addressing
    _has_valid_ip "${ip_floor}" "BOOTSTRAP_METALLB_LB_RANGE"
    _has_valid_ip "${ip_ceil}" "BOOTSTRAP_METALLB_LB_RANGE"
    _has_valid_ip "${BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR}" "BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR"
    _has_valid_ip "${BOOTSTRAP_SVC_TRAEFIK_ADDR}" "BOOTSTRAP_SVC_TRAEFIK_ADDR"
}

verify_git_repository() {
    _has_envar "BOOTSTRAP_GIT_REPOSITORY"

    export GIT_TERMINAL_PROMPT=0
    pushd "$(mktemp -d)" >/dev/null 2>&1
    [ "$(git ls-remote "${BOOTSTRAP_GIT_REPOSITORY}" 2> /dev/null)" ] || {
        _log "ERROR" "Unable to find the remote Git repository '${BOOTSTRAP_GIT_REPOSITORY}'"
        exit 1
    }
    popd >/dev/null 2>&1
    export GIT_TERMINAL_PROMPT=1
}

verify_cloudflare() {
    local account_zone=
    local errors=

    _has_envar "BOOTSTRAP_CLOUDFLARE_TOKEN"
    _has_envar "BOOTSTRAP_CLOUDFLARE_DOMAIN"
    _has_envar "BOOTSTRAP_CLOUDFLARE_EMAIL"

    # Try to retrieve zone information from Cloudflare's API
    account_zone=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${BOOTSTRAP_CLOUDFLARE_DOMAIN}&status=active" \
        -H "Authorization: Bearer ${BOOTSTRAP_CLOUDFLARE_TOKEN}" \
        -H "Content-Type: application/json"
    )

    if [[ "$(echo "${account_zone}" | jq ".success")" == "true" ]]; then
        _log "INFO" "Verified Cloudflare Account and Zone information"
    else
        errors=$(echo "${account_zone}" | jq -c ".errors")
        _log "ERROR" "Unable to get Cloudflare Account and Zone information ${errors}"
        exit 1
    fi
}

verify_nodes() {
    local node_id=
    local node_addr=

    for var in "${!BOOTSTRAP_NODE_ADDR_@}"; do
        node_id=$(echo "${var}" | awk -F"_" '{print $4}')
        node_addr="BOOTSTRAP_NODE_ADDR_${node_id}"

        _has_envar "${node_addr}"

        # TODO: at least ping the nodes instead of ssh...
        if ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${!var}" "true"; then
            _log "INFO" "Successfully SSH'ed into host '${!var}' using ssh certificates"
        else
            _log "ERROR" "Unable to SSH into host '${!var}' using ssh certificates"
            exit 1
        fi
    done
}

success() {
    printf "\nAll checks pass!"
    exit 0
}

_log() {
    local type="${1}"
    local msg="${2}"
    printf "[%s] [%s] %s\n" "$(date -u)" "${type}" "${msg}"
}

main "$@"
