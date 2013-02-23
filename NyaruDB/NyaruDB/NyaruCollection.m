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


@implementation NyaruCollection

@synthesize name = _name;

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
        if (name == nil || name.length == 0) {
            @throw([NSException exceptionWithName:NYARU_PRODUCT reason:@"name is nil or empty." userInfo:nil]);
        }
        
        _name = name;
        _idCount = 0;
        _accessQueue = dispatch_queue_create([[NSString stringWithFormat:@"NyaruDB.Access.%@", name] cStringUsingEncoding:NSUTF8StringEncoding], NULL);
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
    if (indexName == nil || indexName.length == 0) { return; }
    
    dispatch_async(_accessQueue, ^{
        // check exist
        if ([_schemas objectForKey:indexName]) { return; }
        
        NyaruSchema *lastSchema = getLastSchema(_schemas);
        unsigned int previous = 0;
        if (lastSchema) {
            previous = lastSchema.offsetInFile;
        }
        
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:_schemaFilePath];
        NyaruSchema *schema = [[NyaruSchema alloc] initWithName:indexName previousOffser:previous nextOffset:0];
        schema.offsetInFile = [file seekToEndOfFile];
        [file writeData:schema.dataFormate];
        
        if (lastSchema) {
            // update last schema's next offset
            lastSchema.nextOffsetInFile = schema.offsetInFile;
            unsigned int offset = schema.offsetInFile;
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
        NyaruSchema *schema = [_schemas objectForKey:indexName];
        if (schema) {
            NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:_schemaFilePath];
            unsigned int offset;
            if (schema.previousOffsetInFile > 0) {
                // set next offset of previous schema
                offset = schema.nextOffsetInFile;
                [file seekToFileOffset:schema.previousOffsetInFile + 4];
                [file writeData:[NSData dataWithBytes:&offset length:sizeof(offset)]];
            }
            else if (schema.nextOffsetInFile > 0) {
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
    for (NSString *index in [self allIndexes]) {
        if ([index isEqualToString:NYARU_KEY]) { continue; }
        [self removeIndex:index];
    }
}


#pragma mark - Document
- (NSMutableDictionary *)insert:(NSDictionary *)document
{
    if (document == nil) {
        @throw [NSException exceptionWithName:NYARU_PRODUCT reason:@"document could not be nil." userInfo:nil];
        return nil;
    }
    
    NSMutableDictionary *doc = [NSMutableDictionary dictionaryWithDictionary:document];
    if ([[doc objectForKey:NYARU_KEY] isKindOfClass:NSNull.class] || ((NSString *)[doc objectForKey:NYARU_KEY]).length == 0) {
        static const char map[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
        char *keyPrefix = malloc(9);
        NSUInteger selector;
        for (NSUInteger index = 0; index < 8; index++) {
            selector = arc4random() % 52;
            keyPrefix[index] = map[selector];
        }
        keyPrefix[8] = '\0';
        
        time_t t;
        time(&t);
        mktime(gmtime(&t));
        t = ((t << 16) & 0x7FFFFFFF) | (_idCount++ & 0xFFFF);
        [doc setObject:[NSString stringWithFormat:@"%s%lu", keyPrefix, t] forKey:NYARU_KEY];
        free(keyPrefix);
    }
    
    // serialize document
    __block NSData *docData = doc.JSONDataN;
    
    if (docData.length == 0) {
        @throw [NSException exceptionWithName:NYARU_PRODUCT reason:@"document serialized failed." userInfo:nil];
        return nil;
    }
    
    // check key is exist
    if ([((NyaruSchema *)[_schemas objectForKey:NYARU_KEY]).allKeys objectForKey:[doc objectForKey:NYARU_KEY]]) {
        @throw([NSException exceptionWithName:NYARU_PRODUCT reason:[NSString stringWithFormat:@"key '%@' is exist.", [doc objectForKey:NYARU_KEY]] userInfo:nil]);
        return nil;
    }
    
    // write data with GCD
    dispatch_async(_accessQueue, ^(void) {
        // io handle
        __block NSFileHandle *fileDocument = [NSFileHandle fileHandleForWritingAtPath:_documentFilePath];
        __block NSFileHandle *fileIndex = [NSFileHandle fileHandleForUpdatingAtPath:_indexFilePath];
        
        unsigned int documentOffset = 0;
        unsigned int documentLength = docData.length;
        unsigned int blockLength = 0;
        unsigned int indexOffset = 0;
        
        // get index offset
        for (NSUInteger blockIndex = 0; blockIndex < _clearedIndexBlock.count; blockIndex++) {
            NyaruIndexBlock *block = [_clearedIndexBlock objectAtIndex:blockIndex];
            if (block.blockLength >= documentLength) {
                // old document block could be reuse
                indexOffset = block.indexOffset;
                
                // read old document block offset
                [fileIndex seekToFileOffset:indexOffset];
                NSData *documentOffsetData = [fileIndex readDataOfLength:4];
                [documentOffsetData getBytes:&documentOffset length:sizeof(documentOffset)];
                [fileDocument seekToFileOffset:documentOffset];
                
                // if reuse document block, update index data
                [fileIndex seekToFileOffset:indexOffset];
                
                [_clearedIndexBlock removeObjectAtIndex:blockIndex];
                break;
            }
        }
        if (indexOffset == 0) {
            documentOffset = [fileDocument seekToEndOfFile];
            indexOffset = [fileIndex seekToEndOfFile];
            blockLength = documentLength;
        }
        
        // push key and index
        for (NyaruSchema *schema in _schemas.allValues) {
            if (schema.unique) {
                NyaruKey *key = [[NyaruKey alloc] initWithIndexOffset:indexOffset
                                                       documentOffset:documentOffset
                                                       documentLength:documentLength
                                                          blockLength:blockLength];
                [schema pushNyaruKey:[doc objectForKey:NYARU_KEY] nyaruKey:key];
            }
            else {
                [schema pushNyaruIndex:[doc objectForKey:NYARU_KEY] value:[doc objectForKey:schema.name]];
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
- (void)waiteForWriting
{
    dispatch_sync(_accessQueue, ^{ });
}
- (void)removeByKey:(NSString *)documentKey
{
    dispatch_async(_accessQueue, ^(void) {
        NyaruKey *nyaruKey = [[(NyaruSchema *)[_schemas objectForKey:NYARU_KEY] allKeys] objectForKey:documentKey];
        if (!nyaruKey) { return; }
        
        // remove cache
        [_documentCache removeObjectForKey:[NSNumber numberWithUnsignedInt:nyaruKey.documentOffset]];
        
        NSFileHandle *fileIndex = [NSFileHandle fileHandleForWritingAtPath:_indexFilePath];
        @try {
            unsigned int data = 0;
            [fileIndex seekToFileOffset:nyaruKey.indexOffset + 4];
            [fileIndex writeData:[NSData dataWithBytes:&data length:sizeof(data)]];
            [_clearedIndexBlock addObject:[NyaruIndexBlock indexBlockWithOffset:nyaruKey.indexOffset andLength:nyaruKey.blockLength]];
            
            for (NyaruSchema *schema in _schemas.allValues) {
                [schema removeWithKey:documentKey];
            }
        }
        @catch (NSException *exception) { }
        [fileIndex closeFile];
    });
}
- (void)removeByQuery:(NSArray *)queries
{
    dispatch_async(_accessQueue, ^(void) {
        NSArray *documentKeys = nyaruKeysForNyaruQueries(_schemas, queries, NO);
        NSDictionary *keyMap = [(NyaruSchema *)[_schemas objectForKey:NYARU_KEY] allKeys];
        NSFileHandle *fileIndex = [NSFileHandle fileHandleForWritingAtPath:_indexFilePath];
        
        for (NSString *documentKey in documentKeys) {
            NyaruKey *nyaruKey = [keyMap objectForKey:documentKey];
            
            // remove cache
            [_documentCache removeObjectForKey:[NSNumber numberWithUnsignedInt:nyaruKey.documentOffset]];
            
            @try {
                unsigned int data = 0;
                [fileIndex seekToFileOffset:nyaruKey.indexOffset + 4];
                [fileIndex writeData:[NSData dataWithBytes:&data length:sizeof(data)]];
                [_clearedIndexBlock addObject:[NyaruIndexBlock indexBlockWithOffset:nyaruKey.indexOffset andLength:nyaruKey.blockLength]];
                
                for (NyaruSchema *schema in _schemas.allValues) {
                    [schema removeWithKey:documentKey];
                }
            }
            @catch (NSException *exception) { }
        }
        [fileIndex closeFile];
    });
}
- (void)removeAll
{
    // write data with GCD
    dispatch_async(_accessQueue, ^(void) {
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


#pragma mark - Fetch
- (NSArray *)fetchByQuery:(NSArray *)queries skip:(NSUInteger)skip limit:(NSUInteger)limit
{
    __block NSMutableArray *result;
    dispatch_sync(_accessQueue, ^(void) {
        NSUInteger fetchLimit = limit;
        NSArray *keys = nyaruKeysForNyaruQueries(_schemas, queries, YES);
        NSMutableDictionary *item;
        fetchLimit += skip;
        if (fetchLimit == 0) { fetchLimit = keys.count; }
        else if (fetchLimit > keys.count) { fetchLimit = keys.count; }
    
        NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:_documentFilePath];
        
        result = [[NSMutableArray alloc] initWithCapacity:fetchLimit];
        for (NSUInteger index = skip; index < fetchLimit; index++) {
            item = fetchDocumentWithNyaruKey([keys objectAtIndex:index], _documentCache, fileDocument);
            if (item) { [result addObject:item]; }
        }
        [fileDocument closeFile];
    });
    
    return result;
}
- (NSArray *)fetchKeyByQuery:(NSArray *)queries skip:(NSUInteger)skip limit:(NSUInteger)limit
{
    __block NSArray *result;
    dispatch_sync(_accessQueue, ^(void) {
        NSArray *keys = nyaruKeysForNyaruQueries(_schemas, queries, NO);
        if (skip == 0 && limit == keys.count) {
            // fetch all
            result = keys;
            return;
        }
        
        NSUInteger fetchLimit = limit;
        fetchLimit += skip;
        if (fetchLimit == 0) { fetchLimit = keys.count; }
        else if (fetchLimit > keys.count) { fetchLimit = keys.count; }
        
        NSMutableArray *resultTemp = [[NSMutableArray alloc] initWithCapacity:fetchLimit];
        for (NSUInteger index = skip; index < fetchLimit; index++) {
            [resultTemp addObject:[keys objectAtIndex:index]];
        }
        result = resultTemp;
    });
    
    return result;
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
    return [query unionAll];
}
- (NyaruQuery *)where:(NSString *)indexName equalTo:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query union:indexName equalTo:value];
}
- (NyaruQuery *)where:(NSString *)indexName notEqualTo:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query union:indexName notEqualTo:value];
}
- (NyaruQuery *)where:(NSString *)indexName lessThan:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query union:indexName lessThan:value];
}
- (NyaruQuery *)where:(NSString *)indexName lessEqualThan:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query union:indexName lessEqualThan:value];
}
- (NyaruQuery *)where:(NSString *)indexName greaterThan:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query union:indexName greaterThan:value];
}
- (NyaruQuery *)where:(NSString *)indexName greaterEqualThan:(id)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query union:indexName greaterEqualThan:value];
}
- (NyaruQuery *)where:(NSString *)indexName likeTo:(NSString *)value
{
    NyaruQuery *query = [[NyaruQuery alloc] initWithCollection:self];
    return [query union:indexName likeTo:value];
}


