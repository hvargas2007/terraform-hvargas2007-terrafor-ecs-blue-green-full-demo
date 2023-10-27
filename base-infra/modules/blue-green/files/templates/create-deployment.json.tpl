{
    "applicationName": "${application_name}",
    "deploymentGroupName": "${deployment_group_name}",
    "revision": {
        "revisionType": "S3",
        "s3Location": {
            "bucket": "${s3_bucket}",
            "key": "${s3_key}",
            "bundleType": "YAML"
        }
    }
}