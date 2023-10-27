#!/bin/bash

ROLE_NAME=$1
CODEBUILD_ROLE_ARN=$2
AWS_PROFILE=$3

# Check if the necessary commands are installed
declare -A commands_array=(
    [jq]="https://stedolan.github.io/jq/download/"
    [aws]="https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
)

for key in "${!commands_array[@]}"; 
do
    if command -v $key > /dev/null
        then
            echo "" > /dev/null
        else
            echo "[ERROR] $key not installed - Please install $key to continue"
            echo -e '\n'
            echo "Ref: ${commands_array[$key]}"
            echo -e '\n'
            exit 1
    fi
done

default_profile () {
    echo "Using profile ---> default"
	aws iam get-role --role-name $ROLE_NAME | jq -r '.Role | .AssumeRolePolicyDocument' > Original_Role_Trust_Policy.json
    jq '(.Statement | .[] | .Principal | .AWS) = "'"${CODEBUILD_ROLE_ARN}"'" ' Original_Role_Trust_Policy.json | tee New_Role_Trust_Policy.json
    aws iam update-assume-role-policy --role-name $ROLE_NAME --policy-document file://New_Role_Trust_Policy.json
    cleaning
}

other_profile () {
    echo "Using profile $1"
	aws iam get-role --role-name $ROLE_NAME | jq -r '.Role | .AssumeRolePolicyDocument' --profile $3 > Original_Role_Trust_Policy.json
    jq '(.Statement | .[] | .Principal | .AWS) = "'"${CODEBUILD_ROLE_ARN}"'" ' Original_Role_Trust_Policy.json | tee New_Role_Trust_Policy.json
    aws iam update-assume-role-policy --role-name $ROLE_NAME --policy-document file://New_Role_Trust_Policy.json --profile $3
    cleaning
}

cleaning () {
    rm Original_Role_Trust_Policy.json
	rm New_Role_Trust_Policy.json
}

if [ $# -eq 0 ]
then
	echo "[ERROR] Parameter are needed. Run '$(basename $0) -h' for help"
	exit 1
fi
if [ $# -eq 1 ] && [ ${1} = "-h" ]
then
	echo "[INFO] Usage: $(basename $0) {ROLE_NAME} {CODEBUILD_ROLE_ARN} {AWS_PROFILE}"
    echo ""
	echo " - Example 01: $(basename $0) terraform-apply-role arn:aws:iam::0123456789010:role/terraform-codebuild-role default"
	exit 0
fi
if [ "$AWS_PROFILE" == "default" ]
then
    default_profile
    exit 0
else
    other_profile
    exit 0
fi