#!/usr/bin/env bash

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

configure_aws_cli(){
	aws --version
	aws configure set default.region us-east-1
	aws configure set default.output json
}

deploy_cluster() {

    family="nodetodotask-circle"

    make_task_def
    register_definition
    if [[ $(aws ecs update-service --cluster Prod --service WebTier --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
  #  for attempt in {1..90}; do
   #     if stale=$(aws ecs describe-services --cluster Prod --services WebTier | \
    #                   $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
     #       echo "Waiting for stale deployments:"
      #      echo "$stale"
       #     sleep 5
       # else
            echo "Deployed!"
            return 0
 #       fi
 #   done
 #   echo "Service update took too long."
 #   return 1
}

make_task_def(){
	task_template='[
		{
			"name": "nodetodo",
			"image": "%s.dkr.ecr.us-east-1.amazonaws.com/nodetodo:%s",
			"essential": true,
			"memory": 1000,
			"cpu": 200,
			"portMappings": [
				{
					"containerPort": 3000,
					"hostPort": 80
				}
			]
		}
	]'
	
	task_def=$(printf "$task_template" $AWS_ACCOUNT_ID $CIRCLE_SHA1)
}

push_ecr_image(){
	eval $(aws ecr get-login --region us-east-1)
	docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/nodetodo:$CIRCLE_SHA1
}

register_definition() {

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family $family | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

configure_aws_cli
push_ecr_image
deploy_cluster