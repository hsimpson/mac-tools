#!/usr/bin/env bash
# ec2-instance-inventory.sh - List EC2 instances with AMI details (default region)
set -euo pipefail

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"

aws_cmd() {
  if [[ -n "$REGION" ]]; then
    aws --region "$REGION" "$@"
  else
    aws "$@"
  fi
}

usage() {
  cat <<'EOF'
Usage: ec2-instance-inventory.sh [OPTIONS]

List all EC2 instances in the default (or configured) AWS region.

Options:
  -r, --region REGION   AWS region (overrides AWS_REGION / AWS_DEFAULT_REGION)
  -o, --output FORMAT   Output format: markdown (default) or csv
  -h, --help            Show this help

Columns:
  instanceID, name, instance-type, AMI-ID, AMI-name, platform-arch, state, ebs
EOF
}

OUTPUT="markdown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

TMPDIR="${TMPDIR:-/tmp}"
INSTANCES_FILE="$(mktemp "${TMPDIR}/ec2-instances.XXXXXX")"
AMI_FILE="$(mktemp "${TMPDIR}/ec2-amis.XXXXXX")"
VOLUMES_FILE="$(mktemp "${TMPDIR}/ec2-volumes.XXXXXX")"
SORTED_FILE="$(mktemp "${TMPDIR}/ec2-sorted.XXXXXX")"
trap 'rm -f "$INSTANCES_FILE" "$AMI_FILE" "$VOLUMES_FILE" "$SORTED_FILE"' EXIT

aws_cmd ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value | [0], InstanceType, ImageId, Architecture, PlatformDetails, State.Name, join(`,`, BlockDeviceMappings[?Ebs!=null].Ebs.VolumeId)]' \
  --output text > "$INSTANCES_FILE"

if [[ ! -s "$INSTANCES_FILE" ]]; then
  echo "No EC2 instances found." >&2
  exit 0
fi

AMI_IDS="$(cut -f4 "$INSTANCES_FILE" | sort -u | tr '\n' ' ')"
aws_cmd ec2 describe-images --image-ids $AMI_IDS \
  --query 'Images[].[ImageId, Name]' \
  --output text | sort > "$AMI_FILE"

VOLUME_IDS="$(cut -f8 "$INSTANCES_FILE" | tr ',' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')"
if [[ -n "$VOLUME_IDS" ]]; then
  aws_cmd ec2 describe-volumes --volume-ids $VOLUME_IDS \
    --query 'Volumes[].[VolumeId, VolumeType, Size]' \
    --output text | sort > "$VOLUMES_FILE"
else
  : > "$VOLUMES_FILE"
fi

awk -F'\t' -v vol_file="$VOLUMES_FILE" '
  BEGIN {
    while ((getline line < vol_file) > 0) {
      split(line, parts, "\t")
      vol_info[parts[1]] = parts[3] "GiB " parts[2]
    }
    close(vol_file)
  }
  NR == FNR {
    ami_name[$1] = $2
    next
  }
  {
    name = $2
    if (name == "" || name == "None") name = "(no name)"
    platform_arch = $6 "/" $5
    ebs = "-"
    if ($8 != "" && $8 != "None") {
      n = split($8, ids, ",")
      ebs_parts = ""
      for (i = 1; i <= n; i++) {
        vid = ids[i]
        gsub(/^[ \t]+|[ \t]+$/, "", vid)
        if (vid in vol_info) {
          if (ebs_parts != "") ebs_parts = ebs_parts ", "
          ebs_parts = ebs_parts vol_info[vid]
        }
      }
      if (ebs_parts != "") ebs = ebs_parts
    }
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", name, $1, $3, $4, ami_name[$4], platform_arch, $7, ebs
  }
' "$AMI_FILE" "$INSTANCES_FILE" | sort -t$'\t' -k1,1f > "$SORTED_FILE"

case "$OUTPUT" in
  csv)
    echo "instanceID,name,instance-type,AMI-ID,AMI-name,platform-arch,state,ebs"
    awk -F'\t' '{printf "%s,%s,%s,%s,%s,%s,%s,%s\n", $2, $1, $3, $4, $5, $6, $7, $8}' "$SORTED_FILE"
    ;;
  markdown|table)
    echo "| instanceID | name | instance-type | AMI-ID | AMI-name | platform-arch | state | ebs |"
    echo "|---|---|---|---|---|---|---|---|"
    awk -F'\t' '{
      for (i = 1; i <= NF; i++) {
        gsub(/\|/, "\\|", $i)
      }
      printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", $2, $1, $3, $4, $5, $6, $7, $8
    }' "$SORTED_FILE"
    ;;
  *)
    echo "Invalid output format: $OUTPUT (use markdown or csv)" >&2
    exit 1
    ;;
esac
