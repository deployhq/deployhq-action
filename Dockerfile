FROM alpine:latest

LABEL "com.github.actions.name"="DeployHQ Webhook Action"
LABEL "com.github.actions.description"="Trigger a DeployHQ deployment using Github Actions"
LABEL "com.github.actions.icon"="upload-cloud"
LABEL "com.github.actions.color"="purple"

LABEL version="0.0.1"
LABEL repository="https://github.com/viktodorov/deployHQ-webhook-action"
LABEL homepage="https://www.deployhq.com/"
LABEL maintainer="Support DeployHQ <support@deployhq.com>"

RUN apk update && apk add openssl curl

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]