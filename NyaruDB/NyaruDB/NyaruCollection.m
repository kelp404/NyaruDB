//
//  NyaruCollection.m
//  NyaruDB
//
//  Created by Kelp on 12/8/12.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import "NyaruCollection.h"


@interface NyaruCollection()
BURST_LINK BOOL isNyaruHeaderOK(NSString *path);
- (NSMutableDictionary *)loadSchema;
// load index while db init
- (void)loadIndex;
// load index while create a new schema
- (void)loadIndexForSchema:(NyaruSchema *)schema;

BURST_LINK NSMutableDictionary *documentForKey(NyaruKey *nyaruKey, NSFileHandle *fileDocument);
BURST_LINK NSArray *nyaruKeysForNyaruQueries(NSMutableDictionary *schemas, NSArray *queries);
BURST_LINK NSMutableArray *mapNyaruIndexForSort(NSMutableArray *allIndexes, NyaruQuery *query);
BURST_LINK NSMutableArray *mapNyaruIndex(NyaruSchema *schema, NyaruQuery *query);
BURST_LINK NSRange findEqualRange(NSMutableArray *pool, id reference, NyaruSchemaType schemaType);
BURST_LINK NSMutableArray *filterEqual(NSMutableArray *pool, id reference, NyaruSchemaType schemaType);
BURST_LINK NSMutableArray *filterUnequal(NSMutableArray *pool, id reference, NyaruSchemaType schemaType);
BURST_LINK NSMutableArray *filterLess(NSMutableArray *pool, id reference, NyaruSchemaType schemaType, BOOL includeEqual);
BURST_LINK NSMutableArray *filterGreater(NSMutableArray *pool, id reference, NyaruSchemaType schemaType, BOOL includeEqual);
BURST_LINK NSMutableArray *filterLike(NSMutableArray *pool, NSString *reference, NyaruSchemaType schemaType, NyaruQueryOperation operation);
BURST_LINK NSComparisonResult compare(id value1, id value2, NyaruSchemaType schemaType);
@end


@implementation NyaruCollection

@synthesize name = _name;

#pragma mark - ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
#pragma mark - Init
- (id)init
{
    self = [super init];
    if (self) {
        _schema = [NSMutableDictionary new];
        _clearedIndexBlock = [NSMutableArray new];
        _ioQueue = dispatch_queue_create("accuvally.NyaruDB", NULL);
    }
    return self;
}


#pragma mark - ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
#pragma mark - Collection
#pragma mark create a collection
- (id)initWithNewCollectionName:(NSString *)name databasePath:(NSString *)databasePath
{
    self = [self init];
    if (self) {
        if (name == nil || name.length == 0) {
            @throw([NSException exceptionWithName:NyaruDBNProduct reason:@"name is nil or empty." userInfo:nil]);
        }
        
        _indexFilePath = [[databasePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:NyaruIndexExtension];
        _schemaFilePath = [[databasePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:NyaruSchemaExtension];
        _documentFilePath = [[databasePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:NyaruDocumentExtension];
        _name = name;
        
        // check all file exists
        if ([[NSFileManager defaultManager] fileExistsAtPath:_documentFilePath] ||
            [[NSFileManager defaultManager] fileExistsAtPath:_indexFilePath] ||
            [[NSFileManager defaultManager] fileExistsAtPath:_schemaFilePath]) {
            
            return nil;
        }
        
        // create collection file
        NSError *error = nil;
        NSString *header = NyaruFileHeader;
        [header writeToFile:_documentFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NyaruDBNProduct reason:error.description userInfo:error.userInfo]);
        }
        [header writeToFile:_schemaFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NyaruDBNProduct reason:error.description userInfo:error.userInfo]);
        }
        [header writeToFile:_indexFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NyaruDBNProduct reason:error.description userInfo:error.userInfo]);
        }
        
        [self createSchema:NyaruConfig.key];
    }
    return self;
}

