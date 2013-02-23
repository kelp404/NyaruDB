//
//  NyaruDB.h
//  NyaruDB
//
//  Created by Kelp on 2013/02/18.
//

#import <Foundation/Foundation.h>
#import "NyaruCollection.h"
#import "NyaruQuery.h"


@interface NyaruDB : NSObject {
    // key: collection name, value: collection
    NSMutableDictionary *_collections;
    
    // data base path
    NSString *_databasePath;
}

#pragma mark - Static methods
/**
 Get the shared instance.
 @return NyaruDB shared instance
 */
+ (id)instance;

/**
 Remove all database. if you init database error, maybe need to call this message.
 */
+ (void)reset;


#pragma mark - Init
/**
 Init NyaruDB.
 @return NyaruDB instance
 */
- (id)init;


#pragma mark - Collection
/**
 Get all collections.
 @return @[NyaruCollection]
 */
- (NSArray *)collections;
/**
 Get the collection with name. If collection is not exist then create it.
 @param name collection name
 @return NyaruCollection / nil
 */
- (NyaruCollection *)collectionForName:(NSString *)name;
/**
 Remove the collection with name.
 @param name collection name
 */
- (void)removeCollection:(NSString *)name;
- (void)removeAllCollections;

@end
