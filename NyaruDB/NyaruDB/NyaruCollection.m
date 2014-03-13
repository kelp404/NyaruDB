//
//  NyaruCollection.m
//  NyaruDB
//
//  Created by Kelp on 2013/02/18.
//
//

#import "NyaruCollection.h"
#import "NyaruConfig.h"
#import "NyaruIndexBlock.h"
#import "NyaruSchema.h"
#import "NyaruKey.h"
#import "NyaruIndex.h"
#import "NyaruQuery.h"
#import "NyaruQueryCell.h"


// these are for passing Cocoapods Travis CI build [function-declaration]
@interface NyaruCollection()
NYARU_BURST_LINK NSArray *nyaruKeysForNyaruQueries(NSMutableDictionary *schemas, NSArray *queries, BOOL isReturnNyaruKey);
NYARU_BURST_LINK NSArray *nyaruKeysWithQuery(NyaruSchema *schema, NyaruQueryCell *query);
NYARU_BURST_LINK NSArray *nyaruKeysWithSortByIndexValue(NyaruSchema *schema, NyaruQueryCell *query);
NYARU_BURST_LINK NSArray *filterEqual(NSArray *allIndexes, id target, NyaruSchemaType type);
NYARU_BURST_LINK NSMutableArray *filterUnequal(NSArray *allIndexes, id target, NyaruSchemaType type);
NYARU_BURST_LINK NSMutableArray *filterLess(NSArray *allIndexes, id target, NyaruSchemaType type, BOOL includeEqual);
NYARU_BURST_LINK NSArray *filterGreater(NSArray *allIndexes, id target, NyaruSchemaType type, BOOL includeEqual);
NYARU_BURST_LINK NSMutableArray *filterLike(NSArray *allIndexes, NSString *target, NyaruSchemaType type);
NYARU_BURST_LINK NSRange findEqualRange(NSArray *array, id target, NyaruSchemaType type);

#pragma mark - compare value1 and value2
NYARU_BURST_LINK NSComparisonResult compare(id value1, id value2, NyaruSchemaType schemaType);
NYARU_BURST_LINK NSComparisonResult compareDate(NSDate *value1, NSDate *value2);

#pragma mark - Serializer
NYARU_BURST_LINK NSData *serialize(NSDictionary *document);
NYARU_BURST_LINK unsigned char *serializeString(unsigned *length, NSString *source);
NYARU_BURST_LINK unsigned char *serializeDate(unsigned *length, NSDate *source);
NYARU_BURST_LINK unsigned char *serializeNumber(unsigned *length, NSNumber *source);
NYARU_BURST_LINK unsigned char *serializeArray(unsigned *length, NSArray *source);
NYARU_BURST_LINK NSMutableDictionary *deserialize(NSData *data);
NYARU_BURST_LINK NSString *deserializeString(const unsigned char *content, NSUInteger offset, unsigned keyLength, unsigned valueLength);
NYARU_BURST_LINK NSDate *deserializeDate(const unsigned char *content, NSUInteger offset, unsigned keyLength, unsigned valueLength);
NYARU_BURST_LINK NSNumber *deserializeNumber(const unsigned char *content, NSUInteger offset, unsigned keyLength, unsigned valueLength);
NYARU_BURST_LINK NSMutableArray *deserializeArray(const unsigned char *content, NSUInteger offset, unsigned keyLength, unsigned valueLength);
NYARU_BURST_LINK NSString *deserializeArrayString(const unsigned char *content, NSUInteger offset, unsigned valueLength);
NYARU_BURST_LINK NSDate *deserializeArrayDate(const unsigned char *content, NSUInteger offset, unsigned valueLength);
NYARU_BURST_LINK NSNumber *deserializeArrayNumber(const unsigned char *content, NSUInteger offset, unsigned valueLength);

#pragma mark - fetch
NYARU_BURST_LINK NSMutableDictionary *fetchDocumentWithNyaruKey(NyaruKey *nyaruKey, NSCache *documentCache, NSFileHandle *fileDocument);

#pragma mark - Loader
NYARU_BURST_LINK NSMutableDictionary *loadSchema(NSString *path);
NYARU_BURST_LINK void loadIndex(NSMutableDictionary *schemas, NSMutableArray *clearedIndexBlock, NSString *indexFilePath, NSString *documentFilePath);
NYARU_BURST_LINK void loadIndexForSchema(NyaruSchema *schema, NSMutableDictionary *schemas, NSMutableArray *clearedIndexBlock, NSString *indexFilePath, NSString *documentFilePath);

#pragma mark - Others
NYARU_BURST_LINK NyaruSchema *getLastSchema(NSDictionary *allSchemas);
NYARU_BURST_LINK BOOL isNyaruHeaderOK(NSString *path);
NYARU_BURST_LINK void fileDelete(NSString *path);
@end



@implementation NyaruCollection


#pragma mark - Init
/**
 Get a NyaruCollection instance with collection name.
 @param name collection name
 @return NyaruCollection instance
 */
- (id)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        if (name.length == 0U) {
            @throw([NSException exceptionWithName:NYARU_PRODUCT reason:@"name is nil or empty." userInfo:nil]);
        }
        
        _name = name;
        _idCount = 0U;
        _accessQueue = dispatch_queue_create([[NSString stringWithFormat:@"NyaruDB.Access.%@", name] cStringUsingEncoding:NSUTF8StringEncoding], NULL);
        _keyGeneratorQueue = dispatch_queue_create("NyaruDB.key.generator", NULL);
        _documentCache = [NSCache new];
        [_documentCache setCountLimit:NYARU_CACHE_LIMIT];
        _clearedIndexBlock = [NSMutableArray new];
    }
    return self;
}

#pragma mark - ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
#pragma mark - Collection
#pragma mark create a collection
- (id)initWithNewCollectionName:(NSString *)name databasePath:(NSString *)databasePath
{
    self = [self initWithName:name];
    if (self) {
        _indexFilePath = [[databasePath stringByAppendingPathComponent:_name] stringByAppendingPathExtension:NYARU_INDEX];
        _schemaFilePath = [[databasePath stringByAppendingPathComponent:_name] stringByAppendingPathExtension:NYARU_SCHEMA];
        _documentFilePath = [[databasePath stringByAppendingPathComponent:_name] stringByAppendingPathExtension:NYARU_DOCUMENT];
        
        // check all file exists. if exist then delete it.
        fileDelete(_documentFilePath);
        fileDelete(_indexFilePath);
        fileDelete(_schemaFilePath);
        
        // create collection file
        NSError *error = nil;
        [NYARU_HEADER writeToFile:_documentFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NYARU_PRODUCT reason:error.description userInfo:error.userInfo]);
        }
        [NYARU_HEADER writeToFile:_schemaFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NYARU_PRODUCT reason:error.description userInfo:error.userInfo]);
        }
        [NYARU_HEADER writeToFile:_indexFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NYARU_PRODUCT reason:error.description userInfo:error.userInfo]);
        }
        
        _schemas = [NSMutableDictionary new];
        [self createIndex:NYARU_KEY];
    }
    return self;
}

