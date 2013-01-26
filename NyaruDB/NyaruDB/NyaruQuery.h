//
//  NyaruQuery.h
//  NyaruDB
//
//  Created by Kelp on 2012/10/08.
//

#import <Foundation/Foundation.h>
#import "NyaruSchema.h"

enum {
    NyaruQueryEqual = 0,
    NyaruQueryLess = 1,
    NyaruQueryLessEqual = 2,
    NyaruQueryGreater = 3,
    NyaruQueryGreaterEqual = 4,
    NyaruQueryLike = 5,               // only for NSString
    NyaruQueryBeginningOf = 6,    // only for NSString
    NyaruQueryEndOf = 7,             // only for NSString
    NyaruQueryOrderASC = 8,
    NyaruQueryOrderDESC = 9,
    
    NyaruQueryUnequal = 10,
};
typedef NSInteger NyaruQueryOperation;

enum {
    NYOr = 0,
    NYAnd = 1
};
typedef NSInteger NyaruAppendPrevious;

@interface NyaruQuery : NSObject

@property (strong, nonatomic) NSString *schemaName;
@property (nonatomic) NyaruQueryOperation operation;
@property (strong, nonatomic) id value;
@property (nonatomic) NyaruAppendPrevious appendWith;

+ (id)queryWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation;
+ (id)queryWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation value:(id)value;
+ (id)queryWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation value:(id)value appendWith:(NyaruAppendPrevious)appendWith;

- (id)initWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation;
- (id)initWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation value:(id)value;
- (id)initWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation value:(id)value appendWith:(NyaruAppendPrevious)appendWith;

@end
