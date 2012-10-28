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

When you want to search data by a field, you should create a schema. If you want to search data by 'email', you should create a 'email' schema before searching.



##Document
Document is data in the Collection.

`Insert Data`: the datatype of document is NSDictionary.<br/>
`Get Data`: the datatype of document is NSMutableDictionary.

In the document, there is a member named 'key'. Key is unique and datatype is NSString.
If the document is no 'key' when inserting, it will be automatically generated.

+ Normal Field Datatype: `NSNull`, `NSNumber`, `NSDate`, `NSString`, `NSArray`, `NSDictionary`
+ Schema Datatype: `NSNull`, `NSNumber`, `NSDate`, `NSString`



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
[collection createSchema:@"date"];
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
NyaruQueryOperation
    NyaruQueryEqual = 0,
    NyaruQueryLess = 1,
    NyaruQueryLessEqual = 2,
    NyaruQueryGreater = 3,
    NyaruQueryGreaterEqual = 4,
    NyaruQueryLike = 5,		// only for NSString
    NyaruQueryBeginningOf = 6,	// only for NSString
    NyaruQueryEndOf = 7,	// only for NSString
    NyaruQueryOrderASC = 8,
    NyaruQueryOrderDESC = 9,
    NyaruQueryUnequal = 10
```

```objective-c
// search document the 'email' is equal to 'kelp@phate.org'
NyaruDB *db = [NyaruDB sharedInstance];

NyaruCollection *collection = [db collectionForName:@"collectionName"];
NSArray *query = @[[NyaruQuery queryWithSchemaName:@"email" operation:NyaruQueryEqual value:@"kelp@phate.org"]];
NSArray *documents = [collection documentsForNyaruQueries:query];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```

```objective-c
// search document the 'date' is greater than now, and sort by date with DESC
NyaruDB *db = [NyaruDB sharedInstance];

NyaruCollection *collection = [db collectionForName:@"collectionName"];
NSDate *date = [NSDate new];
NSArray *query = @[[NyaruQuery queryWithSchemaName:@"date" operation:NyaruQueryGreater value:date],
                   [NyaruQuery queryWithSchemaName:@"date" operation:NyaruQueryOrderDESC]];
NSArray *documents = [collection documentsForNyaruQueries:query];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```

```objective-c
// search document the 'number' is greater than 100 or equal to 100, or 'email' is equal to 'kelp@phate.org'
// then sort by date with DESC
NyaruDB *db = [NyaruDB sharedInstance];

NyaruCollection *collection = [db collectionForName:@"collectionName"];
NSDate *date = [NSDate new];
NSArray *query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryGreaterEqual value:@100],
                   [NyaruQuery queryWithSchemaName:@"email" operation:NyaruQueryOrderDESC value:@"kelp@phate.org" appendWith:NYOr],
                   [NyaruQuery queryWithSchemaName:@"date" operation:NyaruQueryOrderDESC]];
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