#pragma mark load a collection
- (id)initWithLoadCollectionName:(NSString *)name databasePath:(NSString *)databasePath
{
    self = [self initWithName:name];
    if (self) {
        _indexFilePath = [[databasePath stringByAppendingPathComponent:_name] stringByAppendingPathExtension:NYARU_INDEX];
        _schemaFilePath = [[databasePath stringByAppendingPathComponent:_name] stringByAppendingPathExtension:NYARU_SCHEMA];
        _documentFilePath = [[databasePath stringByAppendingPathComponent:_name] stringByAppendingPathExtension:NYARU_DOCUMENT];
        
        // check all file exists
        if (!([[NSFileManager defaultManager] fileExistsAtPath:_documentFilePath] &&
              [[NSFileManager defaultManager] fileExistsAtPath:_indexFilePath] &&
              [[NSFileManager defaultManager] fileExistsAtPath:_schemaFilePath])) {
            @throw [NSException exceptionWithName:NYARU_PRODUCT reason:@"file miss" userInfo:nil];
        }
        
        // check file header
        if (!(isNyaruHeaderOK(_indexFilePath) &&
              isNyaruHeaderOK(_schemaFilePath) &&
              isNyaruHeaderOK(_documentFilePath))) {
            // header error
            @throw [NSException exceptionWithName:NYARU_PRODUCT reason:@"file header error" userInfo:nil];
        }
        
        // load schema
        _schemas = loadSchema(_schemaFilePath);
        loadIndex(_schemas, _clearedIndexBlock, _indexFilePath, _documentFilePath);
    }
    return self;
}


#pragma mark - Index
- (NSArray *)allIndexes
{
    __block NSArray *result;
    dispatch_sync(_accessQueue, ^{
        result = _schemas.allKeys;
    });
    return result;
}
- (void)createIndex:(NSString *)indexName
{
    if (indexName.length == 0U) { return; }
    
    dispatch_async(_accessQueue, ^{
        // check exist
        if (_schemas[indexName]) { return; }
        
        NyaruSchema *lastSchema = getLastSchema(_schemas);
        unsigned previous = 0U;
        if (lastSchema) {
            previous = lastSchema.offsetInFile;
        }
        
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:_schemaFilePath];
        NyaruSchema *schema = [[NyaruSchema alloc] initWithName:indexName previousOffser:previous nextOffset:0U];
        schema.offsetInFile = (unsigned)[file seekToEndOfFile];
        [file writeData:schema.dataFormate];
        
        if (lastSchema) {
            // update last schema's next offset
            lastSchema.nextOffsetInFile = schema.offsetInFile;
            unsigned offset = schema.offsetInFile;
            [file seekToFileOffset:lastSchema.offsetInFile + 4];
            [file writeData:[NSData dataWithBytes:&offset length:sizeof(offset)]];
        }
        [file closeFile];
        
        [_schemas setObject:schema forKey:schema.name];
        loadIndexForSchema(schema, _schemas, _clearedIndexBlock, _indexFilePath, _documentFilePath);
    });
}
- (void)removeIndex:(NSString *)indexName
{
    if ([indexName isEqualToString:NYARU_KEY]) {
        @throw([NSException exceptionWithName:NYARU_PRODUCT reason:@"index 'key' could not be remove." userInfo:nil]);
    }
    
    dispatch_async(_accessQueue, ^{
        NyaruSchema *schema = _schemas[indexName];
        if (schema) {
            NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:_schemaFilePath];
            unsigned offset;
            if (schema.previousOffsetInFile > 0U) {
                // set next offset of previous schema
                offset = schema.nextOffsetInFile;
                [file seekToFileOffset:schema.previousOffsetInFile + 4U];
                [file writeData:[NSData dataWithBytes:&offset length:sizeof(offset)]];
            }
            else if (schema.nextOffsetInFile > 0U) {
                // set previous offset of next schema
                offset = schema.previousOffsetInFile;
                [file seekToFileOffset:schema.nextOffsetInFile];
                [file writeData:[NSData dataWithBytes:&offset length:sizeof(offset)]];
            }
            [file closeFile];
            
            [_schemas removeObjectForKey:indexName];
        }
    });
}
- (void)removeAllindexes
{
    for (NSString *index in self.allIndexes) {
        if ([index isEqualToString:NYARU_KEY]) { continue; }
        [self removeIndex:index];
    }
}


#pragma mark - Document
- (NSMutableDictionary *)put:(NSDictionary *)document
{
    if (!document) {
        @throw [NSException exceptionWithName:NYARU_PRODUCT reason:@"document could not be nil." userInfo:nil];
        return nil;
    }
    
    NSMutableDictionary *doc = [document mutableCopy];
    if (!doc[NYARU_KEY] ||
        [doc[NYARU_KEY] isKindOfClass:NSNull.class] ||
        [(NSString *)doc[NYARU_KEY] length] == 0U) {
        // If key is missing, null or empty then generate it.
        dispatch_sync(_keyGeneratorQueue, ^{
            // if generate in different dispatches, it may be the same.
            CFUUIDRef uuid = CFUUIDCreate(NULL);
            CFStringRef result = CFUUIDCreateString(NULL, uuid);
            [doc setObject:[NSString stringWithString:(__bridge NSString *)result] forKey:NYARU_KEY];
            CFRelease(result);
            CFRelease(uuid);
        });
    }
    
    // serialize document
    __block NSData *docData = serialize(doc);
    
    if (docData.length == 0U) {
        @throw [NSException exceptionWithName:NYARU_PRODUCT reason:@"document serialized failed." userInfo:nil];
        return nil;
    }
    
    // write data with GCD
    dispatch_async(_accessQueue, ^{
        // document key
        NSString *docKey = doc[NYARU_KEY];
        
        // io handle
        NSFileHandle *fileDocument = [NSFileHandle fileHandleForWritingAtPath:_documentFilePath];
        NSFileHandle *fileIndex = [NSFileHandle fileHandleForUpdatingAtPath:_indexFilePath];
        
        // check key is exist
        NyaruKey *existKey = [(NyaruSchema *)_schemas[NYARU_KEY] allKeys][docKey];
        if (existKey) {
            // remove cache
            [_documentCache removeObjectForKey:[NSNumber numberWithUnsignedInt:existKey.documentOffset]];
            
            // remove data in .index
            unsigned zeroData = 0U;
            [fileIndex seekToFileOffset:existKey.indexOffset + 4U];
            [fileIndex writeData:[NSData dataWithBytes:&zeroData length:sizeof(zeroData)]];
            [_clearedIndexBlock addObject:[[NyaruIndexBlock alloc] initWithOffset:existKey.indexOffset andLength:existKey.blockLength]];
            
            for (NyaruSchema *schema in _schemas.allValues) {
                [schema removeWithKey:docKey];
            }
        }
        
        unsigned documentOffset = 0U;
        unsigned documentLength = (unsigned)docData.length;
        unsigned blockLength = 0U;
        unsigned indexOffset = 0U;
        
        // get index offset
        for (NSUInteger blockIndex = 0U; blockIndex < _clearedIndexBlock.count; blockIndex++) {
            NyaruIndexBlock *block = _clearedIndexBlock[blockIndex];
            if (block.blockLength >= documentLength) {
                // old document block could be reuse
                indexOffset = block.indexOffset;
                
                // read old document block offset
                [fileIndex seekToFileOffset:indexOffset];
                NSData *documentOffsetData = [fileIndex readDataOfLength:sizeof(documentOffset)];
                memcpy(&documentOffset, documentOffsetData.bytes, sizeof(documentOffset));
                [fileDocument seekToFileOffset:documentOffset];
                
                // if reuse document block, update index data
                [fileIndex seekToFileOffset:indexOffset];
                
                [_clearedIndexBlock removeObjectAtIndex:blockIndex];
                break;
            }
        }
        if (indexOffset == 0U) {
            documentOffset = (unsigned)[fileDocument seekToEndOfFile];
            indexOffset = (unsigned)[fileIndex seekToEndOfFile];
            blockLength = documentLength;
        }
        
        // push key and index
        for (NyaruSchema *schema in _schemas.allValues) {
            if (schema.unique) {
                NyaruKey *key = [[NyaruKey alloc] initWithIndexOffset:indexOffset
                                                       documentOffset:documentOffset
                                                       documentLength:documentLength
                                                          blockLength:blockLength];
                [schema pushNyaruKey:docKey nyaruKey:key];
            }
            else {
                [schema pushNyaruIndex:docKey value:doc[schema.name]];
            }
        }
        
        // write document
        [fileDocument writeData:docData];
        [_documentCache setObject:doc forKey:[NSNumber numberWithUnsignedInt:documentOffset]];
        
        // write index
        NSMutableData *indexData = [[NSMutableData alloc] initWithBytes:&documentOffset length:sizeof(documentOffset)];
        [indexData appendBytes:&documentLength length:sizeof(documentLength)];
        [indexData appendBytes:&blockLength length:sizeof(blockLength)];
        [fileIndex writeData:indexData];
        
        // close files
        [fileDocument closeFile];
        [fileIndex closeFile];
        docData = nil;
    });
    
    return doc;
}
- (void)waitForWriting
{
    dispatch_sync(_accessQueue, ^{ });
}
- (void)removeByKey:(NSString *)documentKey
{
    dispatch_async(_accessQueue, ^{
        NyaruKey *nyaruKey = [(NyaruSchema *)_schemas[NYARU_KEY] allKeys][documentKey];
        if (!nyaruKey) { return; }
        
        // remove cache
        [_documentCache removeObjectForKey:[NSNumber numberWithUnsignedInt:nyaruKey.documentOffset]];
        
        NSFileHandle *fileIndex = [NSFileHandle fileHandleForWritingAtPath:_indexFilePath];
        unsigned zeroData = 0U;
        [fileIndex seekToFileOffset:nyaruKey.indexOffset + 4U];
        [fileIndex writeData:[NSData dataWithBytes:&zeroData length:sizeof(zeroData)]];
        [_clearedIndexBlock addObject:[[NyaruIndexBlock alloc] initWithOffset:nyaruKey.indexOffset andLength:nyaruKey.blockLength]];
        
        for (NyaruSchema *schema in _schemas.allValues) {
            [schema removeWithKey:documentKey];
        }
        [fileIndex closeFile];
    });
}
- (void)removeByQuery:(NSArray *)queries
{
    dispatch_async(_accessQueue, ^{
        NSArray *documentKeys = nyaruKeysForNyaruQueries(_schemas, queries, NO);
        NSDictionary *keyMap = [(NyaruSchema *)_schemas[NYARU_KEY] allKeys];
        NSFileHandle *fileIndex = [NSFileHandle fileHandleForWritingAtPath:_indexFilePath];
        
        for (NSString *documentKey in documentKeys) {
            NyaruKey *nyaruKey = keyMap[documentKey];
            
            // remove cache
            [_documentCache removeObjectForKey:[NSNumber numberWithUnsignedInt:nyaruKey.documentOffset]];
            
            unsigned zeroData = 0U;
            [fileIndex seekToFileOffset:nyaruKey.indexOffset + 4U];
            [fileIndex writeData:[NSData dataWithBytes:&zeroData length:sizeof(zeroData)]];
            [_clearedIndexBlock addObject:[[NyaruIndexBlock alloc] initWithOffset:nyaruKey.indexOffset andLength:nyaruKey.blockLength]];
            
            for (NyaruSchema *schema in _schemas.allValues) {
                [schema removeWithKey:documentKey];
            }
        }
        [fileIndex closeFile];
    });
}
- (void)removeAll
{
    // write data with GCD
    dispatch_async(_accessQueue, ^{
        [_clearedIndexBlock removeAllObjects];
        [_documentCache removeAllObjects];
        for (NyaruSchema *schema in _schemas.allValues) {
            [schema removeAll];
        }
        
        // remove files
        [[NSFileManager defaultManager] removeItemAtPath:_documentFilePath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:_indexFilePath error:nil];
        
        // create files
        NSError *error = nil;
        NSString *header = NYARU_HEADER;
        [header writeToFile:_documentFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NYARU_PRODUCT reason:error.description userInfo:error.userInfo]);
        }
        [header writeToFile:_indexFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NYARU_PRODUCT reason:error.description userInfo:error.userInfo]);
        }
    });
}
#pragma mark Cache
- (void)clearCache
{
    [_documentCache removeAllObjects];
}


