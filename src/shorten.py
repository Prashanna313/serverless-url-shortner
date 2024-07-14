import boto3
import json
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('URLShortener')

def lambda_handler(event, context):
    body = json.loads(event['body'])
    long_url = body['url']
    short_id = str(uuid.uuid4())[:8]
    table.put_item(Item={'short_id': short_id, 'long_url': long_url})
    return {
        'statusCode': 200,
        'body': json.dumps({'short_url': f"https://{event['headers']['Host']}/{short_id}"})
    }
