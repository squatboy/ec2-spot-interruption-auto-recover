## 개요

이 인프라 예제는 AWS EC2 Spot 인스턴스가 중단(회수) 경고를 받으면 EventBridge가 알림을 감지하고 Lambda를 통해 데이터 볼륨 스냅샷 및 AMI 백업을 수행한 뒤, Auto Scaling Group의 capacity-rebalance 기능으로 신규 Spot 인스턴스를 프로비저닝하여 최소한의 다운타임으로 서비스 복구를 지원합니다. 모든 리소스는 Terraform으로 코드화하여 관리합니다.



## 시스템 구성도
<img width="895" alt="image" src="https://github.com/user-attachments/assets/0984bbfd-607a-4f72-905f-43fd06908129" />






## 동작 원리

1. **EventBridge**가 2분 전 Spot 중단 경고(`EC2 Spot Instance Interruption Warning`) 이벤트를 감지합니다.
2. 해당 이벤트를 **Lambda**로 전달하면, Lambda가 SSM Run Command를 통해 애플리케이션을 안전 종료(graceful shutdown)합니다.
3. 이어서 Lambda는 **EBS 데이터 볼륨**의 스냅샷과 현재 인스턴스의 **AMI** 생성을 비동기 호출합니다.
4. **Auto Scaling Group**(`capacity_rebalance=true`)이 즉시 새 Spot 인스턴스를 프로비저닝합니다.
5. 새 인스턴스는 부팅 시 실행되는 **user-data 스크립트**를 통해 이전 데이터 볼륨을 자동으로 마운트하고 애플리케이션을 실행합니다.
6. **알림 및 모니터링**:
   - 스팟 중단 경고가 감지되면 **SNS 경고 메시지**가 발송됩니다.
   - 새 인스턴스에서 user-data 스크립트가 성공적으로 종료되면, **성공 메시지**를 SNS를 통해 발송합니다.
7. 마지막으로, Lambda 함수가 **Elastic IP를 새 인스턴스에 재연결**함으로써 IP 변경 없이 서비스가 복구됩니다.



## 적용 및 프로비저닝

### 1. 사전 준비

- Terraform 설치 (v1.2 이상)
- AWS CLI 설정 (IAM 권한: EC2, SSM, Lambda, Events)
- SNS 경고 수신용 이메일 또는 웹훅 URL
- GitHub Actions 사용 시 워크플로우 활성화

### 2. 코드 클론 및 변수 설정

```bash
git clone <https://github.com/><YOUR_ORG>/aws-spot-autorecover.git
cd aws-spot-autorecover/terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 내부 변수(region, availability_zone, private_subnets, alert_email 등) 수정

```

### 3. Terraform 실행

```bash
terraform init
terraform apply -auto-approve

```

### 4. 배포 확인

- AWS 콘솔에서 Auto Scaling Group, Lambda, EventBridge, SNS 주제 및 구독 (이메일 또는 웹훅), EIP 리소스 확인
- Spot 인스턴스 생성 및 태그 적용 여부 확인

### 5. 테스트

- 낮은 사양 Spot 인스턴스에서 인위적 중단(시험 모드) 테스트 - 수동 중단 이벤트를 트리거:
  ```bash
  aws ec2 send-spot-instance-interruptions \
  --instance-ids <your-instance-id>
  ```
  
- 다음 항목들을 모니터링합니다:
  - Spot 중단 경고에 대한 SNS 알림
  - Lambda 함수의 CloudWatch 로그 (SSM, 스냅샷, AMI 생성)
  - 새 인스턴스에서 user-data 스크립트 완료 후 SNS 성공 알림



## 주의 사항

- **백업 AMI**는 재해 복구용으로만 사용하며, 프로덕션 AMI 갱신은 별도 파이프라인에서 관리하세요.
- 스냅샷/AMI 생성은 2분 이내 호출 완료되어야 하며, AWS 백엔드에서 백업 작업이 계속 진행됩니다.
- 멀티 AZ 데이터 안정성이 필요하다면 EBS 대신 EFS를 사용하는 것을 고려하고, user-data 스크립트도 이에 맞게 수정하세요.
- user-data 및 Lambda 핸들러 내부의 명령은 실제 사용하는 애플리케이션 로직에 맞게 수정하여 적용하세요.