#pragma mark - Query
- (NyaruQuery *)query
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return query;
}
- (NyaruQuery *)all
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query orAll];
}
- (NyaruQuery *)where:(NSString *)indexName equal:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query or:indexName equal:value];
}
- (NyaruQuery *)where:(NSString *)indexName notEqual:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query or:indexName notEqual:value];
}
- (NyaruQuery *)where:(NSString *)indexName less:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query or:indexName less:value];
}
- (NyaruQuery *)where:(NSString *)indexName lessEqual:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query or:indexName lessEqual:value];
}
- (NyaruQuery *)where:(NSString *)indexName greater:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query or:indexName greater:value];
}
- (NyaruQuery *)where:(NSString *)indexName greaterEqual:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query or:indexName greaterEqual:value];
}
- (NyaruQuery *)where:(NSString *)indexName like:(NSString *)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query or:indexName like:value];
}


#pragma mark - Count
- (NSUInteger)count
{
    __block NSUInteger result;
    dispatch_sync(_accessQueue, ^{
        result = [_schemas[NYARU_KEY] allKeys].count;
    });
    return result;
}
- (NSUInteger)countByQuery:(NSArray *)queries
{
    __block NSUInteger result;
    dispatch_sync(_accessQueue, ^{
        result = nyaruKeysForNyaruQueries(_schemas, queries, NO).count;
    });
    return result;
}
- (void)countAsync:(void (^)(NSUInteger))handler
{
    dispatch_async(_accessQueue, ^{
        NSUInteger count = [_schemas[NYARU_KEY] allKeys].count;
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(count);
        });
    });
}
- (void)countByQuery:(NSArray *)queries async:(void (^)(NSUInteger))handler
{
    dispatch_async(_accessQueue, ^{
        NSUInteger count = nyaruKeysForNyaruQueries(_schemas, queries, NO).count;
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(count);
        });
    });
}


#pragma mark - Fetch
- (NSArray *)fetchByQuery:(NSArray *)queries skip:(NSUInteger)skip limit:(NSUInteger)limit
{
    __block NSMutableArray *result;
    dispatch_sync(_accessQueue, ^{
        NSUInteger fetchLimit = limit;
        NSArray *keys = nyaruKeysForNyaruQueries(_schemas, queries, YES);
        NSMutableDictionary *item;
        fetchLimit += skip;
        if (fetchLimit == 0U) { fetchLimit = keys.count; }
        else if (fetchLimit > keys.count) { fetchLimit = keys.count; }
        
        NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:_documentFilePath];
        
        result = [[NSMutableArray alloc] initWithCapacity:fetchLimit];
        for (NSUInteger index = skip; index < fetchLimit; index++) {
            item = fetchDocumentWithNyaruKey(keys[index], _documentCache, fileDocument);
            if (item) { [result addObject:item]; }
        }
        [fileDocument closeFile];
    });
    
    return result;
}

- (void)fetchByQuery:(NSArray *)queries skip:(NSUInteger)skip limit:(NSUInteger)limit async:(void (^)(NSArray *))handler
{
    dispatch_async(_accessQueue, ^{
        NSMutableArray *result;
        NSMutableDictionary *document;
        NSUInteger fetchLimit = limit;
        NSArray *keys = nyaruKeysForNyaruQueries(_schemas, queries, YES);
        
        fetchLimit += skip;
        if (fetchLimit == 0U) {
            // fetch all documents
            fetchLimit = keys.count;
        }
        else if (fetchLimit > keys.count) {
            // limit over bound
            fetchLimit = keys.count;
        }
        
        // open file handle
        NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:_documentFilePath];
        
        result = [[NSMutableArray alloc] initWithCapacity:fetchLimit];
        for (NSUInteger index = skip; index < fetchLimit; index++) {
            document = fetchDocumentWithNyaruKey(keys[index], _documentCache, fileDocument);
            if (document) {
                [result addObject:document];
            }
        }
        [fileDocument closeFile];
        
        // eval callback
        if (handler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(result);
            });
        }
    });
}


