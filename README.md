#NyaruDB  [![Build Status](https://secure.travis-ci.org/kelp404/NyaruDB.png?branch=master)](http://travis-ci.org/kelp404/NyaruDB)
###＼(・ω・＼)SAN値！(／・ω・)／ピンチ！
> <a href="http://nyaruko.com/" target="_blank">這いよれ！ニャル子さんW</a>  
> 2013年4月7日（日）深夜1:05～からテレビ東京ほかにて放送スタート！  


[MIT License](http://www.opensource.org/licenses/mit-license.php)


NyaruDB is a simple NoSQL database in Objective-C. It could be run on iOS and OS X.  
It is a key-valu pair NoSQL database. You could search data by fields of the document.


##Feature
####More quickly than sqlite.  
>
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


####Clean query syntax.  
>
```objective-c
// where type == 1 order by update
NSArray *documents = [[[collection where:@"type" equal:@1] orderBy:@"update"] fetch];
```



---
##Installation
####git

>
```bash
$ git clone git://github.com/kelp404/NyaruDB.git
```

####<a href="http://cocoapods.org/" target="_blank">CocoadPods</a>:

>
add `Podfile` in your project path
```
platform :ios
pod 'NyaruDB'
```
```bash
$ pod install
```



---
##Management Tool
####<a href="https://github.com/kelp404/NyaruDB-Control" target="_blank">NyaruDB Control</a>  
<img src='https://raw.github.com/kelp404/NyaruDB-Control/master/_images/screenshot00.png'/>



---
##Collection
Collection is like Table of sql database.  



##Index
When you want to search data by a field, you should create a index.  
If you want to search data by 'email', you should create a 'email' index before searching.  



##Document
Document is data in the collection.

There is a member named `key` in the document. Key is unique and datatype is NSString.
If the document has no `key` when inserted, it will be automatically generated.

+ Normal Field Datatype: `NSNull`, `NSNumber`, `NSDate`, `NSString`, `NSArray`, `NSDictionary`  
**(items just allow `NSString`, `NSNumber`, `NSDate` and `NSNull` in the `NSArray`)**  
+ Index Field Datatype: `NSNull`, `NSNumber`, `NSDate`, `NSString`  



---
##Access Database
###Instance
>
####iOS
`[NyaruDB instance]` returns a static NyaruDB instance, and database path is `/your-app/Documents/NyaruDB`.
```objective-c
NyaruDB *db = [NyaruDB instance];
```
####OS X
`[[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"]`.  
NyaruDB will scan all documents in collections when `[NyaruDB init]`, so do not call `init` too much.  
In OS X, you should handle the static instance by yourself.  
```objective-c
NyaruDB *db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];
```


###Create the collection
>
```objective-c
NyaruCollection *collectioin = [db collection:@"collectionName"];
```


###Create the index
>
```objective-c
NyaruCollection *collection = [db collection:@"collectionName"];
[collection createIndex:@"email"];
[collection createIndex:@"number"];
[collection createIndex:@"date"];
```


###Insert the document
>
If there is a document has the same 'key', it will be replace with the new document. (update document)
```objective-c
NyaruCollection *collection = [db collection:@"collectionName"];
NSDictionary *document = @{@"email": @"kelp@phate.org",
    @"name": @"Kelp",
    @"phone": @"0123456789",
    @"date": [NSDate date],
    @"text": @"(」・ω・)」うー！(／・ω・)／にゃー！",
    @"number": @100};
[collection put:document];
```


###Query
>
The field of the document which is `key` or `index` supports search.  
`key` supports `equal`.  
`index` supports `equal`, `notEqual`, `less`, `lessEqual`, `greater`, `greaterEqual` and `like`.  
>
You could use `and`(Intersection) or `or` to append the query.
```objective-c
// search the document the 'key' is equal to 'IjkhMGIT752091136'
NyaruCollection *co = [db collection:@"collectionName"];
NSArray *documents = [[co where:@"key" equal:@"IjkhMGIT752091136"] fetch];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```
```objective-c
// search documents the 'date' is greater than now, and sort by date with DESC
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
NyaruCollection *co = [db collection:@"collectionName"];
NSDate *date = [NSDate date];
NSArray *documents = [[[[co where:@"date" greater:date] and:@"type" equal:@2] orderBy:@"date"] fetch];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```
```objective-c
// search documents 'type' == 1 or 'type' == 3
NyaruCollection *co = [db collection:@"collectionName"];
NSArray *documents = [[[co where:@"type" equal:@1] or:@"type" equal:@3] fetch];
for (NSMutableDictionary *document in documents) {
    NSLog(@"%@", document);
}
```
```objective-c
// count documents 'type' == 1
NyaruCollection *co = [db collection:@"collectionName"];
NSUInteger count = [[co where:@"type" equal:@1] count];
NSLog(@"%u", count);
```


###Delete documents
>
```objective-c
NyaruCollection *co = [db collection:@"collectionName"];
[co createIndex:@"number"];
[co put:@{@"number": @100}];
[co put:@{@"number": @200}];
[co put:@{@"number": @10}];
// remove by query
[[co where:@"number" equal:@10] remove];
// remove all
[[co all] remove];
```


###Sync & Async
>
`put` and `remove` will be run as async mode.  
`fetch` and `count` will be run as sync mode. But all commands will be processed on a same dispatch.  
>
After 1.4.1 NyaruDB has new messages about async fetch and count.  
`[NyaruQuery fetchAsync:(void (^)(NSArray *))handler]`  
`[NyaruQuery countAsync:(void (^)(NSUInteger))handler]`  
>
If you wount to put documents as sync, you could use `[NyaruCollection waitForWriting]`.
```Objective-C
NyaruDB *db = [NyaruDB instance];
NyaruCollection *collection = [db collection:@"collection"];
NSDictionary *document = @{@"email": @"kelp@phate.org",
    @"name": @"Kelp",
    @"phone": @"0123456789",
    @"date": [NSDate date],
    @"text": @"(」・ω・)」",
    @"number": @100};
[collection put:document];
[collection waitForWriting];  // sync
```
>
```Objective-C
// be Careful
NyaruDB *db = [NyaruDB instance];
NyaruCollection *collection = [db collection:@"collection"];
NSDictionary *document = @{@"email": @"kelp@phate.org",
    @"name": @"Kelp",
    @"phone": @"0123456789",
    @"date": [NSDate date],
    @"text": @"(」・ω・)」",
    @"number": @100};
for (NSUInteger index = 0; index < 1000; index++) {
    // put 1k documents
    [collection put:document];
}
// cpu will wait for documents write done.
// if this is main dispatch, it will be locked.
NSUInteger count = collection.count;
// you could try this
[collection countAsync:^(NSUInteger count) {
    // this block run in main dispatch
}];
```




---
##Class
###NyaruDB interface
>
```Objective-C
#pragma mark - Instance
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
#pragma mark - Collection
- (NSArray *)collections;
- (NyaruCollection *)collection:(NSString *)name;
#pragma mark Remove
- (void)removeCollection:(NSString *)name;
- (void)removeAllCollections;
```


###NyaruCollection interface
>
```Objective-C
#pragma mark - Index
- (NSArray *)allIndexes;
- (void)createIndex:(NSString *)indexName;
- (void)removeIndex:(NSString *)indexName;
- (void)removeAllindexes;
#pragma mark - Document
// put document
- (NSMutableDictionary *)put:(NSDictionary *)document;
// remove all documents (directly remove files)
- (void)removeAll;
// waiting for data writing
- (void)waitForWriting;
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
- (void)countAsync:(void (^)(NSUInteger))handler;
```


###NyaruQuery interface
>
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
- (NyaruQuery *)or:(NSString *)indexName equal:(id)value;
- (NyaruQuery *)or:(NSString *)indexName notEqual:(id)value;
- (NyaruQuery *)or:(NSString *)indexName less:(id)value;
- (NyaruQuery *)or:(NSString *)indexName lessEqual:(id)value;
- (NyaruQuery *)or:(NSString *)indexName greater:(id)value;
- (NyaruQuery *)or:(NSString *)indexName greaterEqual:(id)value;
- (NyaruQuery *)or:(NSString *)indexName like:(NSString *)value;
#pragma mark - Order By
- (NyaruQuery *)orderBy:(NSString *)indexName;
- (NyaruQuery *)orderByDESC:(NSString *)indexName;
#pragma mark - Count
- (NSUInteger)count;
- (void)countAsync:(void (^)(NSUInteger))handler;
#pragma mark - Fetch
- (NSArray *)fetch;
- (NSArray *)fetch:(NSUInteger)limit;
- (NSArray *)fetch:(NSUInteger)limit skip:(NSUInteger)skip;
- (NSMutableDictionary *)fetchFirst;
- (void)fetchAsync:(void (^)(NSArray *))handler;
- (void)fetch:(NSUInteger)limit async:(void (^)(NSArray *))handler;
- (void)fetch:(NSUInteger)limit skip:(NSUInteger)skip async:(void (^)(NSArray *))handler;
- (void)fetchFirstAsync:(void (^)(NSMutableDictionary *))handler;
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


##Thanks
+ [ニャル子](http://nyaruko.com/)
+ 白い悪魔なのは
+ [LINQ](http://msdn.microsoft.com/en-us//library/bb397897.aspx)


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
