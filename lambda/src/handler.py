import boto3
import os

ec2 = boto3.client("ec2")
ssm = boto3.client("ssm")


def handler(event, context):
    instance_id = event["detail"]["instance-id"]

    # 1. 애플리케이션 안전 종료 (Docker 컨테이너 중지)
    ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName=os.environ["SSM_DOCUMENT"],
        Parameters={
            "commands": [
                # 60초 동안 정상 종료를 기다린 후 강제 종료
                "docker stop -t 60 myapp-container"
            ]
        },
    )

    # 2. EBS 볼륨 스냅샷 생성
    # 인스턴스에 연결된 데이터 볼륨 찾기
    volumes = ec2.describe_volumes(
        Filters=[
            {"Name": "attachment.instance-id", "Values": [instance_id]},
            {"Name": "tag:Name", "Values": [os.environ["VOLUME_TAG"]]},
        ]
    )["Volumes"]

    if volumes:
        volume_id = volumes[0]["VolumeId"]
        ec2.create_snapshot(
            VolumeId=volume_id, Description=f"Spot backup for {instance_id}"
        )

    # 3. AMI 생성 로직은 더 이상 필요 없으므로 삭제

    return {
        "statusCode": 200,
        "body": f"Graceful shutdown and backup process initiated for {instance_id}",
    }
