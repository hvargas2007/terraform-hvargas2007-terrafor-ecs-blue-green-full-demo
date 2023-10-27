---
version: 1.0

Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "${task_definition_revision}"
        LoadBalancerInfo:
          ContainerName: "${container_name}"
          ContainerPort: ${container_port}
        PlatformVersion: "LATEST"