#pragma mark load a collection
- (id)initWithLoadCollectionName:(NSString *)name databasePath:(NSString *)databasePath
{
    self = [self init];
    if (self) {
        _indexFilePath = [[databasePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:NyaruIndexExtension];
        _schemaFilePath = [[databasePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:NyaruSchemaExtension];
        _documentFilePath = [[databasePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:NyaruDocumentExtension];
        _name = name;
        
        // check all file exists
        if ([[NSFileManager defaultManager] fileExistsAtPath:_documentFilePath] &&
            [[NSFileManager defaultManager] fileExistsAtPath:_indexFilePath] &&
            [[NSFileManager defaultManager] fileExistsAtPath:_schemaFilePath]) {
            
            // check file header
            BOOL headerOK = isNyaruHeaderOK(_indexFilePath);
            if (headerOK) {
                headerOK = isNyaruHeaderOK(_schemaFilePath);
            }
            if (headerOK) {
                headerOK = isNyaruHeaderOK(_documentFilePath);
            }
            if (!headerOK) {
                // header error
                return nil;
            }
            
            // load schema
            _schema = [self loadSchema];
            [self loadIndex];
        }
        else {
            return nil;
        }
    }
    return self;
}

#pragma mark Remove a Collection
- (void)remove
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:_documentFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:_documentFilePath error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:_indexFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:_indexFilePath error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:_schemaFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:_schemaFilePath error:nil];
    }
}


#pragma mark - ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
#pragma mark - Schema
#pragma mark get schemas
- (NSDictionary *)allSchemas
{
    return _schema;
}
- (NyaruSchema *)schemaForName:(NSString *)name
{
    return [_schema objectForKey:name];
}

#pragma mark create a schema
- (NyaruSchema *)createSchema:(NSString *)name
{
    if (name == nil || name.length == 0) {
        return nil;
    }
    
    // check exist
    if ([_schema objectForKey:name]) {
        return nil;
    }
    
    NyaruSchema *lastSchema = _schema.allValues.lastObject;
    unsigned int previous = 0;
    if (lastSchema) {
        previous = lastSchema.offset;
    }
    
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:_schemaFilePath];
    NyaruSchema *schema = [[NyaruSchema alloc] initWithName:name previousOffser:previous nextOffset:0];
    schema.offset = [file seekToEndOfFile];
    [file writeData:schema.dataFormate];
    
    if (lastSchema) {
        // update last schema's next offset
        unsigned int offset = schema.offset;
        [file seekToFileOffset:lastSchema.offset + 4];
        [file writeData:[NSData dataWithBytes:&offset length:sizeof(offset)]];
    }
    [file closeFile];
    
    [_schema setObject:schema forKey:schema.name];
    [self loadIndexForSchema:schema];
    
    return schema;
}

#pragma mark remove a schema
- (void)removeSchema:(NSString *)name
{
    if ([name isEqualToString:NyaruConfig.key]) {
        @throw([NSException exceptionWithName:NyaruDBNProduct reason:@"schema 'key' could not be remove." userInfo:nil]);
    }
    
    NyaruSchema *schema = [_schema objectForKey:name];
    if (schema) {
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:_schemaFilePath];
        unsigned int offset;
        if (schema.previousOffset > 0) {
            // set next offset of previous schema
            offset = schema.nextOffset;
            [file seekToFileOffset:schema.previousOffset + 4];
            [file writeData:[NSData dataWithBytes:&offset length:sizeof(offset)]];
        }
        else if (schema.nextOffset > 0) {
            // set previous offset of next schema
            offset = schema.previousOffset;
            [file seekToFileOffset:schema.nextOffset];
            [file writeData:[NSData dataWithBytes:&offset length:sizeof(offset)]];
        }
        [file closeFile];
        
        [_schema removeObjectForKey:name];
    }
}


