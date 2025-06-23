#!/bin/bash
set -euo pipefail

# 0) 공통 함수
retry() {
  local n=0
  local max=$${2:-12}   # 수정: 셸 변수 이스케이프
  local sleep_s=$${3:-5} # 수정: 셸 변수 이스케이프
  until "$@"; do
    ((n++)) && (( n >= max )) && return 1
    sleep "$sleep_s"
  done
}

# 1) 메타데이터(IMDSv2)로 식별 정보 확보
TOKEN=$(curl -fsX PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

meta() {
  curl -fs -H "X-aws-ec2-metadata-token: $TOKEN" \
       "http://169.254.169.254/latest/$1"
}

INSTANCE_ID=$(meta meta-data/instance-id)
AWS_REGION=$(meta meta-data/placement/region)
ACCOUNT_ID=$(meta dynamic/instance-identity/document \
           | grep -oP '"accountId"\s*:\s*"\K[0-9]+')

# 2) ASG 이름 태그 확보 (최대 1분 재시도)
get_asg() {
  aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$${INSTANCE_ID}" "Name=key,Values=aws:autoscaling:groupName" \
    --region "$${AWS_REGION}" \
    --query 'Tags[0].Value' --output text 2>/dev/null || true
}

ASG_NAME=$(retry get_asg 12 5 || echo "unknown")

# 3) 데이터 EBS 볼륨 attach
find_volume() {
  aws ec2 describe-volumes \
    --filters "Name=tag:Name,Values=${volume_tag}" \
              "Name=status,Values=available" \
    --region "$${AWS_REGION}" \
    --query 'Volumes[0].VolumeId' --output text 2>/dev/null || true
}

VOL_ID=$(retry find_volume 12 5)
if [[ -z "$VOL_ID" || "$VOL_ID" == "None" ]]; then
  echo "❌ 데이터 볼륨(${volume_tag})을 찾을 수 없습니다." >&2
  exit 1
fi

aws ec2 attach-volume \
  --volume-id  "$${VOL_ID}" \
  --instance-id "$${INSTANCE_ID}" \
  --device /dev/sdf \
  --region "$${AWS_REGION}"

# 4) 디바이스 확인 후 마운트 (파일시스템 체크 및 포맷 로직 추가)
retry test -e /dev/xvdh 30 2 || retry test -e /dev/sdf 30 2
DEV_PATH=$(test -e /dev/xvdh && echo /dev/xvdh || echo /dev/sdf)

if ! blkid -s TYPE -o value "$DEV_PATH"; then
  echo "파일시스템이 없어 $${DEV_PATH}를 포맷합니다."
  mkfs.ext4 "$DEV_PATH"
fi

mkdir -p /data
mount "$DEV_PATH" /data

# 5) 애플리케이션 기동
systemctl start myapp

# 6) 유저데이터 완료 SNS 알림
TOPIC_ARN="arn:aws:sns:$${AWS_REGION}:$${ACCOUNT_ID}:SpotRecoveryAlerts"

aws sns publish \
  --topic-arn "$${TOPIC_ARN}" \
  --subject "✅ userdata COMPLETE on $${INSTANCE_ID}" \
  --message "Instance $${INSTANCE_ID} user-data script finished successfully." \
  --region "$${AWS_REGION}"

exit 0