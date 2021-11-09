#!/bin/bash
# ##############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# ##############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
k8s_cmd=kubectl
oc_cmd=oc

###### Create the namespace
echo
echo "Creating \"${CP4BA_PROJECT_NAME}\" project ... "
${k8s_cmd} create namespace "${CP4BA_PROJECT_NAME}"
echo

###### Create the secrets
echo -e "\x1B[1mCreating secret \"admin.registrykey\" in ${CP4BA_PROJECT_NAME}...\n\x1B[0m"
CREATE_SECRET_RESULT=$(${k8s_cmd} create secret docker-registry admin.registrykey -n "${CP4BA_PROJECT_NAME}" --docker-username="${DOCKER_USERNAME}" --docker-password="${ENTITLED_REGISTRY_KEY}" --docker-server="${DOCKER_SERVER}" --docker-email="${ENTITLED_REGISTRY_EMAIL}")
sleep 5

if [[ ${CREATE_SECRET_RESULT} ]]; then
    echo -e "\033[1;32m \"admin.registrykey\" secret has been created\x1B[0m"
fi

echo
echo -e "\x1B[1mCreating secret \"ibm-entitlement-key\" in ${CP4BA_PROJECT_NAME}...\n\x1B[0m"
CREATE_SECRET_RESULT=$(${k8s_cmd} create secret docker-registry ibm-entitlement-key -n "${CP4BA_PROJECT_NAME}" --docker-username="${DOCKER_USERNAME}" --docker-password="${ENTITLED_REGISTRY_KEY}" --docker-server="${DOCKER_SERVER}" --docker-email="${ENTITLED_REGISTRY_EMAIL}")
sleep 5

if [[ ${CREATE_SECRET_RESULT} ]]; then
    echo -e "\033[1;32m \"ibm-entitlement-key\" secret has been created\x1B[0m"
fi
echo

# echo -e "\x1B[1mCreating remaining secrets \n${SECRETS_CONTENT}...\n\x1B[0m"
echo -e "\x1B[1mCreating remaining secrets...\n\x1B[0m"
${k8s_cmd} apply -n "${CP4BA_PROJECT_NAME}" -f -<<EOF
${SECRETS_CONTENT}
EOF

echo ""
###### Create storage
echo -e "Creating storage classes..."
${k8s_cmd} apply -f "${CP4BA_STORAGE_CLASS_FILE}"

echo -e "\x1B[1mCreating the Persistent Volumes Claim (PVC)...\x1B[0m"
${k8s_cmd} apply -f -<<EOF
 ${OPERATOR_PVC_FILE}
EOF

CREATE_PVC_RESULT=$(${k8s_cmd} -n "${CP4BA_PROJECT_NAME}" apply -f "${OPERATOR_PVC_FILE}")

if [[ $CREATE_PVC_RESULT ]]; then
    echo -e "\x1B[1;34mThe Persistent Volume Claims have been created.\x1B[0m"
else
    echo -e "\x1B[1;31mFailed\x1B[0m"
fi
# Check Operator Persistent Volume status every 5 seconds (max 10 minutes) until allocate.
ATTEMPTS=0
TIMEOUT=60
printf "\n"
echo -e "\x1B[1mWaiting for the persistent volumes to be ready...\x1B[0m"
until (${k8s_cmd} get pvc -n "${CP4BA_PROJECT_NAME}" | grep cp4a-shared-log-pvc | grep "Bound") || [ $ATTEMPTS -eq $TIMEOUT ] ; do
    ATTEMPTS=$((ATTEMPTS + 1))
    echo -e "......"
    sleep 10
    if [ $ATTEMPTS -eq $TIMEOUT ] ; then
        echo -e "\x1B[1;31mFailed: Run the following command to check the claim '${k8s_cmd} describe pvc cp4a-shared-log-pvc'\x1B[0m"
        exit 1
    fi
done
if [ $ATTEMPTS -lt $TIMEOUT ] ; then
    echo -e "\x1B[1;34m The Persistent Volume Claim is successfully bound\x1B[0m"
fi
echo

ATTEMPTS=0
TIMEOUT=60
echo -e "\x1B[1mWaiting for the persistent volumes to be ready...\x1B[0m"
until (${k8s_cmd} get pvc -n "${CP4BA_PROJECT_NAME}" | grep operator-shared-pvc | grep "Bound") || [ $ATTEMPTS -eq $TIMEOUT ] ; do
    ATTEMPTS=$((ATTEMPTS + 1))
    echo -e "......"
    sleep 10
    if [ $ATTEMPTS -eq $TIMEOUT ] ; then
        echo -e "\x1B[1;31mFailed: Run the following command to check the claim '${k8s_cmd} describe pvc operator-shared-pvc'\x1B[0m"
        exit 1
    fi
done
if [ $ATTEMPTS -lt $TIMEOUT ] ; then
    echo -e "\x1B[1;34m The Persistent Volume Claim is successfully bound\x1B[0m"
fi
echo

sleep 5
echo ""

###### Create common service subscription
echo -e "\x1B[1mCreating the Common Service Subscription...\n${CMN_SERVICES_SUBSCRIPTION_FILE}\n\x1B[0m"
${k8s_cmd} apply -f "${CMN_SERVICES_SUBSCRIPTION_FILE}"


echo -e "\x1B[1mCreating the Service Account...\n${SERVICE_ACCOUNT_FILE}\n\x1B[0m"
${k8s_cmd} apply -f "${SERVICE_ACCOUNT_FILE}"

sleep 5

echo ""

