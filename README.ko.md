## 개요

이 인프라 예제는 AWS EC2 Spot 인스턴스가 중단(회수) 경고를 받으면 EventBridge가 알림을 감지하고 Lambda를 통해 데이터 볼륨 스냅샷 및 AMI 백업을 수행한 뒤, Auto Scaling Group의 capacity-rebalance 기능으로 신규 Spot 인스턴스를 프로비저닝하여 최소한의 다운타임으로 서비스 복구를 지원합니다. 모든 리소스는 Terraform으로 코드화하여 관리합니다.



## 시스템 구성도
<img width="890" alt="image" src="https://github.com/user-attachments/assets/7c938a72-d100-433f-acbb-a5028651c3d2" />



## 동작 원리

1. **EventBridge**가 2분 전 Spot 중단 경고(`EC2 Spot Instance Interruption Warning`) 이벤트를 감지합니다.
2. 해당 이벤트를 **Lambda**로 전달하면, Lambda가 SSM Run Command를 통해 애플리케이션을 안전 종료(graceful shutdown)합니다.
3. 이어서 Lambda는 **EBS 데이터 볼륨**의 스냅샷과 현재 인스턴스의 **AMI** 생성을 비동기 호출합니다.
4. **Auto Scaling Group**(`capacity_rebalance=true`)이 즉시 새 Spot 인스턴스를 프로비저닝합니다.
5. 마지막으로 Lambda가 **Elastic IP**를 새 인스턴스에 재연결하여 서비스의 IP 변경 없이 무중단으로 복구를 완료합니다.



## 적용 및 프로비저닝

### 1. 사전 준비

- Terraform 설치 (v1.2 이상)
- AWS CLI 설정 (IAM 권한: EC2, SSM, Lambda, Events)
- GitHub Actions 사용 시 워크플로우 활성화

### 2. 코드 클론 및 변수 설정

```bash
git clone <https://github.com/><YOUR_ORG>/aws-spot-autorecover.git
cd aws-spot-autorecover/terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 내부 변수(region, availability_zone, private_subnets 등) 수정

```

### 3. Terraform 실행

```bash
terraform init
terraform apply -auto-approve

```

### 4. 배포 확인

- AWS 콘솔에서 Auto Scaling Group, Lambda, EventBridge, EIP 리소스 확인
- Spot 인스턴스 생성 및 태그 적용 여부 확인

### 5. 테스트

- 낮은 사양 Spot 인스턴스에서 인위적 중단(시험 모드) 테스트
- CloudWatch Logs 및 Lambda 로그로 각 단계 정상 수행 여부 검증



## 주의 사항

- **백업 AMI**는 재해 복구용으로만 사용하며, 프로덕션 AMI 갱신은 별도 파이프라인에서 관리하세요.
- 스냅샷/AMI 생성은 2분 이내 호출 완료되어야 하며, AWS 백엔드에서 백업 작업이 계속 진행됩니다.
- 필요 시 EBS 대신 EFS로 교체해 다중 AZ 데이터 지속성을 확보할 수 있습니다.

