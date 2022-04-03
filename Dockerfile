# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
ARG OWNER=jupyter
ARG BASE_CONTAINER=$OWNER/minimal-notebook
FROM $BASE_CONTAINER
ENV GRANT_SUDO=yes
LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

# Fix: https://github.com/hadolint/hadolint/wiki/DL4006
# Fix: https://github.com/koalaman/shellcheck/wiki/SC3014
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    # for cython: https://cython.readthedocs.io/en/latest/src/quickstart/install.html
    build-essential \
    # for latex labels
    cm-super \
    dvipng \
    # for matplotlib anim
    ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER ${NB_UID}

# Install Python 3 packages
RUN mamba install --quiet --yes \
    'altair' \
    'beautifulsoup4' \
    'bokeh' \
    'bottleneck' \
    'cloudpickle' \
    'conda-forge::blas=*=openblas' \
    'cython' \
    'dask' \
    'dill' \
    'h5py' \
    'ipympl'\
    'ipywidgets' \
    'matplotlib-base' \
    'numba' \
    'numexpr' \
    'pandas' \
    'patsy' \
    'protobuf' \
    'pytables' \
    'scikit-image' \
    'scikit-learn' \
    'scipy' \
    'seaborn' \
    'sqlalchemy' \
    'statsmodels' \
    'sympy' \
    'widgetsnbextension'\
    'xlrd' && \
    mamba clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

# Install facets which does not have a pip or conda package at the moment
WORKDIR /tmp
RUN git clone https://github.com/PAIR-code/facets.git && \
    jupyter nbextension install facets/facets-dist/ --sys-prefix && \
    rm -rf /tmp/facets && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME="/home/${NB_USER}/.cache/"

RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions "/home/${NB_USER}"

USER ${NB_UID}

WORKDIR "${HOME}"


RUN python3 -m pip install pip install opencv-contrib-python
USER root
RUN sudo apt-get -y update
RUN sudo apt install -y caffe-cpu
RUN sudo apt-get install -y libgflags-dev gnupg dirmngr
RUN sudo apt-get install -y build-essential libssl-dev lsb-core software-properties-common
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
RUN sudo apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main"

# OPENPOSE
RUN sudo apt-get update -y && \
    sudo apt-get upgrade -y && \
    sudo apt-get install -y \
        g++ libboost-all-dev \
        caffe-cpu libcaffe-cpu-dev \
        wget apt-utils lsb-core cmake git make \
        libopencv-dev \
        protobuf-compiler \
        libprotobuf-dev \
        libgoogle-glog-dev \
        libboost-all-dev \
        hdf5-tools \
        libhdf5-dev \
        libatlas-base-dev
#replace cmake as old version has CUDA variable bugs
RUN wget https://github.com/Kitware/CMake/releases/download/v3.16.0/cmake-3.16.0-Linux-x86_64.tar.gz && \
tar xzf cmake-3.16.0-Linux-x86_64.tar.gz -C /opt && \
rm cmake-3.16.0-Linux-x86_64.tar.gz
ENV PATH="/opt/cmake-3.16.0-Linux-x86_64/bin:${PATH}"

WORKDIR ${HOME}
RUN git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose.git

WORKDIR ${HOME}/openpose/scripts/build
RUN sed -i 's/\<sudo -H\>//g' install_deps.sh; \
    sed -i 's/\<sudo\>//g' install_deps.sh; \
    sync; sleep 1;

WORKDIR ${HOME}/openpose/build

RUN cmake -DBUILD_PYTHON=ON -DGPU_MODE=CPU_ONLY -DUSE_MKL=OFF \
    -DBUILD_CAFFE=OFF \
    -DCaffe_LIBS=/usr/lib/x86_64-linux-gnu/libcaffe.so \
    -DDOWNLOAD_BODY_25_MODEL:Bool=ON \
    -DCaffe_INCLUDE_DIRS=/usr/include/caffe ..
# # Downloads all available models. You can reduce image size by being more selective.
# RUN cmake -DGPU_MODE:String=CPU_ONLY \
#           -DOWNLOAD_BODY_25_MODEL:Bool=ON \
#           -DDOWNLOAD_BODY_MPI_MODEL:Bool=ON \
#           -DDOWNLOAD_BODY_COCO_MODEL:Bool=ON \
#           -DDOWNLOAD_FACE_MODEL:Bool=ON \
#           -DDOWNLOAD_HAND_MODEL:Bool=ON \
#           -DUSE_MKL:Bool=OFF \
#           ..
# RUN cmake -DBUILD_PYTHON=ON .. && make -j `nproc`
# # you may find that you need to adjust this.
RUN make clean && make all -j `nproc`

RUN cd ${HOME}/openpose/build/python/openpose && make install
ENV PYTHONPATH=/openpose/build/python/openpose
ENV LD_LIBRARY_PATH=/openpose/build/python/openpose
RUN cp ${HOME}/openpose/build/python/openpose/pyopenpose.cpython-39-x86_64-linux-gnu.so /opt/conda/lib/python3.9/site-packages/
RUN cd /opt/conda/lib/python3.9/site-packages/ && ln -s pyopenpose.cpython-39-x86_64-linux-gnu.so pyopenpose


USER ${NB_UID}
WORKDIR ${HOME}/work
EXPOSE 8888:8888