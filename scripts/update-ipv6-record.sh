#!/bin/sh
set -eu

export AWS_PAGER=""

primary_record_name="${TLS_HOSTNAME:?TLS_HOSTNAME is required}"
shortcut_record_name="${SHORTCUT_TLS_HOSTNAME:-shortcut.la.qyp.life}"
shortcut_alias_record_name="${SHORTCUT_ALIAS_HOSTNAME:-downloads.la.qyp.life}"
zone_name="${ROUTE53_ZONE_NAME:-qyp.life}"
network_interface="${IPV6_INTERFACE:-eth0}"
record_ttl="${IPV6_DDNS_TTL:-60}"
update_interval="${IPV6_DDNS_INTERVAL_SECONDS:-60}"
dry_run="${IPV6_DDNS_DRY_RUN:-false}"
run_once="${IPV6_DDNS_RUN_ONCE:-false}"

validate_dns_name() {
    case "$1" in
        "" | .* | *..* | *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-]*)
            printf '%s\n' "invalid DNS name" >&2
            exit 2
            ;;
    esac
}

validate_positive_integer() {
    case "$1" in
        "" | *[!0123456789]* | 0)
            printf '%s\n' "expected a positive integer" >&2
            exit 2
            ;;
    esac
}

validate_dns_name "$primary_record_name"
validate_dns_name "$shortcut_record_name"
validate_dns_name "$shortcut_alias_record_name"
validate_dns_name "$zone_name"
validate_positive_integer "$record_ttl"
validate_positive_integer "$update_interval"

if [ "$shortcut_alias_record_name" = "$primary_record_name" ] || [ "$shortcut_alias_record_name" = "$shortcut_record_name" ]; then
    printf '%s\n' "shortcut alias must be different from direct AAAA records" >&2
    exit 2
fi

global_ipv6_address() {
    address_hex="$(awk -v target_interface="$network_interface" '
        $6 == target_interface && $3 == "40" && $4 == "00" { print $1; exit }
    ' /proc/net/if_inet6)"
    if [ -z "$address_hex" ]; then
        printf '%s\n' "no global /64 IPv6 address found on ${network_interface}" >&2
        return 1
    fi
    printf '%s' "$address_hex" | sed 's/\(....\)/\1:/g; s/:$//'
}

route53_zone_id() {
    zone_result="$(aws route53 list-hosted-zones-by-name \
        --dns-name "${zone_name}." \
        --max-items 1 \
        --query 'HostedZones[0].[Id,Name]' \
        --output text)"
    set -- $zone_result
    if [ "$#" -ne 2 ] || [ "$2" != "${zone_name}." ]; then
        printf '%s\n' "Route 53 hosted zone ${zone_name}. was not found" >&2
        return 1
    fi
    printf '%s' "${1#/hostedzone/}"
}

update_record() {
    record_name="$1"
    address="$(global_ipv6_address)"
    if [ "$dry_run" = "true" ]; then
        printf '%s\n' "dry-run AAAA ${record_name}. -> ${address} TTL ${record_ttl}"
        return 0
    fi

    zone_id="$(route53_zone_id)"
    current_address="$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --start-record-name "${record_name}." \
        --start-record-type AAAA \
        --max-items 1 \
        --query 'ResourceRecordSets[0].ResourceRecords[0].Value' \
        --output text || true)"
    if [ "$current_address" = "$address" ]; then
        printf '%s\n' "unchanged AAAA ${record_name}. -> ${address}"
        return 0
    fi

    change_batch="$(printf '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"%s.","Type":"AAAA","TTL":%s,"ResourceRecords":[{"Value":"%s"}]}}]}' "$record_name" "$record_ttl" "$address")"
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --change-batch "$change_batch" \
        --output text >/dev/null
    printf '%s\n' "updated AAAA ${record_name}. -> ${address}"
}

update_alias_record() {
    alias_target="${primary_record_name}."
    if [ "$dry_run" = "true" ]; then
        printf '%s\n' "dry-run CNAME ${shortcut_alias_record_name}. -> ${alias_target} TTL ${record_ttl}"
        return 0
    fi

    zone_id="$(route53_zone_id)"
    current_target="$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --start-record-name "${shortcut_alias_record_name}." \
        --start-record-type CNAME \
        --max-items 1 \
        --query 'ResourceRecordSets[0].ResourceRecords[0].Value' \
        --output text || true)"
    if [ "$current_target" = "$alias_target" ]; then
        printf '%s\n' "unchanged CNAME ${shortcut_alias_record_name}. -> ${alias_target}"
        return 0
    fi

    change_batch="$(printf '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"%s.","Type":"CNAME","TTL":%s,"ResourceRecords":[{"Value":"%s"}]}}]}' "$shortcut_alias_record_name" "$record_ttl" "$alias_target")"
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --change-batch "$change_batch" \
        --output text >/dev/null
    printf '%s\n' "updated CNAME ${shortcut_alias_record_name}. -> ${alias_target}"
}

update_all_records() {
    update_record "$primary_record_name"
    if [ "$shortcut_record_name" != "$primary_record_name" ]; then
        update_record "$shortcut_record_name"
    fi
    update_alias_record
}

while :; do
    if update_all_records; then
        if [ "$run_once" = "true" ]; then
            exit 0
        fi
        sleep "$update_interval"
    else
        if [ "$run_once" = "true" ]; then
            exit 1
        fi
        sleep 15
    fi
done
