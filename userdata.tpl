#!/bin/bash
set -euo pipefail

# 0) 공통 함수
# 사용법: retry <최대 시도 횟수> <대기 시간(초)> <실행할 명령어와 인자들>
retry() {
    local max_retries=$1
    local sleep_interval=$2
    shift 2 # 함수 인자에서 처음 2개(횟수, 시간)를 제거
    local cmd=("$@") # 나머지 모든 인자를 '명령어'로 인식

    local n=0
    until "$${cmd[@]}"; do
        ((n++)) && (( n >= max_retries )) && return 1
        sleep "$sleep_interval"
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
  local vol_id
  vol_id=$(aws ec2 describe-volumes --filters "Name=tag:Name,Values=${volume_tag}" "Name=status,Values=available" --region "$${AWS_REGION}" --query 'Volumes[0].VolumeId' --output text 2>/dev/null)

  if [[ -n "$vol_id" && "$vol_id" != "None" ]]; then
    echo "$vol_id"
    return 0
  else
    return 1
  fi
}

VOL_ID=$(retry 12 5 find_volume)
if [[ -z "$VOL_ID" ]]; then
  echo "❌ 데이터 볼륨(${volume_tag})을 찾을 수 없습니다." >&2
  exit 1
fi
aws ec2 attach-volume --volume-id "$${VOL_ID}" --instance-id "$${INSTANCE_ID}" --device /dev/sdf --region "$${AWS_REGION}"

# 3) 디바이스 확인 후 마운트
find_device_path() {
    if [ -e /dev/xvdf ]; then echo "/dev/xvdf"; return 0;
    elif [ -e /dev/sdf ]; then echo "/dev/sdf"; return 0;
    fi
    return 1
}

DEV_PATH=$(retry 30 2 find_device_path)
if ! blkid -s TYPE -o value "$DEV_PATH"; then
  echo "파일시스템이 없어 $${DEV_PATH}를 포맷합니다."
  mkfs.ext4 "$DEV_PATH"
fi
mkdir -p /data
mount "$DEV_PATH" /data

# 4) Docker 컨테이너 실행

# Docker 데몬 활성화 및 시작
systemctl enable --now docker
# ECR 로그인
aws ecr get-login-password --region "$${AWS_REGION}" | docker login --username AWS --password-stdin "$${ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com"
# 기존 컨테이너 정리 (재부팅 시 대비)
docker stop myapp-container || true
docker rm myapp-container || true
# Docker 컨테이너 실행
docker run -d \
  --name myapp-container \
  -v /data:/myapp \
  -p 1234:80 \
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