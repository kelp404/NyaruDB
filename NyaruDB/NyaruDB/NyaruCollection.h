//
//  NyaruCollection.h
//  NyaruDB
//
//  Created by Kelp on 2013/02/18.
//
//

#import <Foundation/Foundation.h>

@class NyaruIndexBlock;
@class NyaruQuery;


@interface NyaruCollection : NSObject {
    /**
     File io dispatch queue.
     Access _schemas, _clearedIndexBlock, write/read file shoud in this queue.
     */
    dispatch_queue_t _accessQueue;
    
    /**
     If key is missing, null or empty then it will be generated in this dispatch.
     */
    dispatch_queue_t _keyGeneratorQueue;
    
    /**
     A field in the document for search.
     { key: schema name, value: NyaruSchema }
     */
    NSMutableDictionary *_schemas;
    
    /**
     Index offset without data.
     [NyaruIndexBlock]
     */
    NSMutableArray *_clearedIndexBlock;
    
    /**
     Fetch document with NyaruKey cache.
     Cache document for NYARU_CACHE_LIMIT items.
     { key: @documentOffset, value: document }
     */
    NSCache *_documentCache;
    
    // file full-path
    NSString *_documentFilePath;
    NSString *_schemaFilePath;
    NSString *_indexFilePath;
    
    unsigned int _idCount;
}

/**
 Collection name
 */
@property (strong, nonatomic, readonly) NSString *name;


#pragma mark - Init
/**
 Init a collection instance it is new.
 @param name collection name
 @param databasePath collection path (it is a folder path)
 @return collection instance
 */
- (id)initWithNewCollectionName:(NSString *)name databasePath:(NSString *)databasePath;

/**
 Init a collection instance it is exist.
 @param name collection name
 @param databasePath collection path (it is a folder path)
 @return collection instance
 */
- (id)initWithLoadCollectionName:(NSString *)name databasePath:(NSString *)databasePath;


#pragma mark - Index
/**
 Get all indexes.
 @return ["index name"]
 */
- (NSArray *)allIndexes;
- (void)createIndex:(NSString *)indexName;
- (void)removeIndex:(NSString *)indexName;
- (void)removeAllindexes;


#pragma mark - Document
#pragma mark Put
/**
 Put the document into the collection.
 @param document: put this document into the collection.
        If the document has no 'key' then it will be generate.
        If there is a document has the same 'key', it will be replace with the new.
 @return: the put document.
 */
- (NSMutableDictionary *)put:(NSDictionary *)document;
- (void)waitForWriting;
#pragma mark Remove
- (void)removeByKey:(NSString *)documentKey;
- (void)removeByQuery:(NSArray *)queries;
- (void)removeAll;
#pragma mark Cache
- (void)clearCache;


#pragma mark - Query
- (NyaruQuery *)query;
- (NyaruQuery *)all;
- (NyaruQuery *)where:(NSString *)indexName equal:(id)value;
- (NyaruQuery *)where:(NSString *)indexName notEqual:(id)value;
- (NyaruQuery *)where:(NSString *)indexName less:(id)value;
- (NyaruQuery *)where:(NSString *)indexName lessEqual:(id)value;
- (NyaruQuery *)where:(NSString *)indexName greater:(id)value;
- (NyaruQuery *)where:(NSString *)indexName greaterEqual:(id)value;
- (NyaruQuery *)where:(NSString *)indexName like:(NSString *)value;

#pragma mark - Count
/**
 Count all documents.
 @return The number of all documents.
 */
- (NSUInteger)count;
/**
 Count by queries.
 @param queries The nyaru queries.
 @return The count result.
 */
- (NSUInteger)countByQuery:(NSArray *)queries;
/**
 Count all documents.
 @param handler The result handler. It will run in main dispatch.
 */
- (void)countAsync:(void (^)(NSUInteger))handler;
/**
 Count by queries.
 @param queries The nyaru queries.
 @param handler The result handler. It will run in main dispatch.
 */
- (void)countByQuery:(NSArray *)queries async:(void (^)(NSUInteger))handler;

#pragma mark - Fetch
/**
 Fetch documents by queries.
 @param queries The nyaru queries.
 @param skip The number of skip data.
 @param limit The number of result documents.
 @return [NSMutableDictionary]
 */
- (NSArray *)fetchByQuery:(NSArray *)queries skip:(NSUInteger)skip limit:(NSUInteger)limit;
/**
 Async fetch documents by queries.
 @param queries The nyaru queries.
 @param skip The number of skip data.
 @param limit The number of result documents.
 @param handler The result handler. It will run in main dispatch.
 */
- (void)fetchByQuery:(NSArray *)queries skip:(NSUInteger)skip limit:(NSUInteger)limit async:(void (^)(NSArray *))handler;


#pragma mark - Private methods
/**
 Remove all files of this collection.
 * do not use this message, please use [NyaruDB deleteCollectionWithName:@"collection"].
 */
- (void)removeCollectionFiles;
/**
 Remove all dictionarys and arrays.
 */
- (void)close;

#pragma mark Schema
/**
 Collection's schemas. This is for test.
 */
- (NSMutableDictionary *)schemas;


@end
