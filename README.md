#NyaruDB

Kelp http://kelp.phate.org/ <br/>
[MIT License][mit]
[MIT]: http://www.opensource.org/licenses/mit-license.php


NyaruDB is a lite NoSQL database in Objective-C. It could be run on iOS.  
It is a key-document NoSQL database. You could search data by a field of document.



##Collection
Collection is like Table of sql database.



##Schema
Schema of NyaruDB is not like Schema of sql database.

When you want to search data by a field, you should create a schema. If you want to search data by 'email', you should create a 'email' schema before search.



##Document
Document is data in the Collection.

`Insert Data`: the datatype of document is NSDictionary.<br/>
`Get Data`: the datatype of document is NSMutableDictionary.

In the document, there is a member named 'key'. Key is unique and datatype is NSString.
If the document is no 'key' when inserting, it will be automatically generated.

+ Normal Field Datatype: `NSNull`, `NSNumber (true: 1, false: 0)`, `NSDate`, `NSString`, `NSArray`, `NSDictionary`
+ Schema Datatype: `NSNull`, `NSNumber (true: 1, false: 0)`, `NSDate`, `NSString`



##Create Collection
```objective-c
NyaruDB *db = [NyaruDB sharedInstance];
NyaruCollection *collectioin = [db createCollection:@"collectionName"];
```


##Create Schema
```objective-c
NyaruDB *db = [NyaruDB sharedInstance];

NyaruCollection *collection = [db collectionForName:@"collectionName"];
[collection createSchema:@"email"];
[collection createSchema:@"number"];
```


##Insert Data
```objective-c
NyaruDB *db = [NyaruDB sharedInstance];

NyaruCollection *collection = [db collectionForName:@"collectionName"];
NSDictionary *document = @{ @"email": @"kelp@phate.org",
    @"name": @"Kelp",
    @"phone": @"0123456789",
    @"date": [NSDate date],
    @"text": @"(」・ω・)」うー！(／・ω・)／にゃー！",
    @"number": @100 };
[collection insertDocumentWithDictionary:document];
```


##Query
```objective-c
NyaruDB *db = [NyaruDB sharedInstance];

NyaruCollection *collection = [db collectionForName:@"collectionName"];
NSArray *query = @[[NyaruQuery queryWithSchemaName:@"email" operation:NyaruQueryEqual value:@"kelp@phate.org"]];
NSArray *documents = [collection documentsForNyaruQueries:query];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```



##Attention
+ limit of name of field is 255
+ limit of datas is 4 byte 4,294,967,295
+ limit of document size is 4G
+ key is unique and it is NSString
+ key does not provide searching by query
+ key is case sensitive
+ index is case insensitive
+ a field of data should be same data type which is schema
+ sort query allow only one
