#!/bin/bash
source /opt/conda/etc/profile.d/conda.sh
conda activate feature_3dgs
pip install git+https://github.com/nerfstudio-project/gsplat.git@v0.1.10
echo "Activated environment: $(conda info --envs | grep \* | awk '{print $1}')"
exec "$@"