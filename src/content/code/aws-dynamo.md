---
title: "Amazon DynamoDB"
description: "A python approach on Amazon DynamoDB"
draft: false
toc: false
---

Python approach on how to interact with Amazon DynamoDB. Check [https://github.com/5thempire/aws-dynamodb](https://github.com/5thempire/aws-dynamodb) for the complete source code. The requirements are:

* [boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/dynamodb.html)
* [DynamoDB docker](https://hub.docker.com/r/amazon/dynamodb-local/)
* [Python](https://www.python.org/)

## Schema Definition

### Key-Value Schema

A table schema can just be the definition of the index, however this configuration is only recommended for when the **IndexKey** is the only index we want to search for.

```python
SIMPLE_SCHEMA_TABLE_NAME = 'SimpleSchemaTableName'
SIMPLE_SCHEMA_KEY = 'IndexKey'
SIMPLE_SCHEMA_VALUE = 'Value'
SIMPLE_SCHEMA = {
    'TableName': SIMPLE_SCHEMA_TABLE_NAME,
    'AttributeDefinitions': [
        {
            'AttributeName': SIMPLE_SCHEMA_KEY,
            'AttributeType': 'S'
        }
    ],
    'KeySchema': [
        {
            'AttributeName': SIMPLE_SCHEMA_KEY,
            'KeyType': 'HASH'
        }
    ],
    'ProvisionedThroughput':{
        'ReadCapacityUnits': 10,
        'WriteCapacityUnits': 10
    }
}
```

### Complex Schema

The following schema has two indexes, **AttributeOneKey** and **AttributeTwoKey**. Another important thing is the introduction of the field [**ProjectionType**](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Projection.html), which defines what is included in the response.

```python
COMPLEX_SCHEMA_TABLE_NAME = 'ComplexSchemaTableName'
COMPLEX_SCHEMA_KEY_ONE = 'AttributeOneKey'
COMPLEX_SCHEMA_KEY_TWO = 'AttributeTwoKey'
COMPLEX_SCHEMA_KEY_THREE = 'AttributeThreeKey'
COMPLEX_SCHEMA_INDEX_TWO = 'AttributeTwoIndexName'
COMPLEX_SCHEMA = {
    'TableName': COMPLEX_SCHEMA_TABLE_NAME,
    'AttributeDefinitions': [
        {
            'AttributeName': COMPLEX_SCHEMA_KEY_ONE,
            'AttributeType': 'S'
        },
        {
            'AttributeName': COMPLEX_SCHEMA_KEY_TWO,
            'AttributeType': 'S'
        }
        ],
    'KeySchema': [
        {
            'AttributeName': COMPLEX_SCHEMA_KEY_ONE,
            'KeyType': 'HASH'
        }
    ],
    'ProvisionedThroughput':{
        'ReadCapacityUnits': 10,
        'WriteCapacityUnits': 10
    },
    'GlobalSecondaryIndexes' : [{
      'IndexName' : COMPLEX_SCHEMA_INDEX_TWO,
      'KeySchema' : [
        {
          'AttributeName' : COMPLEX_SCHEMA_KEY_TWO,
          'KeyType' : 'HASH'
        }
      ],
      'Projection' : {
        'ProjectionType' : 'ALL'
      },
      'ProvisionedThroughput' : {
        'ReadCapacityUnits' : 10,
        'WriteCapacityUnits' : 10
      }
    }],
}
```

## Python classes

### DynamoGeneralClass

A general class with some base actions.

```python
import sys
from abc import abstractmethod

import boto3


class DynamoGeneralClass:

    def __init__(self, conf):
        self.conf = conf

        try:
            self.dynamodb = boto3.client('dynamodb', **conf)
        except Exception as err:
            print("{} - {}".format(__name__, err))
            sys.exit(1)

    def create_table(self, table_schema, table_name):
        self.table_name = table_name
        try:
            self.dynamodb.create_table(**table_schema)
        except Exception as err:
            print("{} - already exists - {}".format(table_name, err))
        finally:
            # Wait for the table to exist before exiting
            waiter = self.dynamodb.get_waiter('table_exists')
            waiter.wait(TableName=table_name)

    def get_table(self, table_name):
        dyndb = boto3.resource('dynamodb', **self.conf)
        return dyndb.Table(table_name)

    def list_all(self):
        """
        For TESTING puposes ONLY, should not be used in
        production
        """
        return self.dynamodb.scan(TableName=self.table_name)

    @abstractmethod
    def get_params(self, key):
        pass

    @abstractmethod
    def put_params(self, key, data):
        pass

    @abstractmethod
    def update_params(self, key, data):
        pass

    def get(self, key):
        """
        Get from DynamoDB
        """
        params = self.get_params(key)
        response = self.dynamodb.get_item(**params)
        return response

    def put(self, key, data):
        """
        Write to DynamoDB
        """
        params = self.put_params(key, data)
        self.dynamodb.put_item(**params)

    def update(self, key, data):
        """
        Update to DynamoDB
        """
        params = self.update_params(key, data)
        self.dynamodb.update_item(**params)

    def exists(self, key):
        """
        Returns a boolean depending
        on the existence of the key
        """
        data = self.get(key)
        return True if 'Item' in data else False
```

### SimpleTableClass

The next class will inherit from the **DynamoGeneralClass** to connect manipulate the table **SimpleSchemaTableName**.

```python
from dyn_base import DynamoGeneralClass
from schema import SIMPLE_SCHEMA,SIMPLE_SCHEMA_TABLE_NAME, SIMPLE_SCHEMA_KEY, SIMPLE_SCHEMA_VALUE


class SimpleTableClass(DynamoGeneralClass):

    def get_params(self, key):
        params = {
            'TableName': SIMPLE_SCHEMA_TABLE_NAME,
            'Key': {
                SIMPLE_SCHEMA_KEY: {"S": key}
            }
        }
        return params

    def put_params(self, key, data):
        params = {
            'TableName': SIMPLE_SCHEMA_TABLE_NAME,
            'Item': {
                SIMPLE_SCHEMA_KEY: {"S": key},
            }
        }
        params['Item'].update(data)
        return params

    def set_value(self, key, value):
        params = {
            SIMPLE_SCHEMA_VALUE: {'S': value}
        }
        self.put(key, params)
```

### ComplexTableClass

The next class will inherit from the **DynamoGeneralClass** to connect manipulate the table **ComplexSchemaTableName**.

```python
from datetime import datetime

from dyn_base import DynamoGeneralClass
from schema import (COMPLEX_SCHEMA, COMPLEX_SCHEMA_INDEX_TWO, COMPLEX_SCHEMA_KEY_ONE, COMPLEX_SCHEMA_KEY_THREE,
                    COMPLEX_SCHEMA_KEY_TWO, COMPLEX_SCHEMA_TABLE_NAME)

GREEN = 'green'
RED = 'red'


class ComplexTableClass(DynamoGeneralClass):

    def get_params(self, key):
        params = {
            'TableName': COMPLEX_SCHEMA_TABLE_NAME,
            'Key': {
                COMPLEX_SCHEMA_KEY_ONE: {"S": key}
            }
        }
        return params

    def put_params(self, key, data):
        params = {
            'TableName': COMPLEX_SCHEMA_TABLE_NAME,
            'Item': {
                COMPLEX_SCHEMA_KEY_ONE: {"S": key},
            }
        }
        params['Item'].update(data)
        return params

    def update_params(self, key, value, timestamp):
        params = {
            'ExpressionAttributeNames': {
                '#LU': COMPLEX_SCHEMA_KEY_THREE,
                '#S': COMPLEX_SCHEMA_KEY_TWO
            },
            'ExpressionAttributeValues': {
                ':lu': {
                    'S': timestamp
                },
                ':s': {
                    'S': value
                }
            },
            'Key': {
                COMPLEX_SCHEMA_KEY_ONE: {"S": key}
            },
            'ReturnValues': 'UPDATED_NEW',
            'TableName': COMPLEX_SCHEMA_TABLE_NAME,
            'UpdateExpression': 'SET #LU = :lu, #S = :s'
        }
        return params

    def filter_by_key_one(self, key, status):
        """
        Filters all entries by key one and key two
        """
        response = self.dynamodb.query(TableName=COMPLEX_SCHEMA_TABLE_NAME,
                                       KeyConditionExpression="{} = :key".format(COMPLEX_SCHEMA_KEY_ONE),
                                       FilterExpression="#S = :status",
                                       ExpressionAttributeValues={":status": {"S": status},
                                                                  ":key": {"S": key}},
                                       ExpressionAttributeNames={"#S": COMPLEX_SCHEMA_KEY_TWO})
        return response

    def filter_by_key_two(self, status):
        """
        Filters all entries by key two
        """
        response = self.dynamodb.query(TableName=COMPLEX_SCHEMA_TABLE_NAME,
                                       IndexName=COMPLEX_SCHEMA_INDEX_TWO,
                                       KeyConditionExpression="#S = :status",
                                       ExpressionAttributeValues={":status": {"S": status}},
                                       ExpressionAttributeNames={"#S": COMPLEX_SCHEMA_KEY_TWO})
        return response

    def update(self, key, status):
        """
        Update to DynamoDB
        """
        timestamp = datetime.utcnow().strftime('%Y-%m-%d-%H-%M')
        params = self.update_params(key, status, timestamp)

        self.dynamodb.update_item(**params)
```

## Amazon DynamoDB Docker

To test the implementation use the Amazon DynamoDB docker image.

```bash
docker run -p 8000:8000 amazon/dynamodb-local
```

Set Amazon DynamoDB configuration as:

```python
aws_conf = {
    'aws_access_key_id': 'dummy_key',
    'aws_secret_access_key': 'dummy_secret',
    'region_name': 'dummy_region',
    'endpoint_url': 'http://localhost:8000'
    }
```
