//
//  NyaruDB.h
//  NyaruDB
//
//  Created by Kelp on 12/7/14.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NyaruConfig.h"
#import "NyaruCollection.h"
#import "NyaruKey.h"
#import "NyaruIndex.h"
#import "NyaruQuery.h"

@interface NyaruDB : NSObject {
    // key: collection name, value: collection
    NSMutableDictionary *_collections;
}

@property (strong, nonatomic, readonly) NSString *databasePath;

+ (id)sharedInstance;
+ (void)reset;

- (NSDictionary *)allCollections;
- (NyaruCollection *)collectionForName:(NSString *)name;
- (NyaruCollection *)createCollection:(NSString *)name;
- (void)removeCollection:(NSString *)name;

@end
