FROM python:3.11-slim

# Install GDAL dependencies and git
RUN apt-get update && apt-get install -y \
    gdal-bin \
    libgdal-dev \
    gcc \
    python3-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set GDAL include paths
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal
ENV GDAL_VERSION=3.7.0

# Set working directory
WORKDIR /app

# Clone your Git repo (adjust URL and branch)
ARG GIT_TOKEN
ARG GIT_REPO=github.com/vparmar-art/LastMinute.git

RUN git clone --depth 1 https://$GIT_TOKEN@$GIT_REPO /app-src
RUN cp -r /app-src/backend/* /app/
RUN rm -rf /app-src

# Install Python dependencies
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# Run Django app
CMD ["gunicorn", "yourproject.wsgi:application", "--bind", "0.0.0.0:8000"]