#pragma mark - ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
#pragma mark - for NyaruDB (do not use these)
- (void)removeCollectionFiles
{
    fileDelete(_schemaFilePath);
    fileDelete(_indexFilePath);
    fileDelete(_documentFilePath);
}
- (void)close
{
    dispatch_sync(_accessQueue, ^{
        for (NyaruSchema *schema in _schemas.allValues) {
            [schema close];
        }
        [_documentCache removeAllObjects];
        [_schemas removeAllObjects];
        [_clearedIndexBlock removeAllObjects];
    });
#if TARGET_OS_IPHONE
    dispatch_release(_accessQueue);
    dispatch_release(_keyGeneratorQueue);
#endif
}

#pragma mark Schema
- (NSMutableDictionary *)schemas
{
    return _schemas;
}


#pragma mark - Private methods
#pragma mark - Query
/**
 Get NyaruKeys with _schemas and queries
 @param schemas _schemas
 @param queries [NyaruQuery]
 @param isReturnNyaruKey YES: return @[NyaruKey], NO: return @[document.key]
 @return @[NyaruKey] / @[document.key]
 */
NYARU_BURST_LINK NSArray *nyaruKeysForNyaruQueries(NSMutableDictionary *schemas, NSArray *queries, BOOL isReturnNyaruKey)
{
    NyaruQueryCell *sortQuery = nil;
    NSMutableSet *resultKeys = [NSMutableSet new];
    NSArray *keys;
    
    for (NyaruQueryCell *query in queries) {
        NyaruSchema *schema = schemas[query.schemaName];
        
        if (query.operation == (NyaruQueryAll | NyaruQueryUnion)) {
            // union all
            if (queries.count == 1U) {
                // high speed return all NyaruKeys
                if (isReturnNyaruKey) {
                    return [(NyaruSchema *)schemas[NYARU_KEY] allKeys].allValues;
                }
                else {
                    return [(NyaruSchema *)schemas[NYARU_KEY] allKeys].allKeys;
                }
            }
            else {
                [resultKeys addObjectsFromArray:[(NyaruSchema *)schemas[NYARU_KEY] allKeys].allKeys];
            }
        }
        else if (!schema) { continue; }
        else if (query.operation == NyaruQueryOrderASC || query.operation == NyaruQueryOrderDESC) {
            // sort operation
            sortQuery = query;
        }
        else if ((query.operation & NyaruQueryIntersection) == NyaruQueryIntersection) {
            // and(intersect) .....
            keys = nyaruKeysWithQuery(schema, query);
            [resultKeys intersectSet:[NSSet setWithArray:keys]];
        }
        else if ((query.operation & NyaruQueryUnion) == NyaruQueryUnion) {
            // union .....
            keys = nyaruKeysWithQuery(schema, query);
            [resultKeys addObjectsFromArray:keys];
        }
    }
    
    NSDictionary *keyMap = nil;
    if (isReturnNyaruKey) {
        // return @[NyaruKey]
        keyMap = [(NyaruSchema *)schemas[NYARU_KEY] allKeys];
    }
    
    if (sortQuery) {
        // sort result and map document.key to NyaruKey
        NyaruSchema *nyaruSchema = schemas[sortQuery.schemaName];
        if (nyaruSchema) {
            NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:resultKeys.count];
            NSArray *sortedMap = nyaruKeysWithSortByIndexValue(nyaruSchema, sortQuery);
            if (isReturnNyaruKey) {
                // map document.key to NyaruKey
                for (NSString *key in sortedMap) {
                    if ([resultKeys intersectsSet:[NSSet setWithObject:key]]) {
                        [result addObject:keyMap[key]];
                    }
                }
            }
            else {
                for (NSString *key in sortedMap) {
                    if ([resultKeys intersectsSet:[NSSet setWithObject:key]]) {
                        [result addObject:key];
                    }
                }
            }
            return result;
        }
    }
    
    if (isReturnNyaruKey) {
        // map document.key to NyaruKey
        NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:resultKeys.count];
        for (NSString *key in resultKeys) {
            [result addObject:keyMap[key]];
        }
        return result;
    }
    else {
        return resultKeys.allObjects;
    }
}
/**
 Get NyaruIndexe.key in the schema with query.
 @param schema NyaruSchema
 @param query NyaruQueryCell
 @return @[NyaruIndex.key]
 */
NYARU_BURST_LINK NSArray *nyaruKeysWithQuery(NyaruSchema *schema, NyaruQueryCell *query)
{
    NSMutableArray *result = [NSMutableArray new];
    NyaruSchemaType queryType;
    
    // schema.key equal to query.value
    if (schema.unique) {
        if ((query.operation & NyaruQueryEqual) == NyaruQueryEqual) {
            NyaruKey *key = schema.allKeys[query.value];
            if (key) { [result addObject:query.value]; }
            return result;
        }
        else {
            @throw [NSException exceptionWithName:NYARU_PRODUCT reason:@"key des not provite query." userInfo:nil];
        }
    }
    
    // lookup class
    if ([query.value isKindOfClass:NSNull.class]) { queryType = NyaruSchemaTypeNil; }
    else if ([query.value isKindOfClass:NSNumber.class]) { queryType = NyaruSchemaTypeNumber; }
    else if ([query.value isKindOfClass:NSString.class]) { queryType = NyaruSchemaTypeString; }
    else if ([query.value isKindOfClass:NSDate.class]) { queryType = NyaruSchemaTypeDate; }
    else if (!query.value) { queryType = NyaruSchemaTypeNil; query.value = [NSNull null]; }
    else { queryType = NyaruSchemaTypeString; query.value = [NSString stringWithFormat:@"%@", query.value]; }
    
    if (queryType != NyaruSchemaTypeNil && schema.schemaType != queryType) {
        // type not match
        return result;
    }
    
    // switch operation
    NyaruQueryOperation op = query.operation & QUERY_OPERATION_MASK;
    // if query type is nil should set nil data here.
    switch (op) {
        case NyaruQueryEqual:
            if (queryType == NyaruSchemaTypeNil) {
                [result addObjectsFromArray:schema.allNilIndexes];
            }
            else { return filterEqual(schema.allNotNilIndexes, query.value, queryType); }
            break;
        case NyaruQueryUnequal:
            if (queryType == NyaruSchemaTypeNil) {
                for (NyaruIndex *index in schema.allNotNilIndexes) {
                    [result addObject:[index keySet].allObjects];
                }
            }
            else {
                result = filterUnequal(schema.allNotNilIndexes, query.value, queryType);
                [result addObjectsFromArray:schema.allNilIndexes];
            }
            break;
        case NyaruQueryLess:
            // no value less then nil
            if (queryType != NyaruSchemaTypeNil) {
                result = filterLess(schema.allNotNilIndexes, query.value, queryType, NO);
                [result addObjectsFromArray:schema.allNilIndexes];
            }
            break;
        case NyaruQueryLessEqual:
            if (queryType == NyaruSchemaTypeNil) {
                [result addObjectsFromArray:schema.allNilIndexes];
            }
            else {
                result = filterLess(schema.allNotNilIndexes, query.value, queryType, YES);
                [result addObjectsFromArray:schema.allNilIndexes];
            }
            break;
        case NyaruQueryGreater:
            if (queryType == NyaruSchemaTypeNil) {
                for (NyaruIndex *index in schema.allNotNilIndexes) {
                    [result addObject:[index keySet].allObjects];
                }
            }
            else { return filterGreater(schema.allNotNilIndexes, query.value, queryType, NO); }
            break;
        case NyaruQueryGreaterEqual:
            if (queryType == NyaruSchemaTypeNil) {
                [result addObjectsFromArray:schema.allNilIndexes];
                for (NyaruIndex *index in schema.allNotNilIndexes) {
                    [result addObject:[index keySet].allObjects];
                }
            }
            else { return filterGreater(schema.allNotNilIndexes, query.value, queryType, YES); }
            break;
        case NyaruQueryLike:
            result = filterLike(schema.allNotNilIndexes, query.value, queryType);
            if (queryType == NyaruSchemaTypeNil) {
                [result addObjectsFromArray:schema.allNilIndexes];
            }
            break;
        default:
            break;
    }
    
    return result;
}
/**
 Get all NyaruIndex.key in the schema and sort these by NyaruIndex.value.
 @param schema NyaruSchema
 @param query NyaruQueryCell
 @return @[NyaruIndex.key]
 */