#pragma mark - Count
- (NSUInteger)count
{
    __block NSUInteger result;
    dispatch_sync(_accessQueue, ^(void) {
        result = [[_schemas objectForKey:NYARU_KEY] allKeys].count;
    });
    return result;
}
- (NSUInteger)countByQuery:(NSArray *)queries
{
    __block NSUInteger result;
    dispatch_sync(_accessQueue, ^(void) {
        result = nyaruKeysForNyaruQueries(_schemas, queries, NO).count;
    });
    return result;
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
    dispatch_sync(_accessQueue, ^(void) {
        for (NyaruSchema *schema in _schemas.allValues) {
            [schema close];
        }
        [_documentCache removeAllObjects];
        [_schemas removeAllObjects];
        [_clearedIndexBlock removeAllObjects];
    });
    dispatch_release(_accessQueue);
}

#pragma mark Schema
- (NSMutableDictionary *)schemas
{
    return _schemas;
}


#pragma mark - Private methods
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
        NyaruSchema *schema = [schemas objectForKey:query.schemaName];
        
        if (query.operation == (NyaruQueryAll | NyaruQueryUnion)) {
            // union all
            if (queries.count == 1) {
                // high speed return all NyaruKeys
                if (isReturnNyaruKey) {
                    return [(NyaruSchema *)[schemas objectForKey:NYARU_KEY] allKeys].allValues;
                }
                else {
                    return [(NyaruSchema *)[schemas objectForKey:NYARU_KEY] allKeys].allKeys;
                }
            }
            else {
                [resultKeys addObjectsFromArray:[(NyaruSchema *)[schemas objectForKey:NYARU_KEY] allKeys].allKeys];
            }
        }
        else if (schema == nil) { continue; }
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
        keyMap = [(NyaruSchema *)[schemas objectForKey:NYARU_KEY] allKeys];
    }
    
    if (sortQuery) {
        // sort result and map document.key to NyaruKey
        NyaruSchema *nyaruSchema = [schemas objectForKey:sortQuery.schemaName];
        if (nyaruSchema) {
            NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:resultKeys.count];
            NSArray *sortedMap = nyaruKeysWithSortByIndexValue(nyaruSchema, sortQuery);
            if (isReturnNyaruKey) {
                // map document.key to NyaruKey
                for (NSString *key in sortedMap) {
                    if ([resultKeys intersectsSet:[NSSet setWithObject:key]]) {
                        [result addObject:[keyMap objectForKey:key]];
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
            [result addObject:[keyMap objectForKey:key]];
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
            NyaruKey *key = [schema.allKeys objectForKey:query.value];
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
    else if (query.value == nil) { queryType = NyaruSchemaTypeNil; query.value = [NSNull null]; }
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
                    [result addObject:[[index keySet] allObjects]];
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
                    [result addObject:[[index keySet] allObjects]];
                }
            }
            else { return filterGreater(schema.allNotNilIndexes, query.value, queryType, NO); }
            break;
        case NyaruQueryGreaterEqual:
            if (queryType == NyaruSchemaTypeNil) {
                [result addObjectsFromArray:schema.allNilIndexes];
                for (NyaruIndex *index in schema.allNotNilIndexes) {
                    [result addObject:[[index keySet] allObjects]];
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
    }
    
    return result;
}
/**
 Get all NyaruIndexe.key in the schema and sort these by NyaruIndex.value.
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
            for (NSString *key in [[index keySet] allObjects]) {
                [result insertObject:key atIndex:0];
            }
        }
        [result addObjectsFromArray:schema.allNilIndexes];
    }
    else {
        // ASC
        [result addObjectsFromArray:schema.allNilIndexes];
        for (NyaruIndex *index in schema.allNotNilIndexes) {
            [result addObjectsFromArray:[[index keySet] allObjects]];
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
    if (range.length > 0) {
        // found equal value
        return [[allIndexes objectAtIndex:range.location] keySet].allObjects;
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
    if (range.length > 0) {
        // found equal value
        NSUInteger max = range.location == NSUIntegerMax ? allIndexes.count : range.location;
        for (NSUInteger index = 0; index < max; index++) {
            [result addObjectsFromArray:[[allIndexes objectAtIndex:index] keySet].allObjects];
        }
        for (NSUInteger index = range.location + range.length; index < allIndexes.count; index++) {
            [result addObjectsFromArray:[[allIndexes objectAtIndex:index] keySet].allObjects];
        }
    }
    else {
        // no equal value
        for (NyaruIndex *index in allIndexes) {
            [result addObjectsFromArray:index.keySet.allObjects];
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
    if (range.location == NSUIntegerMax && range.length == 0) { return result; }
    
    if (range.location != NSUIntegerMax && range.location != 0) {
        NSUInteger max = range.length > 0 ? range.location - 1 : range.location;
        for (NSUInteger index = 0; index <= max; index++) {
            // add less datas
            [result addObjectsFromArray:[[allIndexes objectAtIndex:index] keySet].allObjects];
        }
    }
    
    if (includeEqual && range.length > 0) {
        // add equal datas
        [result addObjectsFromArray:[[allIndexes objectAtIndex:range.location] keySet].allObjects];
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
    if (range.location == allIndexes.count && range.length == 0 && !includeEqual) { return result; }
    if (range.location == NSUIntegerMax && range.length == 0) {
        // all data is greater
        for (NSUInteger index = 0; index < allIndexes.count; index++) {
            // add greater datas
            [result addObjectsFromArray:[[allIndexes objectAtIndex:index] keySet].allObjects];
        }
        return result;
    }
    
    for (NSUInteger index = range.location + 1; index < allIndexes.count; index++) {
        // add greater datas
        [result addObjectsFromArray:[[allIndexes objectAtIndex:index] keySet].allObjects];
    }
    
    if (includeEqual && range.length > 0) {
        // add equal datas
        [result addObjectsFromArray:[[allIndexes objectAtIndex:range.location] keySet].allObjects];
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
 */
NYARU_BURST_LINK NSRange findEqualRange(NSArray *array, id target, NyaruSchemaType type)
{
    NSComparisonResult compResult;
    
    // array.count : 0 ~ 1
    switch (array.count) {
        case 0:
            return NSMakeRange(NSUIntegerMax, 0);
        case 1:
            compResult = compare([[array objectAtIndex:0] value], target, type);
            // target < array[0]
            if (compResult == NSOrderedDescending) { return NSMakeRange(NSUIntegerMax, 0); }
            // target == array[0]
            else if (compResult == NSOrderedSame) { return NSMakeRange(0, 1); }
            // target > array[0]
            else { return NSMakeRange(0, 0); }
    }
    
    // compare the first
    compResult = compare([[array objectAtIndex:0] value], target, type);
    switch (compResult) {
        case NSOrderedSame:
            // target == array[0]
            return NSMakeRange(0, 1);
        case NSOrderedDescending:
            // target < array[0]
            return NSMakeRange(NSUIntegerMax, 0);
        case NSOrderedAscending: break;
    }
    // compare the last
    compResult = compare([[array lastObject] value], target, type);
    switch (compResult) {
        case NSOrderedSame:
            // index == array[last]
            return NSMakeRange(array.count - 1, 1);
        case NSOrderedAscending:
            // target > array[last]
            return NSMakeRange(array.count - 1, 0);
        case NSOrderedDescending: break;
    }
    
    NSUInteger upBound = 1;
    NSUInteger downBound = array.count - 2;
    NSUInteger targetIndex = (upBound + downBound) / 2;
    
    while (upBound <= downBound) {
        compResult = compare([[array objectAtIndex:targetIndex] value], target, type);
        
        switch (compResult) {
            case NSOrderedSame:
                // target == array[targetIndex]
                return NSMakeRange(targetIndex, 1);
            case NSOrderedDescending:
                // index.value < array[targetIndex]
                downBound = targetIndex - 1;
                targetIndex = (upBound + downBound) / 2;
                break;
            case NSOrderedAscending:
                // index.value > array[targetIndex]
                upBound = targetIndex + 1;
                targetIndex = (upBound + downBound) / 2;
                if (targetIndex < upBound) { targetIndex = upBound; }
                break;
        }
    }
    
    // did not find the same value in the array.
    return NSMakeRange(upBound, 0);
}
#pragma mark compare value1 and value2
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
#pragma mark fetch
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
        result = documentData.mutableObjectFromJSONDataN;
        [documentCache setObject:result forKey:[NSNumber numberWithUnsignedInt:nyaruKey.documentOffset]];
    }
    @catch (NSException *exception) { }
    
    return result;
}


