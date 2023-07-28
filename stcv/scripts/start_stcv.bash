#!/bin/bash

sudo -u ec2-user mkdir -p ${STCV_DIR}

#########

if [ ! -z "${STCV_BUCKET_1_NAME}" ]
then
    echo "Mounting bucket ${STCV_BUCKET_1_NAME} to ${STCV_BUCKET_1_MNT_DIR}"
    sudo umount -f ${STCV_BUCKET_1_MNT_DIR}
    sudo -u ec2-user mkdir -p "${STCV_BUCKET_1_MNT_DIR}"
    sudo s3fs ${STCV_BUCKET_1_NAME} ${STCV_BUCKET_1_MNT_DIR} -o allow_other -o uid=1000,gid=1000,endpoint=eu-central-1,iam_role=auto
    sudo ln -s ${STCV_BUCKET_1_MNT_DIR} /mnt/bucket
else
    echo "Bucket 1 not set!"
fi

if [ ! -z "${STCV_BUCKET_2_NAME}" ]
then
    echo "Mounting bucket ${STCV_BUCKET_2_NAME} to ${STCV_BUCKET_2_MNT_DIR}"
    sudo umount -f ${STCV_BUCKET_2_MNT_DIR}
    sudo -u ec2-user mkdir -p "{$STCV_BUCKET_2_MNT_DIR}"
    sudo s3fs ${STCV_BUCKET_2_NAME} ${STCV_BUCKET_2_MNT_DIR} -o allow_other -o uid=1000,gid=1000,endpoint=eu-central-1,iam_role=auto
    sudo ln -s ${STCV_BUCKET_2_MNT_DIR} /mnt/bucket_secondary
else
    echo "Bucket 2 not set!"
fi

#########

echo "Starting MongoDB (dir: ${STCV_MONGODB_DATA_DIR}) on port ${STCV_MONGODB_PORT}"
sudo -u ec2-user mkdir -p ${STCV_MONGODB_DATA_DIR}
sudo mongod --fork --dbpath ${STCV_MONGODB_DATA_DIR} --bind_ip_all --logpath /var/log/mongodb/mongod.log --port ${STCV_MONGODB_PORT}

#########

echo "Starting Nginx"
sudo -E /etc/init.d/nginx restart

echo "Starting PHP"
sudo /etc/init.d/php8.1-fpm stop
sudo -E /usr/sbin/php-fpm8.1 --allow-to-run-as-root

#########

echo "Starting FiftyOne"
export FIFTYONE_DATABASE_URI=mongodb://127.0.0.1:${STCV_MONGODB_PORT}
export FIFTYONE_DEFAULT_DATASET_DIR=${STCV_FIFTYONE_DATA_DIR}
sudo -u ec2-user mkdir -p ${STCV_FIFTYONE_DATA_DIR}
if [ ${STCV_FIFTYONE_1_BUILD} = "True" ]
then
    source /home/ec2-user/.envs/fo_1/bin/activate
    fiftyone app launch --port ${STCV_FIFTYONE_1_PORT} > /dev/null 2>&1 &
    deactivate
else \
    echo "FiftyOne session 1 not installed!" ; \
fi

if [ ${STCV_FIFTYONE_2_BUILD} = "True" ]
then
    source /home/ec2-user/.envs/fo_2/bin/activate
    fiftyone app launch --port ${STCV_FIFTYONE_2_PORT} > /dev/null 2>&1 &
    deactivate
else \
    echo "FiftyOne session 2 not installed!" ; \
fi

if [ ${STCV_FIFTYONE_3_BUILD} = "True" ]
then
    source /home/ec2-user/.envs/fo_3/bin/activate
    fiftyone app launch --port ${STCV_FIFTYONE_3_PORT} > /dev/null 2>&1 &
    deactivate
else \
    echo "FiftyOne session 3 not installed!" ; \
fi

#########

echo "Starting code-server"
code-server > /dev/null 2>&1 &

#########

echo "Starting Label Studio"
export LABEL_STUDIO_PORT=${STCV_LABELSTUDIO_PORT}
export LABEL_STUDIO_HOST=${STCV_INSTANCE_ADDRESS}/proxy/${STCV_LABELSTUDIO_PORT}/
export LABEL_STUDIO_LOCAL_FILES_SERVING_ENABLED=True
export LABEL_STUDIO_LOCAL_FILES_DOCUMENT_ROOT=${STCV_LABELSTUDIO_DATA_DIR}
export LABEL_STUDIO_DATABASE_NAME=${STCV_LABELSTUDIO_SQLITE_PATH}
sudo -u ec2-user mkdir -p ${STCV_LABELSTUDIO_DATA_DIR}
label-studio start --username email@email.com --password password > /dev/null 2>&1 &

echo "Starting TensorBoard"
if [ ${STCV_TENSORBOARD_1_ENABLE} = "True" ]
then
    sudo -u ec2-user mkdir -p ${STCV_TENSORBOARD_1_DATA_DIR}
    tensorboard --logdir=${STCV_TENSORBOARD_1_DATA_DIR} --port ${STCV_TENSORBOARD_1_PORT} > /dev/null 2>&1 &
fi

if [ ${STCV_TENSORBOARD_2_ENABLE} = "True" ]
then
    sudo -u ec2-user mkdir -p ${STCV_TENSORBOARD_2_DATA_DIR}
    tensorboard --logdir=${STCV_TENSORBOARD_2_DATA_DIR} --port ${STCV_TENSORBOARD_2_PORT} > /dev/null 2>&1 &
fi

echo "Starting MLFlow"
if [ ${STCV_MLFLOW_1_ENABLE} = "True" ]
then
    sudo -u ec2-user mkdir -p ${STCV_MLFLOW_1_DATA_DIR}
    mlflow server --port ${STCV_MLFLOW_1_PORT} --backend-store-uri file://${STCV_MLFLOW_1_DATA_DIR} > /dev/null 2>&1 &
fi

if [ ${STCV_MLFLOW_2_ENABLE} = "True" ]
then
    sudo -u ec2-user mkdir -p ${STCV_MLFLOW_2_DATA_DIR}
    mlflow server --port ${STCV_MLFLOW_2_PORT} --backend-store-uri file://${STCV_MLFLOW_2_DATA_DIR} > /dev/null 2>&1 &
fi

STCV_PERSISTED_CONDA_DIR=${STCV_DIR}/persisted_conda_data_dir
echo "Adding ${STCV_PERSISTED_CONDA_DIR} to list of conda env locations"
rm -rf /home/ec2-user/.condarc
cat << EOF >> /home/ec2-user/.condarc
envs_dirs:
  - ${STCV_PERSISTED_CONDA_DIR}
  - /opt/conda/envs
EOF

bash