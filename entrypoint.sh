#!/bin/sh

set -e

######## Check for required/optional inputs. ########

# Check if DeployHQ webhook URL is set (Required).
# Found in DeployHQ's dashboard, under "Automatic Deployments".
if [ -z "$DEPLOYHQ_WEBHOOK_URL" ]; then
  echo "DEPLOYHQ_WEBHOOK_URL is not set. Please set your DEPLOYHQ_WEBHOOK_URL variable before retrying. Quitting."
  exit 1
fi

# Check if revision is set (Required). 
# Can be set to "latest".
if [ -z "$REPO_REVISION" ]; then
  REPO_REVISION="latest"
  echo "REPO_REVISION is not set. Setting to "latest" by default. If this is incorrect, please set "REPO_REVISION" to your preferred branch and retry."
fi

# Check if repo branch is set (Required).
if [ -z "$REPO_BRANCH" ]; then
  REPO_BRANCH="main"
  echo "REPO_BRANCH is not set. Setting to "main" by default. If this is incorrect, please set "REPO_BRANCH" to your preferred branch and retry."
fi

# Check if the email is set (Required).
# If request is sent without email, 500 "INTERNAL_ERROR" response
if [ -z "$DEPLOYHQ_EMAIL" ]; then
  echo "DEPLOYHQ_EMAIL is not set. Please set your DEPLOYHQ_EMAIL variable before retrying. Quitting."
  exit 1
fi

# Check if repo clone URL is set (Required). 
# URL must follow the SSH pattern: "git@yourhost:path".
### ${TESTING_SUBSTRING#*//} -> removes all prefix until "//", used for domain substring, as GITHUB_SERVER_URL is given with "https://"."
if [ -z "$REPO_CLONE_URL" ]; then
  REPO_CLONE_URL="git@${GITHUB_SERVER_URL#*//}:${GITHUB_REPOSITORY}.git"
  echo "REPO_CLONE_URL is not set. Setting REPO_CLONE_URL as ${REPO_CLONE_URL}."
fi



set -- --data '{"payload":{ "new_ref":"'"${REPO_REVISION}"'","branch":"'"${REPO_BRANCH}"'","email":"'"${DEPLOYHQ_EMAIL}"'","clone_url":"'"${REPO_CLONE_URL}"'"}}'

######## Call the webhook API (POST) and store the response for later. ########
# Payload reference: https://www.deployhq.com/support/deployments/automatic-deployments/custom
# For full API call reference, send a GET API call to "DEPLOYHQ_WEBHOOK_URL".
 
HTTP_RESPONSE=$(curl -sS "${DEPLOYHQ_WEBHOOK_URL}" \
                    -H "Content-type: application/json" \
                    -H "Accept: application/json" \
                    -w "HTTP_STATUS:%{http_code}" \
                    "$@")

######## Format response for a pretty command line output. ########

# Store result and HTTP status code separately to appropriately throw CI errors.
# https://gist.github.com/maxcnunes/9f77afdc32df354883df

HTTP_BODY=$(echo "${HTTP_RESPONSE}" | sed -E 's/HTTP_STATUS\:[0-9]{3}$//')
HTTP_STATUS=$(echo "${HTTP_RESPONSE}" | tr -d '\n' | sed -E 's/.*HTTP_STATUS:([0-9]{3})$/\1/')

# Fail pipeline and print errors if API doesn't return an OK status.
if [ "${HTTP_STATUS}" -eq "200" ]; then
  echo "Successfully triggered deployment on DeployBot!"
  echo "${HTTP_BODY}"
  exit 0
else
  echo "Trigger deployment failed. API response was: "
  echo "${HTTP_BODY}"
  exit 1
fi