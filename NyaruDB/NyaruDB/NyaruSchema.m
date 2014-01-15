//
//  NyaruSchema.m
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import "NyaruSchema.h"
#import "NyaruConfig.h"
#import "NyaruIndex.h"
#import "NyaruKey.h"


// these are for passing Cocoapods Travis CI build [function-declaration]
@interface NyaruSchema()
NYARU_BURST_LINK void insertIndexIntoArrayWithSort(NSMutableArray *array, NSString *key, id insertValue, NyaruSchemaType schemaType);
NYARU_BURST_LINK NSComparisonResult compare(id value1, id value2, NyaruSchemaType schemaType);
NYARU_BURST_LINK NSComparisonResult compareDate(NSDate *value1, NSDate *value2);
@end



@implementation NyaruSchema


#pragma mark - Init
- (id)initWithData:(NSData *)data andOffset:(unsigned)offset
{
    self = [super init];
    if (self) {
        const unsigned char *buffer = data.bytes;
        memcpy(&_previousOffsetInFile, buffer, sizeof(unsigned));
        memcpy(&_nextOffsetInFile, &buffer[4], sizeof(unsigned));
        _name = [[NSString alloc] initWithBytes:&buffer[9] length:(data.length - 9U) encoding:NSUTF8StringEncoding];
        _offsetInFile = offset;
        _unique = [_name isEqualToString:NYARU_KEY];
        
        if (_unique) {
            _schemaType = NyaruSchemaTypeString;
            _indexKey = [NSMutableDictionary new];
        }
        else {
            _schemaType = NyaruSchemaTypeUnknow;
            _indexNil = [NSMutableArray new];
            _index = [NSMutableArray new];
        }
    }
    return self;
}
- (id)initWithName:(NSString *)name previousOffser:(unsigned)previous nextOffset:(unsigned)next
{
    self = [super init];
    if (self) {
        if (name.length == 0U) {
            return nil;
        }
        if ([name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0xffU) {
            @throw([NSException exceptionWithName:NYARU_PRODUCT reason:@"len of name is over 255" userInfo:nil]);
        }
        
        _previousOffsetInFile = previous;
        _nextOffsetInFile = next;
        _name = name;
        _unique = [_name isEqualToString:NYARU_KEY];
        
        if (_unique) {
            _schemaType = NyaruSchemaTypeString;
            _indexKey = [NSMutableDictionary new];
        }
        else {
            _schemaType = NyaruSchemaTypeUnknow;
            _indexNil = [NSMutableArray new];
            _index = [NSMutableArray new];
        }
    }
    return self;
}


#pragma mark - Get Binary Data For Write Schema File
- (NSData *)dataFormate
{
    NSData *nameData = [_name dataUsingEncoding:NSUTF8StringEncoding];
    unsigned int previous = _previousOffsetInFile;
    unsigned int next = _nextOffsetInFile;
    unsigned char length = nameData.length;
    
    // generate index binary data
    NSMutableData *result = [NSMutableData new];
    [result appendData:[NSData dataWithBytes:&previous length:sizeof(previous)]];
    [result appendData:[NSData dataWithBytes:&next length:sizeof(next)]];
    [result appendData:[NSData dataWithBytes:&length length:sizeof(length)]];
    [result appendData:nameData];
    
    return result;
}


#pragma mark - Get NyaruKey / NyaruIndex
- (NSDictionary *)allKeys
{
    return _indexKey;
}
- (NSArray *)allNilIndexes
{
    return _indexNil;
}
- (NSArray *)allNotNilIndexes
{
    return _index;
}


#pragma mark - Remove by key
- (void)removeWithKey:(NSString *)key
{
    [_indexKey removeObjectForKey:key];
    
    for (NSUInteger index = 0U; index < _indexNil.count; index++) {
        if ([_indexNil[index] isEqualToString:key]) {
            [_indexNil removeObjectAtIndex:index];
            return;
        }
    }
    for (NSUInteger index = 0U; index < _index.count; index++) {
        NyaruIndex *nyaruIndex = _index[index];
        if ([nyaruIndex.keySet intersectsSet:[NSSet setWithObject:key]]) {
            [nyaruIndex.keySet removeObject:key];
            if (nyaruIndex.keySet.count == 0U) {
                [_index removeObjectAtIndex:index];
            }
            return;
        }
    }
}
- (void)removeAll
{
    [_indexKey removeAllObjects];
    [_index removeAllObjects];
    [_indexNil removeAllObjects];
}


#pragma mark - push key & index
- (BOOL)pushNyaruKey:(NSString *)key nyaruKey:(NyaruKey *)nyaruKey;
{
    if (_indexKey[key]) {
        // key is exist
        return NO;
    }
    else {
        [_indexKey setObject:nyaruKey forKey:key];
        return YES;
    }
}
- (void)pushNyaruIndex:(NSString *)key value:(id)value
{
    if ([value isKindOfClass:NSNull.class] || !value) {
        [_indexNil addObject:key];
        return;
    }
    
    switch (_schemaType) {
        default:
        case NyaruSchemaTypeUnknow:
            // check schema type
            if ([value isKindOfClass:NSNumber.class]) { _schemaType = NyaruSchemaTypeNumber; }
            else if ([value isKindOfClass:NSString.class]) { _schemaType = NyaruSchemaTypeString; }
            else if ([value isKindOfClass:NSDate.class]) { _schemaType = NyaruSchemaTypeDate; }
            else {
                // other
                @throw [NSException exceptionWithName:NYARU_PRODUCT reason:@"insert other type data" userInfo:nil];
            }
        case NyaruSchemaTypeNumber:
        case NyaruSchemaTypeString:
        case NyaruSchemaTypeDate:
            insertIndexIntoArrayWithSort(_index, key, value, _schemaType);
            break;
    }
}


#pragma mark - for NyaruDB (do not use these)
- (void)close
{
    if (_indexKey) { [_indexKey removeAllObjects]; }
    if (_indexNil) { [_indexNil removeAllObjects]; }
    if (_index) { [_index removeAllObjects]; }
}


#pragma mark - Private methods
#pragma mark insert index into array with sort
/**
 Insert NyaruIndex into array (_index)
 @param array _index
 @param key document.key
 @param insertValue NyaruIndex.value
 @param schemaType
 */
NYARU_BURST_LINK void insertIndexIntoArrayWithSort(NSMutableArray *array, NSString *key, id insertValue, NyaruSchemaType schemaType)
{
    // array.count : 0 ~ 2
    NSComparisonResult compResult;
    switch (array.count) {
        case 0U:
            [array addObject:[[NyaruIndex alloc] initWithIndexValue:insertValue key:key]];
            return;
        case 1U:
            compResult = compare([(NyaruIndex *)array[0U] value], insertValue, schemaType);
            switch (compResult) {
                case NSOrderedAscending:
                    // index > array[0]
                    [array addObject:[[NyaruIndex alloc] initWithIndexValue:insertValue key:key]];
                    break;
                case NSOrderedSame:
                    // index == array[0]
                    [[array[0U] keySet] addObject:key];
                    break;
                case NSOrderedDescending:
                    // index < array[0]
                    [array insertObject:[[NyaruIndex alloc] initWithIndexValue:insertValue key:key] atIndex:0U];
                    break;
            }
            return;
    }
    
    // compare the first
    compResult = compare([(NyaruIndex *)array[0U] value], insertValue, schemaType);
    if (compResult == NSOrderedDescending) {
        // index < array[0]
        [array insertObject:[[NyaruIndex alloc] initWithIndexValue:insertValue key:key] atIndex:0U];
        return;
    }
    else if (compResult == NSOrderedSame) {
        // index == array[0]
        [[array[0U] keySet] addObject:key];
        return;
    }
    // compare the last
    compResult = compare([(NyaruIndex *)[array lastObject] value], insertValue, schemaType);
    if (compResult == NSOrderedAscending) {
        // index > array[last]
        [array addObject:[[NyaruIndex alloc] initWithIndexValue:insertValue key:key]];
        return;
    }
    else if (compResult == NSOrderedSame) {
        // index == array[last]
        [[[array lastObject] keySet] addObject:key];
        return;
    }
    
    NSUInteger upBound = 1U;
    NSUInteger downBound = array.count - 2U;
    NSUInteger targetIndex = (upBound + downBound) / 2U;
    
    while (upBound <= downBound) {
        compResult = compare([(NyaruIndex *)array[targetIndex] value], insertValue, schemaType);
        
        switch (compResult) {
            case NSOrderedSame:
                // index.value == array[targetIndex]
                [[array[targetIndex] keySet] addObject:key];
                return;
            case NSOrderedDescending:
                // index.value < array[targetIndex]
                downBound = targetIndex - 1U;
                targetIndex = (upBound + downBound) / 2U;
                break;
            case NSOrderedAscending:
                // index.value > array[targetIndex]
                upBound = targetIndex + 1U;
                targetIndex = (upBound + downBound) / 2U;
                if (targetIndex < upBound) { targetIndex = upBound; }
                break;
        }
    }
    
    // did not find the same value in the array.
    [array insertObject:[[NyaruIndex alloc] initWithIndexValue:insertValue key:key] atIndex:upBound];
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


@end
