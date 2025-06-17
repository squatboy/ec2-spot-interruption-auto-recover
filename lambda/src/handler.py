import os
import boto3

ec2 = boto3.client('ec2')
ssm = boto3.client('ssm')

def handler(event, context):
    instance_id = event['detail']['instance-id']
    # 1. Graceful shutdown
    ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName=os.environ['SSM_DOCUMENT'],
        Parameters={'commands': ['systemctl stop myapp']}
    )

    # 2. EBS 데이터 볼륨 스냅샷 생성
    vols = ec2.describe_volumes(
        Filters=[
            {'Name': 'tag:Name', 'Values': [os.environ['VOLUME_TAG']]},
            {'Name': 'status',     'Values': ['available']}
        ]
    )['Volumes']
    for v in vols:
        snap = ec2.create_snapshot(
            VolumeId=v['VolumeId'],
            Description=f"Spot backup {instance_id}"
        )
        ec2.create_tags(Resources=[snap['SnapshotId']], Tags=[{'Key':'CreatedBy','Value':'spot-backup'}])

    # 3. AMI 생성 (NoReboot=False)
    ec2.create_image(
        InstanceId=instance_id,
        Name=f"spot-backup-ami-{instance_id}",
        NoReboot=False
    )

    # 4. Elastic IP 재연결
    ec2.associate_address(
        InstanceId=instance_id,
        AllocationId=os.environ['ALLOCATION_ID']
    )