#pragma mark - ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
#pragma mark - Document
#pragma mark Read
- (NSMutableDictionary *)documentForKey:(NSString *)key
{
    NyaruKey *nyaruKey = [[_schema objectForKey:NyaruConfig.key] indexForKey:key];
    
    if (nyaruKey) {
        NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:_documentFilePath];
        NSMutableDictionary *result = documentForKey(nyaruKey, fileDocument);
        [fileDocument closeFile];
        
        return result;
    }
    else {
        return nil;
    }
}
- (NSUInteger)count
{
    NyaruSchema *schema = [_schema objectForKey:NyaruConfig.key];
    return schema.allKeys.count;
}
- (NSUInteger)countForQueries:(NSArray *)query
{
    NSArray *resultKeys = nyaruKeysForNyaruQueries(_schema, query);
    
    return resultKeys.count;
}
- (NSArray *)documents
{
    NSMutableArray *result = [NSMutableArray new];
    
    NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:_documentFilePath];
    NSMutableDictionary *allKeys = ((NyaruSchema *)[_schema objectForKey:NyaruConfig.key]).allKeys;
    for (NSString *key in allKeys.allKeys) {
        NyaruKey *nyaruKey = [allKeys objectForKey:key];
        [result addObject:documentForKey(nyaruKey, fileDocument)];
    }
    [fileDocument closeFile];
    
    return result;
}
- (NSArray *)documentsForNyaruQueries:(NSArray *)query
{
    NSMutableArray *result = [NSMutableArray new];
    NSArray *keys = nyaruKeysForNyaruQueries(_schema, query);
    
    NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:_documentFilePath];
    for (NyaruKey *key in keys) {
        [result addObject:documentForKey(key, fileDocument)];
    }
    [fileDocument closeFile];
    
    return result;
}
- (NSArray *)documentsForNyaruQueries:(NSArray *)query skip:(NSUInteger)skip take:(NSUInteger)take
{
    NSMutableArray *result = [NSMutableArray new];
    NSArray *keys = nyaruKeysForNyaruQueries(_schema, query);
    
    NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:_documentFilePath];
    for (NSUInteger index = skip; index < keys.count && index < take + skip; index++) {
        NyaruKey *key = [keys objectAtIndex:index];
        [result addObject:documentForKey(key, fileDocument)];
    }
    [fileDocument closeFile];
    
    return result;
}
#pragma mark Read - Private
// get document full informetion with nyaru key and file handle
BURST_LINK NSMutableDictionary *documentForKey(NyaruKey *nyaruKey, NSFileHandle *fileDocument)
{
    NSMutableDictionary *result = nil;
    
    @try {
        [fileDocument seekToFileOffset:nyaruKey.documentOffset];
        
        // read document data
        NSData *documentData = [fileDocument readDataOfLength:nyaruKey.documentLength];
        result = documentData.gunzippedData.mutableObjectFromJSONDataN;
    }
    @catch (NSException *exception) { }
    
    return result;
}
// get nyarukeys for queries,   return [NyaruKey]
BURST_LINK NSArray *nyaruKeysForNyaruQueries(NSMutableDictionary *schemas, NSArray *queries)
{
    // key: NSNumber *queryIndex,  value: NSMutableArray *[document.key, document.key]
    NSMutableDictionary *mapResult = [NSMutableDictionary new];
    // key: NSNumber *queryIndex,  value: NSMutableDictionary [NyaruIndex]
    NSMutableDictionary *mapResultSort = [NSMutableDictionary new];
    NSInteger queryIndex = 0;
    
    // search item with map reduce
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();
    
    for (NyaruQuery *query in queries) {
        NyaruSchema *schema = [schemas objectForKey:query.schemaName];
        if (schemas == nil || schema.unique) {
            // there are no schemas which name is same with query.schemaName.
            // or query.schemaName is 'key'
            continue;
        }
        
        if (query.operation == NyaruQueryOrderASC || query.operation == NyaruQueryOrderDESC) {
            // map ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
            NSNumber *index = [NSNumber numberWithInteger:queryIndex];
            dispatch_group_async(group, queue, ^{
                [mapResultSort setObject:mapNyaruIndexForSort(schema.allIndexes, query) forKey:index];
            });
        }
        else {
            // map ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
            NSNumber *index = [NSNumber numberWithInteger:queryIndex];
            dispatch_group_async(group, queue, ^{
                [mapResult setObject:mapNyaruIndex(schema, query) forKey:index];
            });
        }
        queryIndex++;
    }
    
    // reduce ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);
    NSMutableDictionary *schemaKey = ((NyaruSchema *)[schemas objectForKey:NyaruConfig.key]).allKeys;
    NSMutableDictionary *tempKeys = nil;
    
    // set base data
    // key: NSString document.key,  vlaue: NyaruKey
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:schemaKey];
    
    // select operation
    for (NSNumber *mapID in mapResult.allKeys) {
        NSMutableArray *keys = [mapResult objectForKey:mapID];
        NyaruQuery *query = [queries objectAtIndex:mapID.integerValue];
        
        switch (query.appendWith) {
            case NYOr:
                // previous || result (append items
                for (NSString *key in keys) {
                    [result setObject:[schemaKey objectForKey:key] forKey:key];
                }
                break;
            case NYAnd:
            default:
                // previous && result (remove items
                if (keys.count > 0) {
                    // if items in indexes are not exist than remove them
                    tempKeys = [[NSMutableDictionary alloc] initWithObjects:result.allKeys forKeys:result.allKeys];
                    [tempKeys removeObjectsForKeys:keys];
                    [result removeObjectsForKeys:tempKeys.allKeys];
                }
                else {
                    // indexes has no item than clear result
                    [result removeAllObjects];
                }
                break;
        }
    }
    
    // sort operation
    if (mapResultSort.count > 0) {
        NSMutableArray *sortResult = [NSMutableArray new];
        NSMutableArray *indexes = mapResultSort.allValues.lastObject;
        
        for (NyaruIndex *index in indexes) {
            NyaruKey *key = [result objectForKey:index.key];
            if (key) {
                [sortResult addObject:key];
            }
        }
        
        return sortResult;
    }
    
    return result.allValues;
}
// sort operation return [NyaruIndex]
BURST_LINK NSMutableArray *mapNyaruIndexForSort(NSMutableArray *allIndexes, NyaruQuery *query)
{
    NSMutableArray *result = [NSMutableArray new];
    
    switch (query.operation) {
        case NyaruQueryOrderASC:
        default:
            for (NyaruIndex *index in allIndexes) {
                [result addObject:index];
            }
            break;
        case NyaruQueryOrderDESC:
            for (NSUInteger index = allIndexes.count - 1; index != NSUIntegerMax; index--) {
                NyaruIndex *nyaruIndex = [allIndexes objectAtIndex:index];
                [result addObject:nyaruIndex];
            }
            break;
    }
    
    return result;
}
// select operation return [document.key, document.key, document.key...]
BURST_LINK NSMutableArray *mapNyaruIndex(NyaruSchema *schema, NyaruQuery *query)
{
    NSMutableArray *result = [NSMutableArray new];
    NyaruSchemaType queryType;
    
    // lookup class
    if ([query.value isKindOfClass:NSNull.class]) { queryType = NyaruSchemaTypeNil; }
    else if ([query.value isKindOfClass:NSNumber.class]) { queryType = NyaruSchemaTypeNumber; }
    else if ([query.value isKindOfClass:NSString.class]) { queryType = NyaruSchemaTypeString; }
    else if ([query.value isKindOfClass:NSDate.class]) { queryType = NyaruSchemaTypeDate; }
    else { queryType = NyaruSchemaTypeString; }
    
    switch (query.operation) {
        case NyaruQueryEqual:
            if (queryType == NyaruSchemaTypeNil) {
                for (NyaruIndex *index in schema.allNilIndexes) {
                    [result addObject:index.key];
                }
            }
            else
                result = filterEqual(schema.allIndexes, query.value, queryType);
            break;
        case NyaruQueryUnequal:
            result = filterUnequal(schema.allIndexes, query.value, queryType);
            break;
        case NyaruQueryLess:
            if (queryType != NyaruSchemaTypeNil)
                result = filterLess(schema.allIndexes, query.value, queryType, NO);
            break;
        case NyaruQueryLessEqual:
            if (queryType == NyaruSchemaTypeNil) {
                for (NyaruIndex *index in schema.allNilIndexes) {
                    [result addObject:index.key];
                }
            }
            else
                result = filterLess(schema.allIndexes, query.value, queryType, YES);
            break;
        case NyaruQueryGreater:
            result = filterGreater(schema.allIndexes, query.value, queryType, NO);
            break;
        case NyaruQueryGreaterEqual:
            if (queryType == NyaruSchemaTypeNil) {
                for (NyaruIndex *index in schema.allIndexes) {
                    [result addObject:index.key];
                }
            }
            else
                result = filterGreater(schema.allNotNilIndexes, query.value, queryType, YES);
            break;
        case NyaruQueryLike:
        case NyaruQueryBeginningOf:
        case NyaruQueryEndOf:
            if ([query.value isKindOfClass:NSString.class]) {
                result = filterLike(schema.allNotNilIndexes, query.value, queryType, query.operation);
            }
        default:
            break;
    }
    
    return result;
}
// find equal items in pool
// if there are no equal items then return final up bound, and length = 0;
BURST_LINK NSRange findEqualRange(NSMutableArray *pool, id reference, NyaruSchemaType schemaType)
{
    NSUInteger rangeStart = NSNotFound;
    NSUInteger rangeEnd = 0;
    NSUInteger upBound = 0;
    NSUInteger downBound = pool.count - 1;
    NSUInteger targetIndex = (upBound + downBound) / 2;
    NSComparisonResult comp;
    id target;
    
    while (upBound <= downBound) {
        target = ((NyaruIndex *)[pool objectAtIndex:targetIndex]).value;
        comp = compare(reference, target, schemaType);
        
        switch (comp) {
            case NSOrderedSame:
                rangeStart = targetIndex;
                rangeEnd = targetIndex;
                // find equal data
                for (NSUInteger index = targetIndex - 1; index >= upBound && index != NSUIntegerMax; index--) {
                    target = ((NyaruIndex *)[pool objectAtIndex:index]).value;
                    comp = compare(reference, target, schemaType);
                    if (comp == NSOrderedSame)
                        rangeStart = index;
                    else
                        break;
                }
                for (NSUInteger index = targetIndex + 1; index <= downBound; index++) {
                    target = ((NyaruIndex *)[pool objectAtIndex:index]).value;
                    comp = compare(reference, target, schemaType);
                    if (comp == NSOrderedSame)
                        rangeEnd = index;
                    else
                        break;
                }
                // return equal nyaru index array
                return NSMakeRange(rangeStart, rangeEnd - rangeStart + 1);
            case NSOrderedAscending:
                // reference is less than target
                downBound = downBound == targetIndex ? --targetIndex : targetIndex;
                break;
            case NSOrderedDescending:
                // reference is greater than target
                upBound = upBound == targetIndex ? ++targetIndex : targetIndex;
                break;
        }
        
        targetIndex = (upBound + downBound) / 2;
    }
    
    // not find equal data
    return NSMakeRange(upBound, 0);
}
BURST_LINK NSMutableArray *filterEqual(NSMutableArray *pool, id reference, NyaruSchemaType schemaType)
{
    NSMutableArray *result = [NSMutableArray new];
    NSRange equalRange = findEqualRange(pool, reference, schemaType);
    
    if (equalRange.length == 0) {
        return result;
    }
    
    for (NSUInteger index = equalRange.location; index < equalRange.location + equalRange.length; index++) {
        [result addObject:((NyaruIndex *)[pool objectAtIndex:index]).key];
    }
    
    return result;
}
BURST_LINK NSMutableArray *filterUnequal(NSMutableArray *pool, id reference, NyaruSchemaType schemaType)
{
    NSMutableArray *result = [NSMutableArray new];
    NSRange equalRange = findEqualRange(pool, reference, schemaType);
    
    if (equalRange.length == 0) {
        for (NSUInteger index = 0; index < pool.count; index++) {
            [result addObject:((NyaruIndex *)[pool objectAtIndex:index]).key];
        }
    }
    else {
        for (NSUInteger index = 0; index < equalRange.location; index++) {
            [result addObject:((NyaruIndex *)[pool objectAtIndex:index]).key];
        }
        for (NSUInteger index = equalRange.location + equalRange.length; index < pool.count; index++) {
            [result addObject:((NyaruIndex *)[pool objectAtIndex:index]).key];
        }
    }
    
    return result;
}
BURST_LINK NSMutableArray *filterLess(NSMutableArray *pool, id reference, NyaruSchemaType schemaType, BOOL includeEqual)
{
    NSMutableArray *result = [NSMutableArray new];
    NSRange equalRange = findEqualRange(pool, reference, schemaType);
    
    for (NSUInteger index = 0; index < equalRange.location; index++) {
        // add less datas
        [result addObject:((NyaruIndex *)[pool objectAtIndex:index]).key];
    }
    
    if (includeEqual && equalRange.length > 0) {
        // add equal datas
        for (NSUInteger index = equalRange.location; index < equalRange.location + equalRange.length; index++) {
            [result addObject:((NyaruIndex *)[pool objectAtIndex:index]).key];
        }
    }
    
    return result;
}
BURST_LINK NSMutableArray *filterGreater(NSMutableArray *pool, id reference, NyaruSchemaType schemaType, BOOL includeEqual)
{
    NSMutableArray *result = [NSMutableArray new];
    NSRange equalRange = findEqualRange(pool, reference, schemaType);
    
    if (includeEqual && equalRange.length > 0) {
        // add equal datas and greater datas
        for (NSUInteger index = equalRange.location; index < pool.count; index++) {
            [result addObject:((NyaruIndex *)[pool objectAtIndex:index]).key];
        }
    }
    else if (!includeEqual && equalRange.length > 0) {
        // add greater datas
        for (NSUInteger index = equalRange.location + equalRange.length; index < pool.count; index++) {
            [result addObject:((NyaruIndex *)[pool objectAtIndex:index]).key];
        }
    }
    else {
        // add greater datas
        for (NSUInteger index = equalRange.location + 1; index < pool.count; index++) {
            [result addObject:((NyaruIndex *)[pool objectAtIndex:index]).key];
        }
    }
    
    return result;
}
BURST_LINK NSMutableArray *filterLike(NSMutableArray *pool, NSString *reference, NyaruSchemaType schemaType, NyaruQueryOperation operation)
{
    NSMutableArray *result = [NSMutableArray new];
    NSRange target;
    
    switch (operation) {
        case NyaruQueryLike:
            for (NyaruIndex *index in pool) {
                if ([index.value rangeOfString:reference options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [result addObject:index.key];
                }
            }
            break;
        case NyaruQueryBeginningOf:
            target = NSMakeRange(0, reference.length);
            for (NyaruIndex *index in pool) {
                if ([index.value rangeOfString:reference options:NSCaseInsensitiveSearch range:target].location == 0 ) {
                    [result addObject:index.key];
                }
            }
            break;
        case NyaruQueryEndOf:
            for (NyaruIndex *index in pool) {
                target = NSMakeRange([index.value length] - reference.length + 1, reference.length);
                if ([index.value rangeOfString:reference options:NSCaseInsensitiveSearch range:target].location != NSNotFound) {
                    [result addObject:index.key];
                }
            }
            break;
    }
    
    return result;
}
#pragma mark compare value1 and value2 with datatype 'SchemaType'
BURST_LINK NSComparisonResult compare(id value1, id value2, NyaruSchemaType schemaType)
{
    if ([value2 isKindOfClass:NSNull.class]) {
        switch (schemaType) {
            case NyaruSchemaTypeNil:
                return NSOrderedSame;
            default:
                return NSOrderedDescending;
                break;
        }
    }
    
    switch (schemaType) {
        case NyaruSchemaTypeString:
            return [(NSString *)value1 compare:value2 options:NSCaseInsensitiveSearch];
        case NyaruSchemaTypeNumber:
            return [(NSNumber *)value1 compare:value2];
        case NyaruSchemaTypeDate:
            if (((NSDate *)value1).timeIntervalSince1970 == ((NSDate *)value2).timeIntervalSince1970)
                return NSOrderedSame;
            else if (((NSDate *)value1).timeIntervalSince1970 < ((NSDate *)value2).timeIntervalSince1970)
                return NSOrderedAscending;
            else
                return NSOrderedDescending;
        default:
            return NSOrderedAscending;
    }
}

#pragma mark Insert
- (NSMutableDictionary *)insertDocument:(NSDictionary *)document
{
    if (document == nil) {
        @throw [NSException exceptionWithName:NyaruDBNProduct reason:@"document could not be nil." userInfo:nil];
        return nil;
    }
    
    NSMutableDictionary *doc = [NSMutableDictionary dictionaryWithDictionary:document];
    if ([[doc objectForKey:NyaruConfig.key] isKindOfClass:NSNull.class] || ((NSString *)[doc objectForKey:NyaruConfig.key]).length == 0) {
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        NSString *key = (__bridge NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        [doc setObject:key forKey:NyaruConfig.key];
        CFRelease(uuid);
    }
    
    // get document offset
    NSData *docData = doc.JSONDataN.gzippedData;
    
    if (docData.length == 0) {
        @throw [NSException exceptionWithName:NyaruDBNProduct reason:@"document serialized failed." userInfo:nil];
        return nil;
    }
    
    // check key is exist
    if ([((NyaruSchema *)[_schema objectForKey:NyaruConfig.key]).allKeys objectForKey:[doc objectForKey:NyaruConfig.key]]) {
        @throw([NSException exceptionWithName:NyaruDBNProduct reason:[NSString stringWithFormat:@"key '%@' is exist.", [doc objectForKey:NyaruConfig.key]] userInfo:nil]);
        return nil;
    }
    
    // write data with GCD
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, _ioQueue, ^(void) {
        NSFileHandle *fileDocument = [NSFileHandle fileHandleForWritingAtPath:_documentFilePath];
        NSFileHandle *fileIndex = [NSFileHandle fileHandleForUpdatingAtPath:_indexFilePath];
        
        unsigned int documentOffset = 0;
        unsigned int documentLength = docData.length;
        unsigned int blockLength = 0;
        
        // get index offset
        unsigned int indexOffset = 0;
        if (_clearedIndexBlock.count > 0) {
            for (NSDictionary *target in _clearedIndexBlock) {
                blockLength = [[target objectForKey:NyaruConfig.blockLength] unsignedIntValue];
                if (blockLength >= documentLength) {
                    // old document block could be reuse
                    indexOffset = [[target objectForKey:NyaruConfig.indexOffset] unsignedIntValue];
                    
                    // read old document block offset
                    [fileIndex seekToFileOffset:indexOffset];
                    NSData *documentOffsetData = [fileIndex readDataOfLength:4];
                    [documentOffsetData getBytes:&documentOffset length:sizeof(documentOffset)];
                    [fileDocument seekToFileOffset:documentOffset];
                    
                    // if reuse document block, update index data
                    [fileIndex seekToFileOffset:indexOffset];
                    
                    [_clearedIndexBlock removeObject:target];
                    break;
                }
            }
        }
        if (indexOffset == 0) {
            documentOffset = [fileDocument seekToEndOfFile];
            indexOffset = [fileIndex seekToEndOfFile];
            blockLength = documentLength;
        }
        
        // push key and index
        for (NyaruSchema *schema in _schema.allValues) {
            if (schema.unique) {
                NyaruKey *key = [[NyaruKey alloc] initWithIndexOffset:indexOffset
                                                       documentOffset:documentOffset
                                                       documentLength:documentLength
                                                          blockLength:blockLength];
                [schema pushKey:[doc objectForKey:NyaruConfig.key] nyaruKey:key];
            }
            else {
                NyaruIndex *index = [[NyaruIndex alloc] initWithIndexValue:[doc objectForKey:schema.name]
                                                                       key:[doc objectForKey:NyaruConfig.key]];
                [schema pushIndex:index];
            }
        }
        
        // write document
        [fileDocument writeData:docData];
        
        // write index
        NSMutableData *indexData = [[NSMutableData alloc] initWithBytes:&documentOffset length:sizeof(documentOffset)];
        [indexData appendBytes:&documentLength length:sizeof(documentLength)];
        [indexData appendBytes:&blockLength length:sizeof(blockLength)];
        [fileIndex writeData:indexData];
        
        // close files
        [fileDocument closeFile];
        [fileIndex closeFile];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);
    
    return doc;
}

#pragma mark Rmove
- (void)removeDocumentWithKey:(NSString *)key
{
    NyaruKey *nyaruKey = [[_schema objectForKey:NyaruConfig.key] indexForKey:key];
    
    if (nyaruKey) {
        // write data with GCD
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_async(group, _ioQueue, ^(void) {
            NSFileHandle *fileIndex = [NSFileHandle fileHandleForWritingAtPath:_indexFilePath];
            
            @try {
                unsigned int data = 0;
                [fileIndex seekToFileOffset:nyaruKey.indexOffset + 4];
                [fileIndex writeData:[NSData dataWithBytes:&data length:sizeof(data)]];
                [_clearedIndexBlock addObject:@{
                 NyaruConfig.indexOffset: [NSNumber numberWithUnsignedInt:nyaruKey.indexOffset],
                 NyaruConfig.blockLength: [NSNumber numberWithUnsignedInt:nyaruKey.blockLength] }];
                
                for (NyaruSchema *schema in _schema.allValues) {
                    [schema removeForKey:key];
                }
            }
            @catch (NSException *exception) { }
            
            [fileIndex closeFile];
        });
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        dispatch_release(group);
    }
}
- (void)removeAllDocument
{
    // write data with GCD
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, _ioQueue, ^(void) {
        [_clearedIndexBlock removeAllObjects];
        for (NyaruSchema *schema in _schema.allValues) {
            [schema removeAll];
        }
        
        // remove files
        [[NSFileManager defaultManager] removeItemAtPath:_documentFilePath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:_indexFilePath error:nil];
        
        // create files
        NSError *error = nil;
        NSString *header = NyaruFileHeader;
        [header writeToFile:_documentFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NyaruDBNProduct reason:error.description userInfo:error.userInfo]);
        }
        [header writeToFile:_indexFilePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NyaruDBNProduct reason:error.description userInfo:error.userInfo]);
        }
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);
}


