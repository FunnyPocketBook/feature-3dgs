## Unofficial Dockerfile for 3D Gaussian Splatting for Real-Time Radiance Field Rendering
## Bernhard Kerbl, Georgios Kopanas, Thomas Leimkühler, George Drettakis
## https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/

# Use the base image with PyTorch and CUDA support
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel


# NOTE:
# Building the libraries for this repository requires cuda *DURING BUILD PHASE*, therefore:
# - The default-runtime for container should be set to "nvidia" in the deamon.json file. See this: https://github.com/NVIDIA/nvidia-docker/issues/1033
# - For the above to work, the nvidia-container-runtime should be installed in your host. Tested with version 1.14.0-rc.2
# - Make sure NVIDIA's drivers are updated in the host machine. Tested with 525.125.06

ENV DEBIAN_FRONTEND=noninteractive

# Update and install tzdata separately
RUN apt update && apt install -y tzdata 

# Install necessary packages
RUN apt install -y git && \
    apt install -y libglew-dev libassimp-dev libboost-all-dev libgtk-3-dev libopencv-dev libglfw3-dev libavdevice-dev libavcodec-dev libeigen3-dev libxxf86vm-dev libembree-dev && \
    apt clean && apt install wget && rm -rf /var/lib/apt/lists/*

# Create a workspace directory and clone the repository
WORKDIR /workspace
RUN git clone https://gitlab-int.nlr.nl/dang/feature-3dgs.git --recursive

# Create a Conda environment and activate it
WORKDIR /workspace/feature-3dgs


RUN /opt/conda/bin/conda init

# Update PATH
ENV PATH="/opt/conda/bin:$PATH"

ENV TORCH_CUDA_ARCH_LIST="3.5;5.0;6.0;6.1;7.0;7.5;8.0;8.6+PTX"
# RUN conda env create --file environment.yml && conda init bash && exec bash && conda activate feature_3dgs
RUN conda env create --file environment.yml

SHELL ["conda", "run", "-n", "feature_3dgs", "/bin/bash", "-c"]

RUN pip install -r /workspace/feature-3dgs/encoders/lseg_encoder/requirements.txt
RUN pip install -e /workspace/feature-3dgs/encoders/sam_encoder
RUN pip install opencv-python pycocotools matplotlib onnxruntime onnx

# Tweak the CMake file for matching the existing OpenCV version. Fix the naming of FindEmbree.cmake
WORKDIR /workspace/feature-3dgs/SIBR_viewers/cmake/linux
RUN sed -i 's/find_package(OpenCV 4\.5 REQUIRED)/find_package(OpenCV 4.2 REQUIRED)/g' dependencies.cmake
RUN sed -i 's/find_package(embree 3\.0 )/find_package(EMBREE)/g' dependencies.cmake
RUN mv /workspace/feature-3dgs/SIBR_viewers/cmake/linux/Modules/FindEmbree.cmake /workspace/feature-3dgs/SIBR_viewers/cmake/linux/Modules/FindEMBREE.cmake

# Fix the naming of the embree library in the rayscaster's cmake
# RUN sed -i 's/\bembree\b/embree3/g' /workspace/feature-3dgs/SIBR_viewers/src/core/raycaster/CMakeLists.txt

# Ready to build the viewer now.
WORKDIR /workspace/feature-3dgs/SIBR_viewers 
RUN cmake -Bbuild . -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j24 --target install


RUN apt update && apt install -y vim 
WORKDIR /workspace/feature-3dgs

# ENTRYPOINT ["tail"]
# CMD ["-f","/dev/null"]

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