#pragma mark - Private methods
/**
 Load database schema with file path.
 @param path schema file path
 @return NSMutableDictionary { key: schema name, value: NyaruSchema }
 */
NYARU_BURST_LINK NSMutableDictionary *loadSchema(NSString *path)
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSUInteger fileSize = [[fileInfo objectForKey:@"NSFileSize"] unsignedIntegerValue];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    
    [file seekToFileOffset:NYARU_HEADER_LENGTH];
    NSMutableData *data;
    unsigned int offset;
    unsigned char length;
    while (file.offsetInFile < fileSize) {
        offset = file.offsetInFile;
        // get length of key
        data = [NSMutableData dataWithData:[file readDataOfLength:9]];
        [[data subdataWithRange:NSMakeRange(8, 1)] getBytes:&length length:1];
        
        // read data of schema name
        [data appendData:[file readDataOfLength:length]];
        
        NyaruSchema *schema = [[NyaruSchema alloc] initWithData:data andOffset:offset];
        [result setObject:schema forKey:schema.name];
        
        if (schema.nextOffsetInFile == 0) {
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
    unsigned int size = [[fileInfo objectForKey:@"NSFileSize"] unsignedIntegerValue];
    NSFileHandle *fileIndex = [NSFileHandle fileHandleForReadingAtPath:indexFilePath];
    NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:documentFilePath];
    
    [fileIndex seekToFileOffset:NYARU_HEADER_LENGTH];
    while (fileIndex.offsetInFile < size) {
        // read index
        unsigned int indexOffset = fileIndex.offsetInFile;
        unsigned int documentOffset;
        unsigned int documentLength = 0;
        unsigned int blockLength = 0;
        NSData *indexData = [fileIndex readDataOfLength:12];
        
        [[indexData subdataWithRange:NSMakeRange(4, 4)] getBytes:&documentLength length:sizeof(documentLength)];
        if (documentLength == 0) {
            [clearedIndexBlock addObject:[NyaruIndexBlock indexBlockWithOffset:indexOffset andLength:blockLength]];
            continue;
        }
        [[indexData subdataWithRange:NSMakeRange(0, 4)] getBytes:&documentOffset length:sizeof(documentOffset)];
        [[indexData subdataWithRange:NSMakeRange(8, 4)] getBytes:&blockLength length:sizeof(blockLength)];
        
        // read document
        [fileDocument seekToFileOffset:documentOffset];
        NSData *documentData = [fileDocument readDataOfLength:documentLength];
        NSDictionary *document = documentData.mutableObjectFromJSONDataN;
        
        for (NyaruSchema *schema in schemas.allValues) {
            if (schema.unique) {
                NyaruKey *key = [[NyaruKey alloc] initWithIndexOffset:indexOffset
                                                       documentOffset:documentOffset
                                                       documentLength:documentLength
                                                          blockLength:blockLength];
                [schema pushNyaruKey:[document objectForKey:NYARU_KEY] nyaruKey:key];
            }
            else {
                [schema pushNyaruIndex:[document objectForKey:NYARU_KEY] value:[document objectForKey:schema.name]];
            }
        }
    }
    
    [fileIndex closeFile];
    [fileDocument closeFile];
}