echo -e "\x1B[1mCreating the Role Binding...\n${ROLE_BINDING_FILE}\n\x1B[0m"
${k8s_cmd} apply -f "${ROLE_BINDING_FILE}"

echo ""

###### Add the CatalogSource resources to Operator Hub
echo -e "\x1B[1mCreating the Catalog Source...\x1B[0m"
#cat ${CATALOG_SOURCE_FILE}
${k8s_cmd} apply -f "${CATALOG_SOURCE_FILE}"

echo


###### Copy JDBC Files
#echo -e "\x1B[1mCopying JDBC License Files...\x1B[0m"
#podname=$(${k8s_cmd} get pods -n ${CP4BA_PROJECT_NAME} | grep ibm-cp4a-operator | awk '{print $1}')
#${k8s_cmd} cp ${CUR_DIR}/files/jdbc ${CP4BA_PROJECT_NAME}/$podname:/opt/ansible/share

###### Create subscription to Business Automation Operator
#echo -e "\x1B[1mCreating the Subscription...\n${CP4BA_SUBSCRIPTION}\n\x1B[0m"
#${k8s_cmd} apply -f -<<EOF
#${CP4BA_SUBSCRIPTION}
#EOF
#echo "Sleeping for 5 minutes"
#sleep 300



###### Create common service subscription
#echo -e "\x1B[1mCreating the Common Service Subscription...\n${CMN_SERVICES_SUBSCRIPTION_FILE_CONTENT}\n\x1B[0m"
#k8s_cmd apply -f ${CMN_SERVICES_SUBSCRIPTION_FILE_CONTENT}


# Apply CP4BA

${oc_cmd} project "${CP4BA_PROJECT_NAME}"

echo

echo "Creating IBM CP4BA Subscription ..."
${k8s_cmd} apply -f "${CP4BA_SUBSCRIPTION_FILE}" -n "${CP4BA_PROJECT_NAME}"


function cp4ba_deployment() {
#    echo "Creating tls secret key ..."
#    ${CLI_CMD} apply -f "${TLS_SECRET_FILE}" -n "${CP4BA_PROJECT_NAME}"

#    echo "Creating the AutomationUIConfig & Cartridge deployment..."
#    ${k8s_cmd} apply -f "${AUTOMATION_UI_CONFIG_FILE}" -n "${CP4BA_PROJECT_NAME}"
#    ${k8s_cmd} apply -f "${CARTRIDGE_FILE}" -n "${CP4BA_PROJECT_NAME}"
#    echo "Done."

#    ${CLI_CMD} apply -f "${PARENT_DIR}"/files/t_icp4badeploy.yaml





    echo -e "Sleeping for 5 minutes"
    sleep 300
#    sleep 2
    echo

#    echo "Deploying Cloud Pak for Business Automation Capabilities ..."
#    ${k8s_cmd} apply -f "${IBM_CP4BA_CR_FINAL_FILE}" -n "${CP4BA_PROJECT_NAME}"

    if ${k8s_cmd} get catalogsource -n openshift-marketplace | grep ibm-operator-catalog ; then
        echo "Found ibm operator catalog source"
    else
        ${k8s_cmd} apply -f "${CATALOG_SOURCE_FILE}"
        if [ $? -eq 0 ]; then
          echo "IBM Operator Catalog source created!"
        else
          echo "Generic Operator catalog source creation failed"
          exit 1
        fi
    fi

#    while [[ "${result}" -ne 0 ]]
#    do
#        if [[ $counter -gt 20 ]]; then
#            echo "The CP4BA Operator was not created within ten minutes; please attempt to install the product again."
#            exit 1
#        fi
#        counter=$((counter + 1))
#        echo "Waiting for CP4BA operator pod to provision"
#        sleep 30;
#        ${k8s_cmd} get pods -n "${CP4BA_PROJECT_NAME}" | grep ibm-cp4a-operator
#        result=$?
#    done

    local maxRetry=20
    for ((retry=0;retry<=${maxRetry};retry++)); do
      echo "Waiting for CP4BA Operator Catalog pod initialization"

      isReady=$(${k8s_cmd} get pod -n openshift-marketplace --no-headers | grep ibm-operator-catalog | grep "Running")
      if [[ -z $isReady ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then
          echo "Timeout Waiting for  CP4BA Operator Catalog pod to start"
          exit 1
        else
          sleep 5
          continue
        fi
      else
        echo "CP4BA Operator Catalog is running $isReady"
        break
      fi
    done

    for ((retry=0;retry<=${maxRetry};retry++)); do
      echo "Waiting for CP4BA operator pod initialization"

      isReady=$(${k8s_cmd} get pod -n "${CP4BA_PROJECT_NAME}" --no-headers | grep ibm-cp4a-operator | grep "Running")
      if [[ -z $isReady ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then
          echo "Timeout Waiting for CP4BA operator to start"
          exit 1
        else
          sleep 5
          continue
        fi
      else
        echo "CP4BA operator is running $isReady"
        break
      fi
    done
}

cp4ba_deployment

echo

###### Create Deployment
echo -e "\x1B[1mCreating the Deployment \n${CP4BA_DEPLOYMENT_FILE}...\x1B[0m"
${k8s_cmd} apply -f "${CP4BA_DEPLOYMENT_FILE}" -n "${CP4BA_PROJECT_NAME}"
sleep 2


##### Create Deployment
#echo -e "\x1B[1mCreating the Deployment \n${CP4BA_DEPLOYMENT_CONTENT}...\x1B[0m"
#${k8s_cmd} apply -n ${CP4BA_PROJECT_NAME} -f -<<EOF
#${CP4BA_DEPLOYMENT_CONTENT}
#EOF