NYARU_BURST_LINK NSArray *nyaruKeysWithSortByIndexValue(NyaruSchema *schema, NyaruQueryCell *query)
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:schema.allKeys.count];
    
    if ((query.operation & NyaruQueryOrderDESC) == NyaruQueryOrderDESC) {
        // DESC
        for (NyaruIndex *index in schema.allNotNilIndexes) {
            for (NSString *key in [index keySet].allObjects) {
                [result insertObject:key atIndex:0U];
            }
        }
        [result addObjectsFromArray:schema.allNilIndexes];
    }
    else {
        // ASC
        [result addObjectsFromArray:schema.allNilIndexes];
        for (NyaruIndex *index in schema.allNotNilIndexes) {
            [result addObjectsFromArray:[index keySet].allObjects];
        }
    }
    
    return result;
}
/**
 Get all NyaruIndex.key which's value is equal to target.
 @param allIndexes schema.allNotNillIndexes
 @param target NyaruQuery.value match target
 @param targetType NyaruSchemaType of target and schema
 @return @[NyaruIndex.key]
 */
NYARU_BURST_LINK NSArray *filterEqual(NSArray *allIndexes, id target, NyaruSchemaType type)
{
    NSRange range = findEqualRange(allIndexes, target, type);
    if (range.length > 0U) {
        // found equal value
        return [allIndexes[range.location] keySet].allObjects;
    }
    
    return [NSMutableArray new];
}
/**
 Get all NyaruIndex.key which's value is not equal to target.
 @param allIndexes schema.allNotNillIndexes
 @param target NyaruQuery.value match target
 @param targetType NyaruSchemaType of target and schema
 @return NSMutableArray [NyaruIndex.key]
 */
NYARU_BURST_LINK NSMutableArray *filterUnequal(NSArray *allIndexes, id target, NyaruSchemaType type)
{
    NSMutableArray *result = [NSMutableArray new];
    
    NSRange range = findEqualRange(allIndexes, target, type);
    if (range.length > 0U) {
        // found equal value
        NSUInteger max = range.location == NSUIntegerMax ? allIndexes.count : range.location;
        for (NSUInteger index = 0U; index < max; index++) {
            [result addObjectsFromArray:[allIndexes[index] keySet].allObjects];
        }
        for (NSUInteger index = range.location + range.length; index < allIndexes.count; index++) {
            [result addObjectsFromArray:[allIndexes[index] keySet].allObjects];
        }
    }
    else {
        // no equal value
        for (NyaruIndex *index in allIndexes) {
            [result addObjectsFromArray:[index keySet].allObjects];
        }
    }
    
    return result;
}
/**
 Get all NyaruIndex.key which's value is less(equal) to target.
 @param allIndexes schema.allNotNillIndexes
 @param target NyaruQuery.value match target
 @param targetType NyaruSchemaType of target and schema
 @param includeEqual YES: LessEqual, NO: Less
 @return @[NyaruIndex.key]
 */
NYARU_BURST_LINK NSMutableArray *filterLess(NSArray *allIndexes, id target, NyaruSchemaType type, BOOL includeEqual)
{
    NSMutableArray *result = [NSMutableArray new];
    
    NSRange range = findEqualRange(allIndexes, target, type);
    // no less data
    if (range.location == NSUIntegerMax && range.length == 0U) { return result; }
    
    if (range.location != NSUIntegerMax && range.location != 0U) {
        NSUInteger max = range.length > 0U ? range.location - 1U : range.location;
        for (NSUInteger index = 0U; index <= max; index++) {
            // add less datas
            [result addObjectsFromArray:[allIndexes[index] keySet].allObjects];
        }
    }
    
    if (includeEqual && range.length > 0U) {
        // add equal datas
        [result addObjectsFromArray:[allIndexes[range.location] keySet].allObjects];
    }
    
    return result;
}
/**
 Get all NyaruIndex.key which's value is greater(equal) to target.
 @param allIndexes schema.allNotNillIndexes
 @param target NyaruQuery.value match target
 @param targetType NyaruSchemaType of target and schema
 @param includeEqual YES: LessEqual, NO: Less
 @return @[NyaruIndex.key]
 */
NYARU_BURST_LINK NSArray *filterGreater(NSArray *allIndexes, id target, NyaruSchemaType type, BOOL includeEqual)
{
    NSMutableArray *result = [NSMutableArray new];
    
    NSRange range = findEqualRange(allIndexes, target, type);
    // no greater data
    if (range.location == allIndexes.count && range.length == 0U && !includeEqual) { return result; }
    if (range.location == NSUIntegerMax && range.length == 0U) {
        // all data is greater
        for (NSUInteger index = 0U; index < allIndexes.count; index++) {
            // add greater datas
            [result addObjectsFromArray:[allIndexes[index] keySet].allObjects];
        }
        return result;
    }
    
    for (NSUInteger index = range.location + 1U; index < allIndexes.count; index++) {
        // add greater datas
        [result addObjectsFromArray:[allIndexes[index] keySet].allObjects];
    }
    
    if (includeEqual && range.length > 0U) {
        // add equal datas
        [result addObjectsFromArray:[allIndexes[range.location] keySet].allObjects];
    }
    
    return result;
}
/**
 Get all NyaruIndex.key which's value is like, beginning of, end of to target.
 @param allIndexes schema.allNotNillIndexes
 @param target NyaruQuery.value match target
 @param targetType NyaruSchemaType of target and schema
 @return NSMutableArray [NyaruIndex.key]
 */
