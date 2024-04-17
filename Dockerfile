ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG TORCH
ARG PYTHON_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash

# Set the working directory
WORKDIR /

# Create workspace directory
RUN mkdir /workspace

# Update, upgrade, install packages and clean up
RUN apt-get update --yes && \
    apt-get upgrade --yes && \
    apt install --yes --no-install-recommends git wget curl bash libgl1 software-properties-common openssh-server nginx && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt install "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" -y --no-install-recommends && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen


# Set up Python and pip
RUN ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    rm /usr/bin/python3 && \
    ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python get-pip.py


RUN pip install --upgrade --no-cache-dir pip
RUN pip install --upgrade --no-cache-dir ${TORCH}
RUN pip install --upgrade --no-cache-dir jupyterlab ipywidgets jupyter-archive jupyter_contrib_nbextensions

# Set up Jupyter Notebook
RUN pip install notebook==6.5.5
RUN jupyter contrib nbextension install --user && \
    jupyter nbextension enable --py widgetsnbextension

# Set up Colmap
# ARG COLMAP_GIT_COMMIT=3.8
# ENV QT_XCB_GL_INTEGRATION=xcb_egl

# RUN apt-get update && \
#     apt-get install -y --no-install-recommends --no-install-suggests \
#         git \
#         cmake \
#         ninja-build \
#         build-essential \
#         libboost-program-options-dev \
#         libboost-filesystem-dev \
#         libboost-graph-dev \
#         libboost-system-dev \
#         libeigen3-dev \
#         libflann-dev \
#         libfreeimage-dev \
#         libmetis-dev \
#         libgoogle-glog-dev \
#         libgtest-dev \
#         libsqlite3-dev \
#         libglew-dev \
#         qtbase5-dev \
#         libqt5opengl5-dev \
#         libcgal-dev \
#         libceres-dev

# RUN git clone https://github.com/colmap/colmap.git
# RUN cd colmap && \
#     git fetch https://github.com/colmap/colmap.git ${COLMAP_GIT_COMMIT} && \
#     git checkout FETCH_HEAD && \
#     mkdir build && \
#     cd build && \
#     cmake .. -GNinja -DCMAKE_CUDA_ARCHITECTURES="70;72;75;80;86" \
#         -DCMAKE_INSTALL_PREFIX=/colmap_installed && \
#     ninja install
# RUN cd ../../ && rm -rf colmap


# Set up Gaussian Splatting
RUN pip install --upgrade --no-cache-dir plyfile
RUN pip install --upgrade --no-cache-dir tqdm
RUN git clone https://github.com/graphdeco-inria/gaussian-splatting --recursive
RUN cd gaussian-splatting && pip install --upgrade --no-cache-dir submodules/diff-gaussian-rasterization && \
    pip install --upgrade --no-cache-dir submodules/simple-knn && \
    cd ..

# Remove existing SSH host keys
RUN rm -f /etc/ssh/ssh_host_*

# NGINX Proxy
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html

# Copy the README.md
COPY README.md /usr/share/nginx/html/README.md

# Start Scripts
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# Welcome Message
COPY --from=logo runpod.txt /etc/runpod.txt
RUN echo 'cat /etc/runpod.txt' >> /root/.bashrc
RUN echo 'echo -e "\nFor detailed documentation and guides, please visit:\n\033[1;34mhttps://docs.runpod.io/\033[0m and \033[1;34mhttps://blog.runpod.io/\033[0m\n\n"' >> /root/.bashrc

# Set the default command for the container
CMD [ "/start.sh" ]
