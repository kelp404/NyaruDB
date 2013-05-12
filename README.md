#NyaruDB
###＼(・ω・＼)SAN値！(／・ω・)／ピンチ！
> <a href="http://nyaruko.com/" target="_blank">這いよれ！ニャル子さんW</a>  
> 2013年4月7日（日）深夜1:05～からテレビ東京ほかにて放送スタート！  


Kelp https://twitter.com/kelp404  
[MIT License][mit]
[MIT]: http://www.opensource.org/licenses/mit-license.php


NyaruDB is a simple NoSQL database in Objective-C. It could be run on iOS and OS X.  
It is a key-document NoSQL database. You could search data by fields of the document.


##Feature
* More quickly than sqlite.  
NyaruDB use memory cache, <a href="https://developer.apple.com/technologies/mac/core.html#grand-central" target="_blank">GCD</a> and binary tree to optimize performance.
```
NoSQL with SQL:  
NyaruDB: NSDictionary <-- NyaruDB --> File  
sqlite: NSDictionary <-- converter --> SQL <-- sqlite3 function --> File  
```
  　  |  NyaruDB  |  sqlite  
:---------:|:---------:|:---------:
insert 1k documents | 11,000 ms <br/> 500 ms (async) | 36,500 ms
fetch 1k documents | 300 ms <br/> 50 ms (in cache) | 300 ms
search in 1k documents <br/> for 10 times | 12 ms | 40 ms
(this test is on iPhone4)  
<br/>
NyaruDB use GCD to write/read documents, **all accesses would be processed in a same dispatch**.  
Write: process with async GCD.  
Read: process with sync GCD.  
Writing documents to database will be processed in a async dispatch. So your code would not wait for writing documents. CPU will process the next command.  
If next command is reading documents from database, the command will be processed after writing done.  


* Clean query syntax.  
```objective-c
// where type == 1 order by update
NSArray *documents = [[[collection where:@"type" equal:@1] orderBy:@"update"] fetch];
```



---
##Installation
1. **git:**
```
$ git clone git://github.com/kelp404/NyaruDB.git
```

2. **<a href="http://cocoapods.org/" target="_blank">CocoadPods</a>:**  
add `Podfile` in your project path
```
platform :ios
pod 'NyaruDB'
```
```
$ pod install
```



---
##Management Tool
####<a href="https://github.com/kelp404/NyaruDB-Control" target="_blank">NyaruDB Control</a>  
<img src='https://raw.github.com/kelp404/NyaruDB-Control/master/_images/screenshot00.png' witdh='850px' height='503px'/>



---
##Collection
Collection is like Table of sql database.  



##Index
When you want to search data by a field, you should create a index.  
If you want to search data by 'email', you should create a 'email' index before searching.  



##Document
Document is data in the collection.

There is a member named 'key' in the document. Key is unique and datatype is NSString.  
If the document has no 'key' when inserted, it will be automatically generated.  

+ Normal Field Datatype: `NSNull`, `NSNumber`, `NSDate`, `NSString`, `NSArray`, `NSDictionary`  
**(items just allow `NSString`, `NSNumber`, `NSDate` and `NSNull` in the `NSArray`)**  
+ Index Field Datatype: `NSNull`, `NSNumber`, `NSDate`, `NSString`  



---
##Instance
`[NyaruDB instance]` returns a static NyaruDB instance, and database path is `/your-app/Documents/NyaruDB`. This method is for **iOS**.  
`[[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"]` this method is for **OS X**.  
NyaruDB will scan all documents in collections when `[NyaruDB init]`, so do not call `init` too much.  
In OS X, you should handle the static instance by yourself.  


##Create Collection
```objective-c
/* iOS */
NyaruDB *db = [NyaruDB instance];
// /* OS X */
// NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];

NyaruCollection *collectioin = [db collection:@"collectionName"];
```


##Create Index
```objective-c
/* iOS */
NyaruDB *db = [NyaruDB instance];
// /* OS X */
// NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];

NyaruCollection *collection = [db collection:@"collectionName"];
[collection createIndex:@"email"];
[collection createIndex:@"number"];
[collection createIndex:@"date"];
```


##Insert Data
```objective-c
/* iOS */
NyaruDB *db = [NyaruDB instance];
// /* OS X */
// NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];

NyaruCollection *collection = [db collection:@"collectionName"];
NSDictionary *document = @{@"email": @"kelp@phate.org",
    @"name": @"Kelp",
    @"phone": @"0123456789",
    @"date": [NSDate date],
    @"text": @"(」・ω・)」うー！(／・ω・)／にゃー！",
    @"number": @100};
[collection insert:document];
```


##Query    
The field of the document which is `key` or `index` supports search.  
`key` supports `equal`.  
`index` supports `equal`, `notEqual`, `less`, `lessEqual`, `greater`, `greaterEqual` and `like`.  

You could use `and`(Intersection) or `union` to append query.  


```objective-c
// search the document the 'key' is equal to 'IjkhMGIT752091136'
/* iOS */
NyaruDB *db = [NyaruDB instance];
// /* OS X */
// NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];

NyaruCollection *co = [db collection:@"collectionName"];
NSArray *documents = [[co where:@"key" equal:@"IjkhMGIT752091136"] fetch];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```


```objective-c
// search documents the 'date' is greater than now, and sort by date with DESC
/* iOS */
NyaruDB *db = [NyaruDB instance];
// /* OS X */
// NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];

NyaruCollection *co = [db collection:@"collectionName"];
NSDate *date = [NSDate date];
NSArray *documents = [[[co where:@"date" greater:date] orderByDESC:@"date"] fetch];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```


