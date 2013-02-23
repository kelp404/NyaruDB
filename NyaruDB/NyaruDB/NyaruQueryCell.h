//
//  NyaruQueryCell.h
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import <Foundation/Foundation.h>


#define QUERY_OPERATION_MASK 0x3F
enum {
    NyaruQueryUnequal = 0,
    NyaruQueryEqual = 1,                // suport unique schema
    
    NyaruQueryLess = 2,
    NyaruQueryLessEqual = 3,
    
    NyaruQueryGreater = 4,
    NyaruQueryGreaterEqual = 5,
    
    NyaruQueryLike = 0x30,               // only for NSString
//    NyaruQueryBeginningOf = 0x10,    // only for NSString
//    NyaruQueryEndOf = 0x20,             // only for NSString
    
    NyaruQueryIntersection = 0x40,
    NyaruQueryUnion = 0x00,
    
    NyaruQueryAll = 0x80,
    
    NyaruQueryOrderASC = 0x100,
    NyaruQueryOrderDESC = 0x200,
};
typedef NSUInteger NyaruQueryOperation;


@interface NyaruQueryCell : NSObject

@property (strong, nonatomic) NSString *schemaName;
@property (nonatomic) NyaruQueryOperation operation;
@property (strong, nonatomic) id value;

@end
