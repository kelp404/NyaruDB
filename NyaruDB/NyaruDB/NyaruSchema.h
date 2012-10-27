//
//  NyaruIndexSchema.h
//  NyaruDB
//
//  Created by Kelp on 12/9/9.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NyaruKey.h"
#import "NyaruIndex.h"


@interface NyaruSchema : NSObject {
    // index of schema of 'key'. If self.unique is YES then use this.
    // key: value of index key, value: NyaruKey
    // key: ["kelp@accuvally.com", "00@accuvally.com"], value: [key object, key object, key object]
    NSMutableDictionary *_indexKey;
    
    // index of other schemas. If self.unique is NO then use this.
    // data is sorted by index.value
    NSMutableArray *_indexNil;
    NSMutableArray *_index;
}

@property (strong, nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) BOOL unique;
@property (nonatomic) unsigned int previousOffset;
@property (nonatomic) unsigned int nextOffset;
@property (nonatomic) unsigned int offset;

#pragma mark - Init
- (id)initWithData:(NSData *)data;
- (id)initWithName:(NSString *)name previousOffser:(unsigned int)previous nextOffset:(unsigned int)next;

#pragma mark - Get Binary Data For File
- (NSData *)dataFormate;

#pragma mark - Index Access
// get index by key
- (NyaruKey *)indexForKey:(NSString *)key;

// remove all keys/indexes with key
- (void)removeForKey:(NSString *)key;

// all index key/index, key is only for unique
- (NSMutableDictionary *)allKeys;
- (NSMutableArray *)allNilIndexes;
- (NSMutableArray *)allNotNilIndexes;
- (NSMutableArray *)allIndexes;

// push key,    success: return YES,   failed: return NO
- (BOOL)pushKey:(NSString *)key nyaruKey:(NyaruKey *)nyaruKey;
// push index
- (void)pushIndex:(NyaruIndex *)index;

@end
