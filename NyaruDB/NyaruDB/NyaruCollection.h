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
/**
 Please use [NyaruCollection put:]
 It will be removed in 1.4.
 */
- (NSMutableDictionary *)insert:(NSDictionary *)document;
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
- (NSUInteger)count;
- (NSUInteger)countByQuery:(NSArray *)queries;

#pragma mark - Fetch
// fetch document by query
- (NSArray *)fetchByQuery:(NSArray *)queries skip:(NSUInteger)skip limit:(NSUInteger)limit;
// only fetch the field "key" in the document
- (NSArray *)fetchKeyByQuery:(NSArray *)queries skip:(NSUInteger)skip limit:(NSUInteger)limit;


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
