#!/bin/bash
#
# (C) Copyright IBM Corp. 2020
# SPDX-License-Identifier: Apache-2.0
#
# configure-kong.sh
#
# Called from lfh-oci-services.sh to configure the Kong API
#

set -o errexit
set -o nounset
set -o pipefail

function add_http_route() {
  local name=$1
  local method=$2
  local url=$3
  local service=$4
  local hostip=${HOST_IP}
  local hosts='"127.0.0.1","localhost"'
  local admin_url="https://localhost:8444/services/${service}/routes"

  if [ ! $hostip == "127.0.0.1" ]; then
    hosts='"'"${hostip}"'","127.0.0.1","localhost"'
  fi

  curl --insecure "${admin_url}" \
  -H 'Content-Type: application/json' \
  -d '{"paths": ["'"${url}"'"], "methods": ["'"${method}"'"], "hosts": ['"${hosts}"'], "name": "'"${name}"'", "protocols": ["http", "https"], "strip_path": false}'
  echo ""
}

host=${LFH_CONNECT_SERVICE_NAME}
lfhhttp=${LFH_CONNECT_HTTP_PORT}
lfhmllp=${LFH_CONNECT_MLLP_PORT}
kongmllp=${LFH_KONG_MLLP_PORT}

echo "Adding a kong service for LinuxForHealth http routes"
curl --insecure https://localhost:8444/services \
  -H 'Content-Type: application/json' \
  -d '{"name": "lfh-http-service", "url": "http://'"${host}"':'"${lfhhttp}"'"}'
echo ""

echo "Adding kong http routes that match incoming requests and send them to the lfh-http-service url"
add_http_route "hello-world-route" "GET" "/hello-world" "lfh-http-service"
add_http_route "fhir-r4-patient-post-route" "POST" "/fhir/r4/Patient" "lfh-http-service"
add_http_route "orthanc-image-post-route" "POST" "/orthanc/instances" "lfh-http-service"
add_http_route "kafka-get-message-route" "GET" "/datastore/message" "lfh-http-service"
add_http_route "x12-post-route" "POST" "/x12" "lfh-http-service"
add_http_route "ccd-post-route" "POST" "/ccd" "lfh-http-service"

echo "Adding a kong service for the LinuxForHealth hl7v2 mllp route"
curl --insecure https://localhost:8444/services \
  -H 'Content-Type: application/json' \
  -d '{"name": "lfh-hl7v2-service", "url": "tcp://'"${host}"':'"${lfhmllp}"'"}'
echo ""

echo "Adding a kong route that matches incoming requests and sends them to the lfh-hl7v2-service url"
curl --insecure https://localhost:8444/services/lfh-hl7v2-service/routes \
  -H 'Content-Type: application/json' \
  -d '{"name": "lfh-hl7v2-route", "protocols": ["tcp", "tls"], "destinations": [{"port":'"${kongmllp}"'}]}'
echo ""

echo "Adding a kong service for the LinuxForHealth Blue Button 2.0 routes"
curl --insecure https://localhost:8444/services \
  -H 'Content-Type: application/json' \
  -d '{"name": "lfh-bluebutton-service", "url": "http://'"${host}"':'"${lfhhttp}"'"}'
echo ""

echo "Adding Kong http routes that match incoming requests and send them to the lfh-bluebutton-service url"
add_http_route "bb-authorize-route" "GET" "/bluebutton/authorize" "lfh-bluebutton-service"
add_http_route "bb-patient-route" "GET" "/bluebutton/v1/Patient" "lfh-bluebutton-service"
add_http_route "bb-eob-route" "GET" "/bluebutton/v1/ExplanationOfBenefit" "lfh-bluebutton-service"
add_http_route "bb-coverage-route" "GET" "/bluebutton/v1/Coverage" "lfh-bluebutton-service"
