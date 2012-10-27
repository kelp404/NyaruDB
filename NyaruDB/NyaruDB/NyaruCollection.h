//
//  NyaruCollection.h
//  NyaruDB
//
//  Created by Kelp on 12/8/12.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NyaruConfig.h"
#import "NyaruKey.h"
#import "NyaruIndex.h"
#import "NyaruSchema.h"
#import "NyaruQuery.h"

@class NyaruCollection;

@interface NyaruCollection : NSObject {
    dispatch_queue_t _ioQueue;
    
    // key: name of key of index schema, value: index schema
    NSMutableDictionary *_schema;
    
    // file full-path
    NSString *_documentFilePath;
    NSString *_schemaFilePath;
    NSString *_indexFilePath;
    
    // index offset without data, [{ NyaruConfig.indexOffset: NSNumber, NyaruConfig.blockLength: NSNumber}, { NyaruConfig.indexOffset: NSNumber, NyaruConfig.blockLength: NSNumber}]
    NSMutableArray *_clearedIndexBlock;
}

// collection name
@property (strong, nonatomic, readonly) NSString *name;

#pragma mark - Collection
// create a collection
- (id)initWithNewCollectionName:(NSString *)name databasePath:(NSString *)databasePath;
// load a collection
- (id)initWithLoadCollectionName:(NSString *)name databasePath:(NSString *)databasePath;
// remove a collection
- (void)remove;

#pragma mark - Schema
// get schema
- (NSDictionary *)allSchemas;
- (NyaruSchema *)schemaForName:(NSString *)name;
// create schema
// success: return a new schema,    failed: return nil
- (NyaruSchema *)createSchema:(NSString *)name;
// remove schema
- (void)removeSchema:(NSString *)name;

#pragma mark - Document
/*
 read document by key or NyaruQuery
 If data is not exist then return nil.
 skip 0 and take 100 is default query.
*/
- (NSMutableDictionary *)documentForKey:(NSString *)key;
- (NSUInteger)countForQueries:(NSArray *)query;
- (NSArray *)documentsForNyaruQueries:(NSArray *)query;
- (NSArray *)documentsForNyaruQueries:(NSArray *)query skip:(NSUInteger)skip take:(NSUInteger)take;

/*
 insert document
 You could insert data with dictinoary.
 The data necessary includes the property(member) which name is "key".
*/
- (NSMutableDictionary *)insertDocumentWithDictionary:(NSDictionary *)document;

/*
 remove document
*/
- (void)removeDocumentForKey:(NSString *)key;

@end