NYARU_BURST_LINK NSMutableArray *filterLike(NSArray *allIndexes, NSString *target, NyaruSchemaType type)
{
    NSMutableArray *result = [NSMutableArray new];
    
    for (NyaruIndex *index in allIndexes) {
        if ([index.value rangeOfString:target options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [result addObjectsFromArray:[index keySet].allObjects];
        }
    }
    
    return result;
}
/**
 Find equal items in the array.
 If there are no equal items then return final up bound, and length = 0;
 ([0, 2, 4], target=-1) => (NSUIntegerMax, 0)
 ([0, 2, 4], target=0) => (0, 1)
 ([0, 2, 4], target=1) => (0, 0)
 ([0, 2, 4], target=2) => (1, 1)
 ([0, 2, 4], target=3) => (1, 0)
 ([0, 2, 4], target=4) => (2, 1)
 ([0, 2, 4], target=5) => (2, 0)
 ([0, 2, 4, 6], target=5) => (2, 0)
 */
NYARU_BURST_LINK NSRange findEqualRange(NSArray *array, id target, NyaruSchemaType type)
{
    NSComparisonResult compResult;
    
    // array.count : 0 ~ 1
    switch (array.count) {
        case 0U:
            return NSMakeRange(NSUIntegerMax, 0U);
        case 1U:
            compResult = compare([(NyaruIndex *)array[0U] value], target, type);
            // target < array[0]
            if (compResult == NSOrderedDescending) { return NSMakeRange(NSUIntegerMax, 0U); }
            // target == array[0]
            else if (compResult == NSOrderedSame) { return NSMakeRange(0U, 1U); }
            // target > array[0]
            else { return NSMakeRange(0U, 0U); }
    }
    
    // compare the first
    compResult = compare([(NyaruIndex *)array[0U] value], target, type);
    switch (compResult) {
        case NSOrderedSame:
            // target == array[0]
            return NSMakeRange(0U, 1U);
        case NSOrderedDescending:
            // target < array[0]
            return NSMakeRange(NSUIntegerMax, 0U);
        case NSOrderedAscending: break;
    }
    // compare the last
    compResult = compare([(NyaruIndex *)[array lastObject] value], target, type);
    switch (compResult) {
        case NSOrderedSame:
            // index == array[last]
            return NSMakeRange(array.count - 1U, 1U);
        case NSOrderedAscending:
            // target > array[last]
            return NSMakeRange(array.count - 1U, 0U);
        case NSOrderedDescending: break;
    }
    
    NSUInteger upBound = 1U;
    NSUInteger downBound = array.count - 2U;
    NSUInteger targetIndex = (upBound + downBound) / 2U;
    
    while (upBound <= downBound) {
        compResult = compare([(NyaruIndex *)array[targetIndex] value], target, type);
        
        switch (compResult) {
            case NSOrderedSame:
                // array[targetIndex] = target
                return NSMakeRange(targetIndex, 1U);
            case NSOrderedDescending:
                // array[targetIndex] > target
                downBound = targetIndex - 1U;
                targetIndex = (upBound + downBound) / 2U;
                break;
            case NSOrderedAscending:
                // array[targetIndex] < target
                upBound = targetIndex + 1U;
                targetIndex = (upBound + downBound) / 2U;
                if (targetIndex < upBound) {    // last
                    return NSMakeRange(targetIndex, 0U);
                }
                break;
        }
    }
    
    // did not find the same value in the array.
    return NSMakeRange(upBound, 0U);
}
#pragma mark - compare value1 and value2
/**
 A comparer for inserting NyaruIndex.
 */
NYARU_BURST_LINK NSComparisonResult compare(id value1, id value2, NyaruSchemaType schemaType)
{
    switch (schemaType) {
        case NyaruSchemaTypeString:
            return [(NSString *)value1 compare:value2 options:NSCaseInsensitiveSearch];
        case NyaruSchemaTypeNumber:
            return [(NSNumber *)value1 compare:value2];
        case NyaruSchemaTypeDate:
            return compareDate((NSDate *)value1, (NSDate *)value2);
        default:
            return NSOrderedAscending;
    }
}
NYARU_BURST_LINK NSComparisonResult compareDate(NSDate *value1, NSDate *value2)
{
    NSInteger value1TimeInterval = value1.timeIntervalSince1970;
    NSInteger value2TimeInterval = value2.timeIntervalSince1970;
    
    if (value1TimeInterval > value2TimeInterval)
        return NSOrderedDescending;
    else if (value1TimeInterval < value2TimeInterval)
        return NSOrderedAscending;
    else
        return NSOrderedSame;
}

#pragma mark - Serializer
/**
 Serialize document.
 
 Member of document format:
 [K]<0xFFFFFFFF>{key}[SNTLDA]<0xFFFFFFFF>{value}
 (length)
 
 @param document: NSDictionary
 @return: NSData
 */
NYARU_BURST_LINK NSData *serialize(NSDictionary *document)
{
    NSString *key;  // key of the document
    id value;       // value of the document
    unsigned char *buffer = NULL;       // result data buffer
    NSUInteger bufferLength = 0U;       // buffer length
    NSData *dataKey;                        // key data
    unsigned char valueType;            // value type [SNTL]
    unsigned char *bufferValue;         // value buffer
    unsigned bufferValueLength = 0U;   // value bugger length
    
    // content
    for (key in document.allKeys) {
        // key of the document should be NSString and not empty
        if (![key isKindOfClass:NSString.class] || key.length == 0U) { continue; }
        
        value = document[key];
        
        // value of the document should be NSString, NSDate, NSNull or NSNumber
        if ([value isKindOfClass:NSString.class]) {
            valueType = 'S';
            bufferValue = serializeString(&bufferValueLength, value);
        }
        else if ([value isKindOfClass:NSDate.class]) {
            valueType = 'T';
            bufferValue = serializeDate(&bufferValueLength, value);
        }
        else if ([value isKindOfClass:NSNull.class]) {
            valueType = 'L';
            bufferValueLength = 0U;
        }
        else if ([value isKindOfClass:NSNumber.class]) {
            valueType = 'N';
            bufferValue = serializeNumber(&bufferValueLength, value);
        }
        else if ([value isKindOfClass:NSDictionary.class]) {
            valueType = 'D';
            NSData *dictData = serialize(value);
            bufferValueLength = (unsigned)dictData.length;
            bufferValue = malloc(bufferValueLength);
            memcpy(bufferValue, dictData.bytes, bufferValueLength);
        }
        else if ([value isKindOfClass:NSArray.class]) {
            // items just allow NSString, NSNumber, NSDate and NSNull in the array
            valueType = 'A';
            bufferValue = serializeArray(&bufferValueLength, value);
        }
        else {
            // value datatype failed
            continue;
        }
        
        // get nsdata of key
        dataKey = [key dataUsingEncoding:NSUTF8StringEncoding];
        unsigned dataKeyLength = (unsigned)dataKey.length;
        
        // realloc
        NSUInteger offset = bufferLength;
        bufferLength += dataKeyLength + bufferValueLength + 10U;
        buffer = reallocf(buffer, bufferLength);
        
        // set format
        buffer[offset] = 'K';
        memcpy(&buffer[offset + 1U], &dataKeyLength, sizeof(unsigned));
        buffer[offset + dataKeyLength + 5U] = valueType;
        memcpy(&buffer[offset + dataKeyLength + 6U], &bufferValueLength, sizeof(unsigned));
        
        // copy key
        memcpy(&buffer[offset + 5U], dataKey.bytes, dataKey.length);
        // copy value
        memcpy(&buffer[offset + dataKeyLength + 10U], bufferValue, bufferValueLength);
        
        // free
        if (bufferValueLength > 0) {
            free(bufferValue);
        }
    }
    
    NSData *result = [NSData dataWithBytes:buffer length:bufferLength];
    free(buffer);
    return result;
}
NYARU_BURST_LINK unsigned char *serializeString(unsigned *length, NSString *source)
{
    NSData *data = [source dataUsingEncoding:NSUTF8StringEncoding];
    *length = (unsigned)data.length;
    unsigned char *buffer = malloc(*length);
    memcpy(buffer, data.bytes, *length);
    
    return buffer;
}
NYARU_BURST_LINK unsigned char *serializeDate(unsigned *length, NSDate *source)
{
    double data = [source timeIntervalSince1970];
    *length = 8U;
    unsigned char *buffer = malloc(8U);
    memcpy(buffer, &data, 8U);
    
    return buffer;
}
NYARU_BURST_LINK unsigned char *serializeNumber(unsigned *length, NSNumber *source)
{
    CFNumberRef dataNumber = (__bridge CFNumberRef)source;
    *length = (unsigned)CFNumberGetByteSize(dataNumber) + 1U;
    CFNumberType numberType = CFNumberGetType(dataNumber);
    unsigned char *tempData = malloc(*length - 1U);
    CFNumberGetValue(dataNumber, numberType, tempData);
    
    unsigned char *buffer = malloc(*length);
    buffer[0U] = numberType;
    memcpy(&buffer[1U], tempData, *length - 1U);
    free(tempData);
    
    return buffer;
}
NYARU_BURST_LINK unsigned char *serializeArray(unsigned *length, NSArray *source)
{
    *length = 0U;
    unsigned char *buffer = NULL;
    unsigned itemLength = 0U;
    unsigned char itemType;
    for (id item in source) {
        unsigned char *itemData = NULL;
        
        if ([item isKindOfClass:NSString.class]) {
            itemType = 'S';
            itemData = serializeString(&itemLength, item);
        }
        else if ([item isKindOfClass:NSDate.class]) {
            itemType = 'T';
            itemData = serializeDate(&itemLength, item);
        }
        else if ([item isKindOfClass:NSNumber.class]) {
            itemType = 'N';
            itemData = serializeNumber(&itemLength, item);
        }
        else if ([item isKindOfClass:NSNull.class]) {
            itemType = 'L';
            itemLength = 0U;
        }
        else { continue; }
        
        NSUInteger offset = *length;
        *length += itemLength + 5U;
        if (offset == 0U) {  // first item
            buffer = malloc(*length);
        }
        else {
            buffer = reallocf(buffer, *length);
        }
        buffer[offset] = itemType;
        memcpy(&buffer[offset + 1U], &itemLength, sizeof(unsigned));
        memcpy(&buffer[offset + 5U], itemData, itemLength);
        
        if (itemLength == 0U) { continue; }
        free(itemData);
    }
    return buffer;
}
/**
 Deserialize document.
 
 Member of document format:
 [K]<0xFFFFFFFF>{key}[SNTLDA]<0xFFFFFFFF>{value}
 
 @param data: NSData
 @return: NSMutableDictionary
 */
NYARU_BURST_LINK NSMutableDictionary *deserialize(NSData *data)
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    const unsigned char *content = data.bytes;
    NSString *key;
    unsigned keyLength = 0U;
    unsigned char valueType;
    unsigned valueLength = 0U;
    NSUInteger index = 0U;
    unsigned char *tempData;
    NSMutableDictionary *tempDictionary;
    
    while (index < data.length) {
        if (content[index] == 'K') {
            // fetch key length
            memcpy(&keyLength, &content[index + 1U], sizeof(unsigned));
            // fetch key
            tempData = malloc(keyLength);
            memcpy(tempData, &content[index + 5U], keyLength);
            key = [[NSString alloc] initWithBytes:tempData length:keyLength encoding:NSUTF8StringEncoding];
            free(tempData);
            
            // fetch value length
            memcpy(&valueLength, &content[index + keyLength + 6U], sizeof(unsigned));
            // fetch value
            valueType = content[index + keyLength + 5U];
            switch (valueType) {
                case 'S':   // NSString
                    [result setObject:deserializeString(content, index, keyLength, valueLength) forKey:key];
                    break;
                case 'T':   // NSDate
                    [result setObject:deserializeDate(content, index, keyLength, valueLength) forKey:key];
                    break;
                case 'L':   // NSNull
                    [result setObject:[NSNull null] forKey:key];
                    break;
                case 'N':   // NSNumber
                    [result setObject:deserializeNumber(content, index, keyLength, valueLength) forKey:key];
                    break;
                case 'D':   // NSDictionary
                    if (valueLength <= 0U) {
                        [result setObject:[NSMutableDictionary new] forKey:key];
                        break;
                    }
                    tempData = malloc(valueLength);
                    memcpy(tempData, &content[index + keyLength + 10U], valueLength);
                    tempDictionary = deserialize([NSData dataWithBytes:tempData length:valueLength]);
                    [result setObject:tempDictionary forKey:key];
                    free(tempData);
                    break;
                case 'A':   // NSArray
                    [result setObject:deserializeArray(content, index, keyLength, valueLength) forKey:key];
                    break;
            }
            
            index += keyLength + valueLength + 10U;
            continue;
        }
        index++;
    }
    
    return result;
}
NYARU_BURST_LINK NSString *deserializeString(const unsigned char *content, NSUInteger offset, unsigned keyLength, unsigned valueLength)
{
    if (valueLength <= 0U) {
        return @"";
    }
    unsigned char *tempData = malloc(valueLength);
    memcpy(tempData, &content[offset + keyLength + 10U], valueLength);
    NSString *result = [[NSString alloc] initWithBytes:tempData length:valueLength encoding:NSUTF8StringEncoding];
    free(tempData);
    return result;
}
NYARU_BURST_LINK NSDate *deserializeDate(const unsigned char *content, NSUInteger offset, unsigned keyLength, unsigned valueLength)
{
    double tempDouble = 0.0;
    memcpy(&tempDouble, &content[offset + keyLength + 10U], sizeof(double));
    NSDate *result = [NSDate dateWithTimeIntervalSince1970:tempDouble];
    return result;
}
NYARU_BURST_LINK NSNumber *deserializeNumber(const unsigned char *content, NSUInteger offset, unsigned keyLength, unsigned valueLength)
{
    if (valueLength <= 0U) { return @0; }
    
    unsigned char *tempData = malloc(valueLength);
    memcpy(tempData, &content[offset + keyLength + 11U], valueLength - 1U);
    NSNumber *result = (NSNumber *)CFBridgingRelease(CFNumberCreate(NULL, content[offset + keyLength + 10U], tempData));
    free(tempData);
    return result;
}
NYARU_BURST_LINK NSMutableArray *deserializeArray(const unsigned char *content, NSUInteger offset, unsigned keyLength, unsigned valueLength)
{
    if (valueLength <= 0U) {
        return [NSMutableArray new];
    }
    
    NSMutableArray *result = [NSMutableArray new];
    NSUInteger arrayOffset = offset + keyLength + 10U;
    NSUInteger arrayBound = arrayOffset + valueLength;
    
    while (arrayOffset <= arrayBound) {
        // fetch value length
        unsigned itemLength = 0U;
        memcpy(&itemLength, &content[arrayOffset + 1U], sizeof(unsigned));
        
        // fetch value
        switch (content[arrayOffset]) {
            case 'S':   // NSString
                [result addObject:deserializeArrayString(content, arrayOffset, itemLength)];
                break;
            case 'T':   // NSDate
                [result addObject:deserializeArrayDate(content, arrayOffset, itemLength)];
                break;
            case 'L':   // NSNull
                [result addObject:[NSNull null]];
                break;
            case 'N':   // NSNumber
                [result addObject:deserializeArrayNumber(content, arrayOffset, itemLength)];
                break;
        }
        arrayOffset += itemLength + 5U;
    }
    return result;
}
NYARU_BURST_LINK NSString *deserializeArrayString(const unsigned char *content, NSUInteger offset, unsigned valueLength)
{
    if (valueLength <= 0U) {
        return @"";
    }
    unsigned char *tempData = malloc(valueLength);
    memcpy(tempData, &content[offset + 5U], valueLength);
    NSString *result = [[NSString alloc] initWithBytes:tempData length:valueLength encoding:NSUTF8StringEncoding];
    free(tempData);
    return result;
}
NYARU_BURST_LINK NSDate *deserializeArrayDate(const unsigned char *content, NSUInteger offset, unsigned valueLength)
{
    double tempDouble = 0.0;
    memcpy(&tempDouble, &content[offset + 5U], sizeof(double));
    NSDate *result = [NSDate dateWithTimeIntervalSince1970:tempDouble];
    return result;
}
NYARU_BURST_LINK NSNumber *deserializeArrayNumber(const unsigned char *content, NSUInteger offset, unsigned valueLength)
{
    if (valueLength <= 0U) { return @0; }
    
    unsigned char *tempData = malloc(valueLength);
    memcpy(tempData, &content[offset + 6U], valueLength - 1U);
    NSNumber *result = (NSNumber *)CFBridgingRelease(CFNumberCreate(NULL, content[offset + 5U], tempData));
    free(tempData);
    return result;
}

