## Unofficial Dockerfile for 3D Gaussian Splatting for Real-Time Radiance Field Rendering
## Bernhard Kerbl, Georgios Kopanas, Thomas Leimkühler, George Drettakis
## https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/

# First stage: Setup and build
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel as builder

ENV DEBIAN_FRONTEND=noninteractive

# Update and install tzdata separately
RUN apt update && apt install -y tzdata 

# Install necessary packages
RUN apt install -y git \
    libglew-dev libassimp-dev libboost-all-dev libgtk-3-dev libopencv-dev libglfw3-dev \
    libavdevice-dev libavcodec-dev libeigen3-dev libxxf86vm-dev libembree-dev \
    && apt clean && apt install -y wget && rm -rf /var/lib/apt/lists/*

# Create a workspace directory and clone the repository
WORKDIR /workspace
RUN git clone https://gitlab-int.nlr.nl/dang/feature-3dgs.git --recursive

# Create a Conda environment
WORKDIR /workspace/feature-3dgs/src

RUN /opt/conda/bin/conda init
ENV PATH="/opt/conda/bin:$PATH"
ENV TORCH_CUDA_ARCH_LIST="3.5;5.0;6.0;6.1;7.0;7.5;8.0;8.6+PTX"

RUN conda env create --file environment.yml

SHELL ["conda", "run", "-n", "feature_3dgs", "/bin/bash", "-c"]

RUN pip install -r encoders/lseg_encoder/requirements.txt \
    && pip install -e encoders/sam_encoder \
    && pip install opencv-python pycocotools matplotlib onnxruntime onnx

# Tweak the CMake file for matching the existing OpenCV version. Fix the naming of FindEmbree.cmake
WORKDIR /workspace
RUN git clone https://github.com/RongLiu-Leo/Gaussian-Splatting-Monitor.git
WORKDIR /workspace/Gaussian-Splatting-Monitor/SIBR_viewers/cmake/linux
RUN sed -i 's/find_package(OpenCV 4\.5 REQUIRED)/find_package(OpenCV 4.2 REQUIRED)/g' dependencies.cmake \
    && sed -i 's/find_package(embree 3\.0 )/find_package(EMBREE)/g' dependencies.cmake \
    && mv /workspace/Gaussian-Splatting-Monitor/SIBR_viewers/cmake/linux/Modules/FindEmbree.cmake /workspace/Gaussian-Splatting-Monitor/SIBR_viewers/cmake/linux/Modules/FindEMBREE.cmake

# Fix the naming of the embree library in the rayscaster's cmake
RUN sed -i 's/\bembree\b/embree3/g' /workspace/Gaussian-Splatting-Monitor/SIBR_viewers/src/core/raycaster/CMakeLists.txt

# Ready to build the viewer now.
WORKDIR /workspace/Gaussian-Splatting-Monitor/SIBR_viewers 
RUN cmake -Bbuild . -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j24 --target install

# Second stage
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y tzdata vim x11-apps xauth

COPY --from=builder /opt/conda /opt/conda
COPY --from=builder /usr/bin /usr/bin
COPY --from=builder /usr/lib /usr/lib
COPY --from=builder /usr/include /usr/include
COPY --from=builder /usr/share /usr/share
COPY --from=builder /workspace/Gaussian-Splatting-Monitor/SIBR_viewers   /workspace/SIBR_viewers 

WORKDIR /workspace/feature-3dgs

RUN /opt/conda/bin/conda init
ENV PATH="/opt/conda/bin:$PATH"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "bash" ]
