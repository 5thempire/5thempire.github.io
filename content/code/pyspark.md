---
title: "PySpark"
draft: false
description: PySpark is a unified analytics engine, this meant to be a platform for development and testing.
---

![Docker Cloud Automated build](https://img.shields.io/docker/cloud/automated/5thempire/pyspark.svg) 
![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/5thempire/pyspark.svg)
![GitHub](https://img.shields.io/github/license/5thempire/pyspark.svg)

PySpark is a unified analytics engine. For documentation you should check [Spark](https://spark.apache.org/) and [PySpark](https://spark.apache.org/docs/2.4.3/api/python/index.html).

This meant to be a platform for **development** and **testing**. 

**PySpark** version **2.4.3**

## How to use this image

### Start a pyspark instance

```bash
docker run -ti 5thempire/pyspark:latest spark-submit /opt/pyspark/pi.py   
```

### ...via `docker-compose`

Example `docker-compose.yml` for `pyspark`

```yml
version: '3.4'

services:
  spark:
    image: 5thempire/pyspark:latest
    container_name: spark
    stdin_open: true
    tty: true
    volumes:
      - ./code:/opt/pyspark
    ports:
      - "8080:8080"
      - "8888:8888"
```

## How to use the Makefile

The Makefile is meant to automate with ease the typical tasks in the project.

To **set it up**, you should run

```bash
make setup
```

For a **pi sample**, you should run

```bash
make pi-sample
```

To explore **pdb**, run the following 

```bash
make pi-debug
```

## Samples

All the samples are based upon [pi.py](https://github.com/apache/spark/blob/master/examples/src/main/python/pi.py).
