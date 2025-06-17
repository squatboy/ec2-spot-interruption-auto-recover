#!/bin/bash
set -euo pipefail

# 데이터 볼륨 attach
VOL_ID=$(aws ec2 describe-volumes \
  --filters Name=tag:Name,Values=${volume_tag
} Name=status,Values=available \
  --query 'Volumes[
    0
].VolumeId' --output text --region ${AWS_REGION
})

aws ec2 attach-volume --volume-id ${VOL_ID
} \
  --instance-id $(curl -s http: //169.254.169.254/latest/meta-data/instance-id) \
  --device /dev/xvdh --region ${AWS_REGION
}

# 볼륨 ready 대기 및 마운트
until [ -e /dev/xvdh
]; do sleep 1; done
mkdir -p /data
mount /dev/xvdh /data

# 예제 애플리케이션 시작
systemctl start myapp
