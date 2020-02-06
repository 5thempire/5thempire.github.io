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

## Data model Definition

In these examples two different data models are used, their choice is
meant to illustrate what can be achieved and how it can be operated.

* **Key-Value data model** for domains
* **Document data model** for logs

It's advisable that you look at [**ProvisionedThroughput**](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadWriteCapacityMode.html). It should be properly set, since it depends on the amounts of reads and writes your application performs to DynamoDB.

[**Attribute definitions**](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html) defines the core of the table.

[**Global secondary indexes**](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html) are used to speed up queries on non-key attributes. In a DynamoDB table, each key value must be unique. However, the key values in a global secondary index do not need to be unique. 

It contains a selection of attributes from the base table, but they are organized by a primary key that is different from that of the table. The index key does not need to have any of the key attributes from the table. It doesn't even need to have the same key schema as a table.

* [**ProjectionType**](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Projection.html) defines a set of attributes that are projected into the index. This definition is important when storing documents, since it defines what we retrieve when querying.

    * KEYS_ONLY - Only the index and primary keys are projected into the index.
    * INCLUDE - Only the specified table attributes are projected into the index. The list of projected attributes is in NonKeyAttributes.
    * ALL - All of the table attributes are projected into the index.

### Key-Value data model

In this schema url is the hash key, therefore it's the only element that identifies
the item and the only that can be searched for.

The domain item we're storing has two attributes, the url and the corresponding domain.

```python
TABLE_NAME = 'Domain'
DOMAIN = 'domain'
URL = 'url'
SCHEMA = {
    'TableName': TABLE_NAME,
    'AttributeDefinitions': [
        {
            'AttributeName': URL,
            'AttributeType': 'S'
        }
    ],
    'KeySchema': [
        {
            'AttributeName': URL,
            'KeyType': 'HASH'
        }
    ],
    'ProvisionedThroughput': {
        'ReadCapacityUnits': 10,
        'WriteCapacityUnits': 10
    }
}
```

### Document data model

This model has two hashes or indexes, the timestamp and the status. Besides these attributes we're going to store the log message. Since we want to query both, a global secondary index is set. It's worth mentioning that we could store more attributes than just these, but for the demonstration it's enough.

```python
TABLE_NAME = 'Log'
TIMESTAMP = 'updated_at'
STATUS = 'status'
INDEX_STATUS_KEY = 'Status'
SCHEMA = {
    'TableName': TABLE_NAME,
    'AttributeDefinitions': [
        {
            'AttributeName': TIMESTAMP,
            'AttributeType': 'S'
        },
        {
            'AttributeName': STATUS,
            'AttributeType': 'S'
        }
        ],
    'KeySchema': [
        {
            'AttributeName': TIMESTAMP,
            'KeyType': 'HASH'
        }
    ],
    'ProvisionedThroughput': {
        'ReadCapacityUnits': 10,
        'WriteCapacityUnits': 10
    },
    'GlobalSecondaryIndexes': [{
        'IndexName': INDEX_STATUS_KEY,
        'KeySchema': [{
            'AttributeName': STATUS,
            'KeyType': 'HASH'
        }
        ],
        'Projection': {
            'ProjectionType': 'ALL'
        },
        'ProvisionedThroughput': {
            'ReadCapacityUnits': 10,
            'WriteCapacityUnits': 10
        }
    }],
}
```

## Python classes

### Dynamo base class

This approach has one base class to interact with dynamo, which is not meant to be used on it's own, but to provide a solid base for the table specific definitons.

```python
import sys
from abc import abstractmethod

import boto3


class DynamoBase:

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

    @abstractmethod
    def remove_params(self, key, data):
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

    def remove(self, key):
        """
        Removes a key
        """
        params = self.remove_params(key)
        self.dynamodb.delete_item(**params)
```

### Dynamo domain class

This class overrides the base class by defining what's particular for the domain data model interaction.

```python
from dynamo.base import DynamoBase
from samples.domain.schema import TABLE_NAME, DOMAIN, URL


class DynamoDomain(DynamoBase):

    def get_params(self, key):
        params = {
            'TableName': TABLE_NAME,
            'Key': {
                URL: {"S": key}
            }
        }
        return params

    def put_params(self, key, data):
        params = {
            'TableName': TABLE_NAME,
            'Item': {
                URL: {"S": key},
            }
        }
        params['Item'].update(data)
        return params

    def remove_params(self, key):
        params = {
            'TableName': TABLE_NAME,
            'Key': {
                URL: {"S": key}
            }
        }
        return params

    def set_value(self, key, value):
        params = {
            DOMAIN: {'S': value}
        }
        self.put(key, params)

    def get_domain(self, key):
        data = self.get(key)
        return data['Item'][URL]['S']
```

### Dynamo log class

This class overrides the base class by defining what's particular for the log data model interaction.

```python
from dynamo.base import DynamoBase
from samples.log.schema import TABLE_NAME, TIMESTAMP, STATUS, INDEX_STATUS_KEY


class DynamoLog(DynamoBase):

    def get_params(self, key):
        params = {
            'TableName': TABLE_NAME,
            'Key': {
                TIMESTAMP: {"S": key}
            }
        }
        return params

    def put_params(self, key, data):
        params = {
            'TableName': TABLE_NAME,
            'Item': {
                TIMESTAMP: {"S": key},
            }
        }
        params['Item'].update(data)
        return params

    def update_params(self, timestamp, value):
        params = {
            'ExpressionAttributeNames': {
                '#LU': INDEX_STATUS_KEY,
                '#S': STATUS
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
                TIMESTAMP: {"S": timestamp}
            },
            'ReturnValues': 'UPDATED_NEW',
            'TableName': TABLE_NAME,
            'UpdateExpression': 'SET #LU = :lu, #S = :s'
        }
        return params

    def filter_by_timestamp_status(self, timestamp, status):
        """
        Filters all entries by timestamp and status
        """
        response = self.dynamodb.query(TableName=TABLE_NAME,
                                       KeyConditionExpression=f"{TIMESTAMP} = :updated_at",
                                       FilterExpression="#S = :status",
                                       ExpressionAttributeValues={":status": {"S": status},
                                                                  ":updated_at": {"S": timestamp}},
                                       ExpressionAttributeNames={"#S": STATUS})
        return response

    def filter_by_status(self, status):
        """
        Filters all entries by key two
        """
        response = self.dynamodb.query(TableName=TABLE_NAME,
                                       IndexName=INDEX_STATUS_KEY,
                                       KeyConditionExpression="#S = :status",
                                       ExpressionAttributeValues={":status": {"S": status}},
                                       ExpressionAttributeNames={"#S": STATUS})
        return response

    def update(self, timestamp, status):
        """
        Update to DynamoDB
        """
        params = self.update_params(timestamp, status)

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
