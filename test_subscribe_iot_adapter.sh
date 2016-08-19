#! /bin/bash

# Simple script to subscribe to a pub/sub topic
# Must be run on GCE, in a VM with service account access to Pub/Sub since it uses the metadata server for auth info
# Run with a "create" argument to create the subscription (only need to do that once)
#
# It requires 'jq' and 'curl'.


PROJECT="agosto-iot-adapter" # Set YOUR GCP project
TOPIC="gateways" # topic
SUB_NAME="my-test-subscription" # subscription name

FULL_TOPIC="projects/${PROJECT}/topics/${TOPIC}"
URL="https://pubsub.googleapis.com/v1/projects/${PROJECT}/subscriptions/${SUB_NAME}"

# requires jq be installed to parse the json
JQ=`which jq`
if [ "$JQ" == "" ]; then
  echo "ERROR: JQ doesn't appear to be installed.  Try installing with 'sudo apt-get install jq'"
  exit 1
fi

LOG="test_sub_debug.log"
echo "" > $LOG

function get_access_token() {
  token=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" -H "Metadata-Flavor: Google" | jq -a '.access_token'` # get access_token from metadata server
  token=${token//\"/}  # get rid of quotes
}

function create_subscription() {
  JSON="{ \"topic\": \"${FULL_TOPIC}\" }"
  log "create_subscription - Posting JSON: $JSON to URL: $URL"
  resp=`curl -s -X PUT -d "${JSON}" -H "Content-type":" application/json" -H "Authorization":" Bearer ${token}" $URL`
  log "Response: $resp"
  echo "Response to Subscription creation request:"
  echo $resp
}

function get_messages() {
  PULL_URL="$URL:pull"
  JSON="{ \"returnImmediately\": \"false\", \"maxMessages\": \"1\" }"
  log "get_messages - Posting JSON: $JSON to URL: $PULL_URL"
  resp=`curl -m 300 -s -X POST -d "${JSON}" -H "Content-type":" application/json" -H "Authorization":" Bearer ${token}" $PULL_URL`
  log "Response: $resp"
  ACK_ID=$(echo $resp | jq -a '.receivedMessages [0].ackId')
  ACK_ID=${ACK_ID//\"/} # get rid of quotes
  B64DATA=$(echo $resp | jq -a '.receivedMessages [0].message.data')
  B64DATA=${B64DATA//\"/} # get rid of quotes
  if [ "$B64DATA" != "null" ]; then
    DATA=$(echo $B64DATA | base64 -d)
  else
    DATA="<null>" # received empty json - pub/sub does this after a minute or two
  fi
  ATTRIBUTES=$(echo $resp | jq -a '.receivedMessages [0].message.attributes')
  log "ACK_ID: $ACK_ID"
  log "DATA: $DATA"
  ERROR=$(echo $resp | jq -a '.error')
  if [ "$ERROR" != "null" ]; then
    echo "There was a problem:"
    echo $resp
    echo "Hints:"
    echo "- Did you create the subscription?  If not, try running: $0 create"
    echo "- Are you running this on GCE with the proper scopes enabled?"
    exit 1
  fi
}

function ack_message() {
  ACK_URL="$URL:acknowledge"
  JSON="{\"ackIds\": [\"$ACK_ID\"] }"
  log "ack_message - Posting JSON: $JSON to URL: $ACK_URL"
  resp=`curl -m 300 -s -X POST -d "${JSON}" -H "Content-type":" application/json" -H "Authorization":" Bearer ${token}" $ACK_URL`
  log "Response: $resp"
}

function log() {
  echo $1 >> $LOG
}

get_access_token
if [ "$1" == "create" ]; then
  create_subscription
  exit 0
fi
echo "Waiting for messages.."
while true; do
  get_messages
  echo "Msg: $DATA"
  [ "$ATTRIBUTES" != "null" ] && echo "Attributes: $ATTRIBUTES"
  [ "$ACK_ID" != "null" ] && ack_message
done