#pragma mark - fetch
/**
 Fetch the document with NyaruKey and NSFileHandle.
 @param nyaruKey NyaruKey
 @param documentCache _documentCache
 @param fileDocument NSFileHandle
 @return NSMutableDictionary / nil
 */
NYARU_BURST_LINK NSMutableDictionary *fetchDocumentWithNyaruKey(NyaruKey *nyaruKey, NSCache *documentCache, NSFileHandle *fileDocument)
{
    NSMutableDictionary *result = [documentCache objectForKey:[NSNumber numberWithUnsignedInt:nyaruKey.documentOffset]];
    if (result) {
        // return document from cache
        return result;
    }
    
    @try {
        [fileDocument seekToFileOffset:nyaruKey.documentOffset];
        
        // read document data
        NSData *documentData = [fileDocument readDataOfLength:nyaruKey.documentLength];
        result = deserialize(documentData);
        [documentCache setObject:result forKey:[NSNumber numberWithUnsignedInt:nyaruKey.documentOffset]];
    }
    @catch (__unused NSException *exception) { }
    
    return result;
}


#pragma mark - Loader
/**
 Load database schema with file path.
 @param path schema file path
 @return NSMutableDictionary { key: schema name, value: NyaruSchema }
 */
NYARU_BURST_LINK NSMutableDictionary *loadSchema(NSString *path)
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned fileSize = [fileInfo[@"NSFileSize"] unsignedIntValue];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    
    [file seekToFileOffset:NYARU_HEADER_LENGTH];
    NSMutableData *data;
    unsigned offset;
    unsigned char length;
    while (file.offsetInFile < fileSize) {
        offset = (unsigned)file.offsetInFile;
        // get length of key
        data = [NSMutableData dataWithData:[file readDataOfLength:9U]];
        const unsigned char *buffer = data.bytes;
        memcpy(&length, &buffer[8], sizeof(unsigned char));
        
        // read data of schema name
        [data appendData:[file readDataOfLength:length]];
        
        NyaruSchema *schema = [[NyaruSchema alloc] initWithData:data andOffset:offset];
        [result setObject:schema forKey:schema.name];
        
        if (schema.nextOffsetInFile == 0U) {
            // this is last of schema
            break;
        }
        else {
            [file seekToFileOffset:schema.nextOffsetInFile];
        }
    }
    [file closeFile];
    
    return result;
}

