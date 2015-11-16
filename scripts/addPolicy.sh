#!/bin/bash
# addPolicy.sh
# Script to add a new IAM policy
#

# Globals
TOPDIR="$(cd $(dirname $0)/..; pwd)"
SCRIPTDIR="${TOPDIR}/scripts"
METADIR="${TOPDIR}/policies/meta"
POLICYDIR="${TOPDIR}/policies"
VERTEMPLATE="${POLICYDIR}/policy-version-template.json"
JQ=$(which jq)

# Make sure we have `jq`
if [ -z "${JQ}" ]; then
    echo "This script requires jq to be installed."
fi

# Argument Handling
if [ $# -ne 1 ]; then
    echo "Missing arument"
    echo "Usage: $0 policy-name"
    exit 1
fi
ID=$1
POLICY="${POLICYDIR}/${ID}.json"
if [ ! -f "${POLICY}" ]; then
    echo "No such policy: ${POLICY}"
    exit 2
fi
META="${METADIR}/${ID}.json"
if [ ! -f "${META}" ]; then
    echo "Meta for policy not found: ${META}"
    exit 2
fi

# Extract the PolicyName from the meta
NAME="$(${JQ} '.PolicyName' ${META} | sed -e 's/"//g')"
echo "IAM Policy: ${NAME}"

# Grab all managed policies
aws iam list-policies --scope Local > /tmp/all-policies.json

# Does this policy already exist?
# - We also grab the ARN for use later
ARN=$(${JQ} '.Policies | .[].Arn' /tmp/all-policies.json | sed -e 's/"//g' |grep "${NAME}" 2>&1)

# Policy already exists, so create a new version
if [ $? -eq 0 ]; then
    echo -n "Adding new policy version ..."

    # Slip the ARN into the version template
    sed -e "s/XXPOLICYARNXX/$(echo "${ARN}"|sed -e 's|\/|\\&|g')/" ${VERTEMPLATE} > /tmp/${NAME}-1.json

    # Slip the policy into the version template
    sed -e "s/XXPOLICYDOCXX/$(${JQ} -c . ${POLICY} | sed -e 's/"/\\&/g' -e 's/[]"[]/\\&/g')/" /tmp/${NAME}-1.json > /tmp/${NAME}-2.json

    # Create the new policy version
    aws iam create-policy-version --cli-input-json file:///tmp/${NAME}-2.json \
        > /tmp/${NAME}-result.json
    if [ $? -ne 0 ]; then
        echo "There was an error creating the policy" version
        exit 3
    fi

# Policy does not exist yet, so create it
else
    echo -n "Adding new policy ..."

    # Slip the policy into the create meta
    sed -e "s/XXPOLICYDOCXX/$(${JQ} -c . ${POLICY} | sed -e 's/"/\\&/g' -e 's/[]"[]/\\&/g')/" ${META} > /tmp/${NAME}.json

    # Create the policy
    aws iam create-policy --cli-input-json file:///tmp/${NAME}.json \
        > /tmp/${NAME}-result.json
    if [ $? -ne 0 ]; then
        echo "There was an error creating the policy"
        exit 3
    fi
fi
echo " done."

# Clean up
rm /tmp/all-policies.json /tmp/${NAME}*.json

#
# End: add-policy.sh