#pragma mark - ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
#pragma mark - Private Method
BURST_LINK BOOL isNyaruHeaderOK(NSString *path)
{
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *header = [fileHandle readDataOfLength:NyaruFileHeaderLength];
    [fileHandle closeFile];
    return [[[NSString alloc] initWithData:header encoding:NSUTF8StringEncoding] isEqualToString:NyaruFileHeader];
}

- (NSMutableDictionary *)loadSchema
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:_schemaFilePath error:nil];
    unsigned int size = [[fileInfo objectForKey:@"NSFileSize"] unsignedIntegerValue];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:_schemaFilePath];
    
    [file seekToFileOffset:NyaruFileHeaderLength];
    while (file.offsetInFile < size) {
        unsigned int offset = file.offsetInFile;
        // get length of key
        unsigned char length;
        NSMutableData *data = [NSMutableData dataWithData:[file readDataOfLength:9]];
        [[data subdataWithRange:NSMakeRange(8, 1)] getBytes:&length length:sizeof(length)];
        
        // read data of schema name
        [data appendData:[file readDataOfLength:length]];
        
        NyaruSchema *schema = [[NyaruSchema alloc] initWithData:data];
        schema.offset = offset;
        [result setObject:schema forKey:schema.name];
        
        if (schema.nextOffset == 0) {
            // this is last of schema
            break;
        }
        else {
            [file seekToFileOffset:schema.nextOffset];
        }
    }
    
    [file closeFile];
    return result;
}