```objective-c
// search documents the 'date' is greater than now, and 'type' is equal to 2
// then sort by date with ASC
/* iOS */
NyaruDB *db = [NyaruDB instance];
// /* OS X */
// NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];

NyaruCollection *co = [db collection:@"collectionName"];
NSDate *date = [NSDate date];
NSArray *documents = [[[[co where:@"date" greater:date] and:@"type" equal:@2] orderBy:@"date"] fetch];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```


```objective-c
// search documents 'type' == 1 or 'type' == 3
/* iOS */
NyaruDB *db = [NyaruDB instance];
// /* OS X */
// NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];

NyaruCollection *co = [db collection:@"collectionName"];
NSArray *documents = [[[co where:@"type" equal:@1] union:@"type" equal:@3] fetch];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```


```objective-c
// count documents 'type' == 1
/* iOS */
NyaruDB *db = [NyaruDB instance];
// /* OS X */
// NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];

NyaruCollection *co = [db collection:@"collectionName"];
NSUInteger count = [[co where:@"type" equal:@1] count];
NSLog(@"%u", count);
```




##Delete Data
```objective-c
// delete data by key
/* iOS */
NyaruDB *db = [NyaruDB instance];
// /* OS X */
// NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];

// create collection
NyaruCollection *co = [db collection:@"collectionName"];
[co createIndex:@"number"];
[co insert:@{@"number" : @100}];
[co insert:@{@"number" : @200}];
[co insert:@{@"number" : @10}];

// remove by query
[[co where:@"number" equal:@10] remove];
// remove all
[[co all] remove];
```



---
##Class
**NyaruDB interface**
```Objective-C
/**
 Get the shared instance for iOS.
 @return NyaruDB shared instance
 */
+ (id)instance;
/**
 Remove all database for iOS.
 if you init database error, maybe need to call this message.
 */
+ (void)reset;


/**
 Init NyaruDB for OS X.
 @param path Database files are in this path.
 @return NyaruDB instance
 */
- (id)initWithPath:(NSString *)path;
/**
 Close all file handles and collections for OS X.
 Before release instance you should invoke this method.
 */
- (void)close;


- (NSArray *)collections;
- (NyaruCollection *)collection:(NSString *)name;

- (void)removeCollection:(NSString *)name;
- (void)removeAllCollections;
```


**NyaruCollection interface**
```Objective-C
#pragma mark - Index
- (NSArray *)allIndexes;
- (void)createIndex:(NSString *)indexName;
- (void)removeIndex:(NSString *)indexName;
- (void)removeAllindexes;

#pragma mark - Document
// insert document
- (NSMutableDictionary *)insert:(NSDictionary *)document;
// remove all documents (directly remove files)
- (void)removeAll;
// waiting for data writing
- (void)waiteForWriting;
// clear cache
- (void)clearCache;

#pragma mark - Query
- (NyaruQuery *)all;
- (NyaruQuery *)where:(NSString *)indexName equal:(id)value;
- (NyaruQuery *)where:(NSString *)indexName notEqual:(id)value;
- (NyaruQuery *)where:(NSString *)indexName less:(id)value;
- (NyaruQuery *)where:(NSString *)indexName lessEqual:(id)value;
- (NyaruQuery *)where:(NSString *)indexName greater:(id)value;
- (NyaruQuery *)where:(NSString *)indexName greaterEqual:(id)value;
- (NyaruQuery *)where:(NSString *)indexName like:(NSString *)value;

#pragma mark - Count
- (NSUInteger)count;
```


**NyaruQuery interface**
```Objective-C
#pragma mark - Intersection
- (NyaruQuery *)and:(NSString *)indexName equal:(id)value;
- (NyaruQuery *)and:(NSString *)indexName notEqual:(id)value;
- (NyaruQuery *)and:(NSString *)indexName less:(id)value;
- (NyaruQuery *)and:(NSString *)indexName lessEqual:(id)value;
- (NyaruQuery *)and:(NSString *)indexName greater:(id)value;
- (NyaruQuery *)and:(NSString *)indexName greaterEqual:(id)value;
- (NyaruQuery *)and:(NSString *)indexName like:(NSString *)value;

#pragma mark - Union
- (NyaruQuery *)union:(NSString *)indexName equal:(id)value;
- (NyaruQuery *)union:(NSString *)indexName notEqual:(id)value;
- (NyaruQuery *)union:(NSString *)indexName less:(id)value;
- (NyaruQuery *)union:(NSString *)indexName lessEqual:(id)value;
- (NyaruQuery *)union:(NSString *)indexName greater:(id)value;
- (NyaruQuery *)union:(NSString *)indexName greaterEqual:(id)value;
- (NyaruQuery *)union:(NSString *)indexName like:(NSString *)value;

#pragma mark - Order By
- (NyaruQuery *)orderBy:(NSString *)indexName;
- (NyaruQuery *)orderByDESC:(NSString *)indexName;

#pragma mark - Count
- (NSUInteger)count;

#pragma mark - Fetch
- (NSArray *)fetch;
- (NSArray *)fetch:(NSUInteger)limit;
- (NSArray *)fetch:(NSUInteger)limit skip:(NSUInteger)skip;

#pragma mark - Remove
- (void)remove;
```


---
##Attention
+ limit length of field name is 255
+ limit of documents is 4,294,967,295
+ limit of document file size is 4G
+ key is unique and it is NSString
+ key only provides `equal` search
+ key is case sensitive
+ index is case insensitive
+ a field of the document should be same data type which is index
+ sort query allow only one


##History
+ 1.3  
file header -> `nyaruko `  
replace JSONKit with NyaruCollection.serialize()

+ 1.2  
file header -> `(」・ω・)」うー！(／・ω・)／にゃー！1\n`  
optimize performance  
new query syntax

+ 1.1  
file header -> `(」・ω・)」うー！(／・ω・)／にゃー！ \n`  
