## 개요

이 인프라 예제는 AWS EC2 Spot 인스턴스가 중단(회수) 경고를 받으면 EventBridge가 알림을 감지하고 Lambda를 통해 데이터 볼륨 스냅샷을 백업한 뒤, Auto Scaling Group의 capacity-rebalance 기능으로 신규 Spot 인스턴스를 프로비저닝하여 최소한의 다운타임으로 서비스 복구를 지원합니다. 모든 리소스는 Terraform으로 코드화하여 관리합니다.

## 시스템 구성도
<img width="881" alt="image" src="https://github.com/user-attachments/assets/8fcd990d-8d29-47ee-b412-34147bb190d1" />


## 동작 원리

1.  **EventBridge**가 2분 전 Spot 중단 경고(`EC2 Spot Instance Interruption Warning`) 이벤트를 감지합니다.
2.  해당 이벤트를 **Lambda**로 전달하면, Lambda가 SSM Run Command를 통해 Docker 컨테이너를 안전하게 종료(graceful shutdown)시킵니다.
3.  이어서 Lambda는 **EBS 데이터 볼륨**의 스냅샷 생성을 비동기 호출하여 데이터를 백업합니다.
4.  **Auto Scaling Group**(`capacity_rebalance=true`)이 즉시 새 Spot 인스턴스를 프로비저닝합니다.
5.  새 인스턴스는 부팅 시 실행되는 **user-data 스크립트**를 통해 이전 데이터 볼륨을 자동으로 마운트하고, ECR에서 최신 Docker 이미지를 받아 컨테이너를 실행합니다.
6.  **알림 및 모니터링**:
    *   스팟 중단 경고가 감지되면 **SNS 경고 메시지**가 발송됩니다.
    *   새 인스턴스에서 user-data 스크립트가 성공적으로 종료되면, **성공 메시지**를 SNS를 통해 발송합니다.

---

## 적용 및 프로비저닝

아래 단계에 따라 인프라를 배포하세요.

### 1. 사전 준비

- Terraform v1.2 이상
- AWS CLI 설정 (IAM 권한: EC2, SSM, Lambda, SNS, Events, IAM, ECR)
- 애플리케이션이 포함된 Docker 이미지를 Amazon ECR에 푸시
- Docker 엔진이 설치된 커스텀 AMI

### 2. 배포 환경 준비

#### 2.1 단계: 커스텀 AMI 생성 (필수)

이 프로젝트는 **Docker 엔진이 설치된 사전 제작된 AMI가 반드시 필요합니다.**

1.  **기본 인스턴스 시작**: Amazon Linux 2와 같은 기본 AMI로 인스턴스를 시작합니다.
2.  **Docker 설치 및 활성화**: `sudo yum install -y docker`, `sudo systemctl enable docker` 명령으로 Docker를 설치하고 서비스로 활성화합니다.
3.  **AMI 생성 및 태그 지정**: 설정이 완료된 인스턴스에서 AMI를 생성하고, `Name` 태그 값을 `myapp-base-v1`과 같이 지정합니다. Terraform은 이 태그를 사용하여 AMI를 찾습니다.

#### 2.2 단계: Docker 이미지 준비 및 ECR에 푸시

1.  애플리케이션(예: 마인크래프트 서버)이 포함된 `Dockerfile`을 작성하고 이미지를 빌드합니다.
2.  AWS ECR에 리포지토리를 생성합니다.
3.  빌드한 이미지를 ECR 리포지토리에 푸시합니다.

#### 2.3 단계: 설정 파일 준비

리포지토리를 복제하고 예제 파일을 복사하여 `terraform.tfvars` 파일을 생성합니다. 이 파일은 배포에 필요한 설정 값을 저장합니다.

```bash
git clone https://github.com/YOUR_ORG/aws-spot-autorecover.git
cd aws-spot-autorecover
cp terraform.tfvars.example terraform.tfvars
```

이제 `terraform.tfvars` 파일을 열고, 플레이스홀더 값을 실제 리소스 정보(예: 서브넷 ID, 이메일 주소)로 수정하세요.

### 3. Terraform으로 배포

AMI 준비와 `terraform.tfvars` 설정이 완료되면 인프라를 배포할 수 있습니다.

```bash
# Terraform 프로바이더 초기화
terraform init

# AWS에 리소스를 생성하기 위해 설정 적용
terraform apply -auto-approve
```

### 4. 배포 확인

1.  **SNS 구독 확인**: 이메일 받은 편지함에서 AWS로부터 온 구독 확인 링크를 클릭하세요. 이 과정을 거치지 않으면 알림을 받을 수 없습니다.
2.  **리소스 확인**: AWS 콘솔에서 Auto Scaling Group, Lambda 함수, EventBridge 규칙이 생성되었는지 확인합니다.
3.  **애플리케이션 접속**: 새로 시작된 `spot-app-instance`의 퍼블릭 IP를 찾아 브라우저로 접속하여 애플리케이션이 정상 실행되는지 확인합니다.

### 5. 복구 테스트

Spot 인스턴스 회수 이벤트를 시뮬레이션하여 복구 프로세스를 테스트합니다.

1.  실행 중인 Spot 인스턴스의 ID를 확인합니다.
2.  아래 AWS CLI 명령어를 실행합니다:
    ```bash
    aws ec2 send-spot-instance-interruptions \
      --instance-ids <your-instance-id> \
      --region <your-aws-region>
    ```
3.  **복구 과정 모니터링**:
    - 즉시 중단 경고에 대한 **SNS 알림**을 받게 됩니다.
    - 2분 후, Auto Scaling Group에 의해 새 인스턴스가 프로비저닝됩니다.
    - 새 인스턴스에서 user-data 스크립트가 성공적으로 완료되면 또 다른 **SNS 알림**을 받게 됩니다.

## 주의 사항

- **백업 AMI**는 재해 복구용으로만 사용하며, 프로덕션 AMI 갱신은 별도 파이프라인에서 관리하세요.
- 스냅샷/AMI 생성은 2분 이내 호출 완료되어야 하며, AWS 백엔드에서 백업 작업이 계속 진행됩니다.
- 멀티 AZ 데이터 안정성이 필요하다면 EBS 대신 EFS를 사용하는 것을 고려하고, user-data 스크립트도 이에 맞게 수정하세요.
- user-data 및 Lambda 핸들러 내부의 명령은 실제 사용하는 애플리케이션 로직에 맞게 수정하여 적용하세요.