/**
 Load indexes in this collection for search data.
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
    unsigned int size = [[fileInfo objectForKey:@"NSFileSize"] unsignedIntegerValue];
    NSFileHandle *fileIndex = [NSFileHandle fileHandleForReadingAtPath:indexFilePath];
    NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:documentFilePath];
    
    [fileIndex seekToFileOffset:NYARU_HEADER_LENGTH];
    while (fileIndex.offsetInFile < size) {
        // read index
        unsigned int indexOffset = fileIndex.offsetInFile;
        unsigned int documentOffset;
        unsigned int documentLength = 0;
        unsigned int blockLength = 0;
        NSData *indexData = [fileIndex readDataOfLength:12];
        
        [[indexData subdataWithRange:NSMakeRange(4, 4)] getBytes:&documentLength length:sizeof(documentLength)];
        if (documentLength == 0) {
            [clearedIndexBlock addObject:[NyaruIndexBlock indexBlockWithOffset:indexOffset andLength:blockLength]];
            continue;
        }
        [[indexData subdataWithRange:NSMakeRange(0, 4)] getBytes:&documentOffset length:sizeof(documentOffset)];
        [[indexData subdataWithRange:NSMakeRange(8, 4)] getBytes:&blockLength length:sizeof(blockLength)];
        
        // read document
        [fileDocument seekToFileOffset:documentOffset];
        NSData *documentData = [fileDocument readDataOfLength:documentLength];
        NSDictionary *document = documentData.mutableObjectFromJSONDataN;
        
        [schema pushNyaruIndex:[document objectForKey:NYARU_KEY] value:[document objectForKey:schema.name]];
    }
    
    [fileIndex closeFile];
    [fileDocument closeFile];
}

/**
 Get the last schema
 @param _schemas
 @return NyaruSchema / nil
 */
NYARU_BURST_LINK NyaruSchema *getLastSchema(NSDictionary *allSchemas)
{
    for (NyaruSchema *schema in allSchemas.allValues) {
        if (schema.nextOffsetInFile == 0) {
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
