#!/bin/bash
set -euo pipefail

# 0) 공통 함수
retry() {
  local n=0
  local max=$${2:-12}
  local sleep_s=$${3:-5}
  until "$@"; do
    ((n++)) && (( n >= max )) && return 1
    sleep "$sleep_s"
  done
}

# 1) 메타데이터(IMDSv2)로 식별 정보 확보
TOKEN=$(curl -fsX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
meta() { curl -fs -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/$1"; }
INSTANCE_ID=$(meta meta-data/instance-id)
AWS_REGION=$(meta meta-data/placement/region)
ACCOUNT_ID=$(meta dynamic/instance-identity/document | grep -oP '"accountId"\s*:\s*"\K[0-9]+')

# 2) 데이터 EBS 볼륨 attach
find_volume() {
  aws ec2 describe-volumes --filters "Name=tag:Name,Values=${volume_tag}" "Name=status,Values=available" --region "$${AWS_REGION}" --query 'Volumes[0].VolumeId' --output text 2>/dev/null || true
}
VOL_ID=$(retry find_volume 12 5)
if [[ -z "$VOL_ID" || "$VOL_ID" == "None" ]]; then
  echo "❌ 데이터 볼륨(${volume_tag})을 찾을 수 없습니다." >&2
  exit 1
fi
aws ec2 attach-volume --volume-id "$${VOL_ID}" --instance-id "$${INSTANCE_ID}" --device /dev/sdf --region "$${AWS_REGION}"

# 3) 디바이스 확인 후 마운트
retry test -e /dev/xvdh 30 2 || retry test -e /dev/sdf 30 2
DEV_PATH=$(test -e /dev/xvdh && echo /dev/xvdh || echo /dev/sdf)
if ! blkid -s TYPE -o value "$DEV_PATH"; then
  echo "파일시스템이 없어 $${DEV_PATH}를 포맷합니다."
  mkfs.ext4 "$DEV_PATH"
fi
mkdir -p /data
mount "$DEV_PATH" /data

# 4) Docker 컨테이너 실행
# Docker 데몬 활성화
systemctl start docker
# ECR 로그인
aws ecr get-login-password --region "$${AWS_REGION}" | docker login --username AWS --password-stdin "$${ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com"
# 기존 컨테이너 정리 (재부팅 시 대비)
docker stop myapp || true
docker rm myapp || true
# Docker 컨테이너 실행 (예: 마인크래프트 서버)
docker run -d \
  --name myapp \
  -v /data:/myapp \
  -p 1234:1234 \
  --restart always \
  "${ecr_repository_url}"

# 5) 유저데이터 완료 SNS 알림
TOPIC_ARN="arn:aws:sns:$${AWS_REGION}:$${ACCOUNT_ID}:SpotRecoveryAlerts"
aws sns publish \
  --topic-arn "$${TOPIC_ARN}" \
  --subject "✅ userdata COMPLETE on $${INSTANCE_ID}" \
  --message "Instance $${INSTANCE_ID} user-data script finished successfully. Docker container started." \
  --region "$${AWS_REGION}"

exit 0