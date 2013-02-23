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
#pragma mark Insert
- (NSMutableDictionary *)insert:(NSDictionary *)document;
- (void)waiteForWriting;
#pragma mark Remove
- (void)removeByKey:(NSString *)documentKey;
- (void)removeByQuery:(NSArray *)queries;
- (void)removeAll;


#pragma mark - Query
- (NyaruQuery *)query;
- (NyaruQuery *)all;
- (NyaruQuery *)where:(NSString *)indexName equalTo:(id)value;
- (NyaruQuery *)where:(NSString *)indexName notEqualTo:(id)value;
- (NyaruQuery *)where:(NSString *)indexName lessThan:(id)value;
- (NyaruQuery *)where:(NSString *)indexName lessEqualThan:(id)value;
- (NyaruQuery *)where:(NSString *)indexName greaterThan:(id)value;
- (NyaruQuery *)where:(NSString *)indexName greaterEqualThan:(id)value;
- (NyaruQuery *)where:(NSString *)indexName likeTo:(NSString *)value;

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
