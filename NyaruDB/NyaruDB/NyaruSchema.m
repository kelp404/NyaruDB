//
//  NyaruMnemosyne.m
//  NyaruDB
//
//  Created by Kelp on 12/9/9.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import "NyaruConfig.h"
#import "NyaruSchema.h"

@implementation NyaruSchema

@synthesize name = _name;
@synthesize unique = _unique;
@synthesize nextOffset = _nextOffset;
@synthesize previousOffset = _previousOffset;


#pragma mark - Init
- (id)initWithData:(NSData *)data
{
    self = [super init];
    if (self) {
        [[data subdataWithRange:NSMakeRange(0, 4)] getBytes:&_previousOffset length:sizeof(_previousOffset)];
        [[data subdataWithRange:NSMakeRange(4, 4)] getBytes:&_nextOffset length:sizeof(_nextOffset)];
        _name = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(9, data.length - 9)] encoding:NSUTF8StringEncoding];
        _unique = [_name isEqualToString:NyaruConfig.key];
        
        if (_unique) {
            _indexKey = [NSMutableDictionary new];
        }
        else {
            _indexNil = [NSMutableArray new];
            _index = [NSMutableArray new];
        }
    }
    return self;
}

- (id)initWithName:(NSString *)name previousOffser:(unsigned int)previous nextOffset:(unsigned int)next
{
    self = [super init];
    if (self) {
        if (name == nil || name.length == 0) {
            return nil;
        }
        if ([name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0xff) {
            @throw([NSException exceptionWithName:NyaruDBNProduct reason:@"len of name is over 255" userInfo:nil]);
        }
        
        _previousOffset = previous;
        _nextOffset = next;
        _name = name;
        _unique = [_name isEqualToString:NyaruConfig.key];
        
        if (_unique) {
            _indexKey = [NSMutableDictionary new];
        }
        else {
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
    unsigned int previous = _previousOffset;
    unsigned int next = _nextOffset;
    unsigned char length = nameData.length;
    
    // generate index binary data
    NSMutableData *result = [NSMutableData new];
    [result appendData:[NSData dataWithBytes:&previous length:sizeof(previous)]];
    [result appendData:[NSData dataWithBytes:&next length:sizeof(next)]];
    [result appendData:[NSData dataWithBytes:&length length:sizeof(length)]];
    [result appendData:nameData];
    
    return result;
}


#pragma mark - Index Access
#pragma mark read index
- (NyaruKey *)indexForKey:(NSString *)key
{
    return [_indexKey objectForKey:key];
}

#pragma mark remove keys/indexes
- (void)removeForKey:(NSString *)key
{
    [_indexKey removeObjectForKey:key];
    
    id target = nil;
    for (NyaruIndex *index in _index) {
        if ([index.key isEqualToString:key]) {
            target = index;
            break;
        }
    }
    if (target) {
        [_index removeObject:target];
    }
    else {
        for (NyaruIndex *index in _indexNil) {
            if ([index.key isEqualToString:key]) {
                target = index;
            }
        }
        [_indexNil removeObject:target];
    }
}
- (void)removeAll
{
    [_indexKey removeAllObjects];
    [_index removeAllObjects];
    [_indexNil removeAllObjects];
}

#pragma mark get all keys/indexes
- (NSMutableDictionary *)allKeys
{
    if (_unique) {
        return [NSMutableDictionary dictionaryWithDictionary:_indexKey];
    }
    else {
        return nil;
    }
}
- (NSMutableArray *)allNilIndexes
{
    if (_unique) {
        return nil;
    }
    else {
        NSMutableArray *result = [NSMutableArray arrayWithArray:_indexNil];
        return result;
    }
}
- (NSMutableArray *)allNotNilIndexes
{
    if (_unique) {
        return nil;
    }
    else {
        NSMutableArray *result = [NSMutableArray arrayWithArray:_index];
        return result;
    }
}
- (NSMutableArray *)allIndexes
{
    if (_unique) {
        return nil;
    }
    else {
        NSMutableArray *result = [NSMutableArray arrayWithArray:_indexNil];
        [result addObjectsFromArray:_index];
        return result;
    }
}

#pragma mark push key & index
- (BOOL)pushKey:(NSString *)key nyaruKey:(NyaruKey *)nyaruKey;
{
    if ([_indexKey objectForKey:key]) {
        // key is exist
        return NO;
    }
    else {
        [_indexKey setObject:nyaruKey forKey:key];
        return YES;
    }
}
- (void)pushIndex:(NyaruIndex *)index
{
    if ([index.value isKindOfClass:NSNull.class]) {
        // NSNull
        [_indexNil addObject:index];
    }
    else if ([index.value isKindOfClass:NSNumber.class]) {
        // NSNumber
        insertIndexIntoArrayWithSort(_index, index, NyaruSchemaTypeNumber);
    }
    else if ([index.value isKindOfClass:NSString.class]) {
        // NSString
        insertIndexIntoArrayWithSort(_index, index, NyaruSchemaTypeString);
    }
    else if ([index.value isKindOfClass:NSDate.class]) {
        // NSDate
        insertIndexIntoArrayWithSort(_index, index, NyaruSchemaTypeDate);
    }
    else {
        // other
        [_index addObject:index];
    }
}


#pragma mark - Private Methods
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
#pragma mark insert index into array with sort
BURST_LINK void insertIndexIntoArrayWithSort(NSMutableArray *array, NyaruIndex *index, NyaruSchemaType schemaType)
{
    if (array.count == 0) {
        [array addObject:index];
        return;
    }
    
    unsigned int upBound = 0;
    unsigned int downBound = array.count - 1;
    unsigned int targetIndex = (upBound + downBound) / 2;
    id target;
    NSComparisonResult comp;
    
    while (upBound < downBound) {
        target = ((NyaruIndex *)[array objectAtIndex:targetIndex]).value;
        comp = compare(index.value, target, schemaType);
        
        switch (comp) {
            case NSOrderedSame:
                [array insertObject:index atIndex:targetIndex + 1];
                return;
            case NSOrderedAscending:
                // index is less than target
                downBound = downBound == targetIndex ? --targetIndex : targetIndex;
                break;
            case NSOrderedDescending:
                // index is greater than target
                upBound = upBound == targetIndex ? ++targetIndex : targetIndex;
                break;
        }
        
        targetIndex = (upBound + downBound) / 2;
    }
    
    target = ((NyaruIndex *)[array objectAtIndex:targetIndex]).value;
    comp = compare(index.value, target, schemaType);
    switch (comp) {
        case NSOrderedAscending:
            [array insertObject:index atIndex:targetIndex];
            break;
        default:
            [array insertObject:index atIndex:targetIndex + 1];
            break;
    }
}

@end