/**
 Load indexes in this collection for search data.
 @param schemas _schemas
 @param clearedIndexBlock _clearedIndexBlock
 @param indexFilePath _indexFilePath
 @param documentFilePath _documentFilePath
 */
NYARU_BURST_LINK void loadIndex(NSMutableDictionary *schemas, NSMutableArray *clearedIndexBlock, NSString *indexFilePath, NSString *documentFilePath)
{
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:indexFilePath error:nil];
    unsigned size = [fileInfo[@"NSFileSize"] unsignedIntValue];
    NSFileHandle *fileIndex = [NSFileHandle fileHandleForReadingAtPath:indexFilePath];
    NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:documentFilePath];
    
    [fileIndex seekToFileOffset:NYARU_HEADER_LENGTH];
    while (fileIndex.offsetInFile < size) {
        // read index
        unsigned indexOffset = (unsigned)fileIndex.offsetInFile;
        unsigned documentOffset;
        unsigned documentLength = 0U;
        unsigned blockLength = 0U;
        NSData *indexData = [fileIndex readDataOfLength:12U];
        const unsigned char *buffer = indexData.bytes;
        
        memcpy(&documentLength, &buffer[4], sizeof(documentLength));
        if (documentLength == 0U) {
            [clearedIndexBlock addObject:[[NyaruIndexBlock alloc] initWithOffset:indexOffset andLength:blockLength]];
            continue;
        }
        memcpy(&documentOffset, buffer, sizeof(documentOffset));
        memcpy(&blockLength, &buffer[8], sizeof(blockLength));
        
        // read document
        [fileDocument seekToFileOffset:documentOffset];
        NSData *documentData = [fileDocument readDataOfLength:documentLength];
        NSDictionary *document = deserialize(documentData);
        
        for (NyaruSchema *schema in schemas.allValues) {
            if (schema.unique) {
                NyaruKey *key = [[NyaruKey alloc] initWithIndexOffset:indexOffset
                                                       documentOffset:documentOffset
                                                       documentLength:documentLength
                                                          blockLength:blockLength];
                [schema pushNyaruKey:document[NYARU_KEY] nyaruKey:key];
            }
            else {
                [schema pushNyaruIndex:document[NYARU_KEY] value:document[schema.name]];
            }
        }
    }
    
    [fileIndex closeFile];
    [fileDocument closeFile];
}

/**
 Load indexes in this collection for search data.
 This method will be invoked when user created a new Index.
 @param schema the new schema
 @param schemas _schemas
 @param clearedIndexBlock _clearedIndexBlock
 @param indexFilePath _indexFilePath
 @param documentFilePath _documentFilePath
 */
NYARU_BURST_LINK void loadIndexForSchema(NyaruSchema *schema, NSMutableDictionary *schemas, NSMutableArray *clearedIndexBlock, NSString *indexFilePath, NSString *documentFilePath)
{
    if (schema.unique) {
        // first schema 'key'
        return;
    }
    
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:indexFilePath error:nil];
    unsigned size = [fileInfo[@"NSFileSize"] unsignedIntValue];
    NSFileHandle *fileIndex = [NSFileHandle fileHandleForReadingAtPath:indexFilePath];
    NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:documentFilePath];
    
    [fileIndex seekToFileOffset:NYARU_HEADER_LENGTH];
    while (fileIndex.offsetInFile < size) {
        // read index
        unsigned indexOffset = (unsigned)fileIndex.offsetInFile;
        unsigned documentOffset;
        unsigned documentLength = 0U;
        unsigned blockLength = 0U;
        NSData *indexData = [fileIndex readDataOfLength:12U];
        const unsigned char *buffer = indexData.bytes;
        
        memcpy(&documentLength, &buffer[4], sizeof(documentLength));
        if (documentLength == 0U) {
            [clearedIndexBlock addObject:[[NyaruIndexBlock alloc] initWithOffset:indexOffset andLength:blockLength]];
            continue;
        }
        memcpy(&documentOffset, buffer, sizeof(documentOffset));
        memcpy(&blockLength, &buffer[8], sizeof(blockLength));
        
        // read document
        [fileDocument seekToFileOffset:documentOffset];
        NSData *documentData = [fileDocument readDataOfLength:documentLength];
        NSDictionary *document = deserialize(documentData);
        
        [schema pushNyaruIndex:document[NYARU_KEY] value:document[schema.name]];
    }
    
    [fileIndex closeFile];
    [fileDocument closeFile];
}

#pragma mark - Others
/**
 Get the last schema
 @param _schemas
 @return NyaruSchema / nil
 */
NYARU_BURST_LINK NyaruSchema *getLastSchema(NSDictionary *allSchemas)
{
    for (NyaruSchema *schema in allSchemas.allValues) {
        if (schema.nextOffsetInFile == 0U) {
            return schema;
        }
    }
    
    return nil;
}

/**
 Check file's header match NyaruDB.
 @param patch file patch
 @return YES / NO
 */
NYARU_BURST_LINK BOOL isNyaruHeaderOK(NSString *path)
{
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *header = [fileHandle readDataOfLength:NYARU_HEADER_LENGTH];
    [fileHandle closeFile];
    return [header isEqualToData:[NYARU_HEADER dataUsingEncoding:NSUTF8StringEncoding]];
}

/**
 Is file exist then delete it.
 @param path file path
 */
NYARU_BURST_LINK void fileDelete(NSString *path)
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
        if (error) {
            @throw [NSException exceptionWithName:NYARU_DOCUMENT reason:error.description userInfo:error.userInfo];
        }
    }
}

@end
