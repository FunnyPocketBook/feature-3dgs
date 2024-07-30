FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel as builder

ENV DEBIAN_FRONTEND=noninteractive

# Install packages necessary for SIBR viewer (and some other general packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    libglew-dev \
    libassimp-dev \
    libboost-all-dev \
    libgtk-3-dev \
    libopencv-dev \
    libglfw3-dev \
    libavdevice-dev \
    libavcodec-dev \
    libeigen3-dev \
    libxxf86vm-dev \
    libembree-dev \
    wget \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
RUN git clone https://gitlab-int.nlr.nl/dang/feature-3dgs.git --recursive

WORKDIR /workspace/feature-3dgs/src

ENV PATH="/opt/conda/bin:$PATH"
ENV TORCH_CUDA_ARCH_LIST="3.5;5.0;6.0;6.1;7.0;7.5;8.0;8.6+PTX"

# Install packages needed for 2D foundation models
RUN conda env create --file environment.yml \
    && conda run -n feature_3dgs pip install -r encoders/lseg_encoder/requirements.txt \
    && conda run -n feature_3dgs pip install -e encoders/sam_encoder \
    && conda run -n feature_3dgs pip install opencv-python pycocotools matplotlib onnxruntime onnx

# Compile SIBR viewers from source. Doesn't use the one from Feature 3DGS, since the required binaries are missing there.
WORKDIR /workspace
RUN git clone https://github.com/RongLiu-Leo/Gaussian-Splatting-Monitor.git

# Replace requirements with compatible ones
RUN sed -i 's/find_package(OpenCV 4\.5 REQUIRED)/find_package(OpenCV 4.2 REQUIRED)/g; s/find_package(embree 3\.0 )/find_package(EMBREE)/g' /workspace/Gaussian-Splatting-Monitor/SIBR_viewers/cmake/linux/dependencies.cmake \
    && mv /workspace/Gaussian-Splatting-Monitor/SIBR_viewers/cmake/linux/Modules/FindEmbree.cmake /workspace/Gaussian-Splatting-Monitor/SIBR_viewers/cmake/linux/Modules/FindEMBREE.cmake \
    && sed -i 's/\bembree\b/embree3/g' /workspace/Gaussian-Splatting-Monitor/SIBR_viewers/src/core/raycaster/CMakeLists.txt

WORKDIR /workspace/Gaussian-Splatting-Monitor/SIBR_viewers 
RUN cmake -Bbuild . -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j$(nproc) --target install

# Second stage
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    vim \
    x11-apps \
    xauth \
    libglew-dev \
    libassimp-dev \
    libboost-all-dev \
    libgtk-3-dev \
    libopencv-dev \
    libglfw3-dev \
    libavdevice-dev \
    libavcodec-dev \
    libeigen3-dev \
    libxxf86vm-dev \
    libembree-dev \
    software-properties-common \
    && add-apt-repository ppa:kisak/kisak-mesa \
    && apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/conda /opt/conda
COPY --from=builder /workspace/Gaussian-Splatting-Monitor/SIBR_viewers /workspace/SIBR_viewers 

WORKDIR /workspace/feature-3dgs

ENV PATH="/opt/conda/bin:$PATH"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]