- (void)loadIndex
{
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:_indexFilePath error:nil];
    unsigned int size = [[fileInfo objectForKey:@"NSFileSize"] unsignedIntegerValue];
    NSFileHandle *fileIndex = [NSFileHandle fileHandleForReadingAtPath:_indexFilePath];
    NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:_documentFilePath];
    
    [fileIndex seekToFileOffset:NyaruFileHeaderLength];
    while (fileIndex.offsetInFile < size) {
        // read index
        unsigned int indexOffset = fileIndex.offsetInFile;
        unsigned int documentOffset;
        unsigned int documentLength = 0;
        unsigned int blockLength = 0;
        NSData *indexData = [fileIndex readDataOfLength:12];
        
        [[indexData subdataWithRange:NSMakeRange(4, 4)] getBytes:&documentLength length:sizeof(documentLength)];
        if (documentLength == 0) {
            [_clearedIndexBlock addObject:@{
             NyaruConfig.indexOffset: [NSNumber numberWithUnsignedInt:indexOffset],
             NyaruConfig.blockLength: [NSNumber numberWithUnsignedInt:blockLength] }];
            continue;
        }
        [[indexData subdataWithRange:NSMakeRange(0, 4)] getBytes:&documentOffset length:sizeof(documentOffset)];
        [[indexData subdataWithRange:NSMakeRange(8, 4)] getBytes:&blockLength length:sizeof(blockLength)];
        
        // read document
        [fileDocument seekToFileOffset:documentOffset];
        NSData *documentData = [fileDocument readDataOfLength:documentLength];
        NSDictionary *document = documentData.gunzippedData.mutableObjectFromJSONDataN;
        
        for (NyaruSchema *schema in _schema.allValues) {
            if (schema.unique) {
                NyaruKey *key = [[NyaruKey alloc] initWithIndexOffset:indexOffset
                                                       documentOffset:documentOffset
                                                       documentLength:documentLength
                                                          blockLength:blockLength];
                
                [schema pushKey:[document objectForKey:NyaruConfig.key] nyaruKey:key];
            }
            else {
                NyaruIndex *index = [[NyaruIndex alloc] initWithIndexValue:[document objectForKey:schema.name]
                                                                       key:[document objectForKey:NyaruConfig.key]];
                [schema pushIndex:index];
            }
        }
    }
    
    [fileIndex closeFile];
    [fileDocument closeFile];
}
- (void)loadIndexForSchema:(NyaruSchema *)schema
{
    if (schema.unique) {
        // first schema 'key'
        return;
    }
    
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:_indexFilePath error:nil];
    unsigned int size = [[fileInfo objectForKey:@"NSFileSize"] unsignedIntegerValue];
    NSFileHandle *fileIndex = [NSFileHandle fileHandleForReadingAtPath:_indexFilePath];
    NSFileHandle *fileDocument = [NSFileHandle fileHandleForReadingAtPath:_documentFilePath];
    
    [fileIndex seekToFileOffset:NyaruFileHeaderLength];
    while (fileIndex.offsetInFile < size) {
        // read index
        unsigned int indexOffset = fileIndex.offsetInFile;
        unsigned int documentOffset;
        unsigned int documentLength = 0;
        unsigned int blockLength = 0;
        NSData *indexData = [fileIndex readDataOfLength:12];
        
        [[indexData subdataWithRange:NSMakeRange(4, 4)] getBytes:&documentLength length:sizeof(documentLength)];
        if (documentLength == 0) {
            [_clearedIndexBlock addObject:@{
             NyaruConfig.indexOffset: [NSNumber numberWithUnsignedInt:indexOffset],
             NyaruConfig.blockLength: [NSNumber numberWithUnsignedInt:blockLength] }];
            continue;
        }
        [[indexData subdataWithRange:NSMakeRange(0, 4)] getBytes:&documentOffset length:sizeof(documentOffset)];
        [[indexData subdataWithRange:NSMakeRange(8, 4)] getBytes:&blockLength length:sizeof(blockLength)];
        
        // read document
        [fileDocument seekToFileOffset:documentOffset];
        NSData *documentData = [fileDocument readDataOfLength:documentLength];
        NSDictionary *document = documentData.gunzippedData.mutableObjectFromJSONDataN;
        
        NyaruIndex *index = [[NyaruIndex alloc] initWithIndexValue:[document objectForKey:schema.name]
                                                               key:[document objectForKey:NyaruConfig.key]];
        [schema pushIndex:index];
    }
    
    [fileIndex closeFile];
    [fileDocument closeFile];
}

@end
