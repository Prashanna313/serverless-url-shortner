import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('URLShortener')

def lambda_handler(event, context):
    short_id = event['pathParameters']['short_id']
    response = table.get_item(Key={'short_id': short_id})
    if 'Item' in response:
        long_url = response['Item']['long_url']
        return {
            'statusCode': 301,
            'headers': {'Location': long_url}
        }
    return {'statusCode': 404, 'body': 'Not Found'}
