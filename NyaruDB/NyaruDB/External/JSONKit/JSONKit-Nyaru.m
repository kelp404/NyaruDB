//
//  JSONKit.m
//  http://github.com/johnezang/JSONKit
//  Dual licensed under either the terms of the BSD License, or alternatively
//  under the terms of the Apache License, Version 2.0, as specified below.
//

/*
 Copyright (c) 2011, John Engelhart
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the name of the Zang Industries nor the names of its
 contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*
 Copyright 2011 John Engelhart
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/


/*
  Acknowledgments:

  The bulk of the UTF8 / UTF32 conversion and verification comes
  from ConvertUTF.[hc].  It has been modified from the original sources.

  The original sources were obtained from http://www.unicode.org/.
  However, the web site no longer seems to host the files.  Instead,
  the Unicode FAQ http://www.unicode.org/faq//utf_bom.html#gen4
  points to International Components for Unicode (ICU)
  http://site.icu-project.org/ as an example of how to write a UTF
  converter.

  The decision to use the ConvertUTF.[ch] code was made to leverage
  "proven" code.  Hopefully the local modifications are bug free.

  The code in isValidCodePoint() is derived from the ICU code in
  utf.h for the macros U_IS_UNICODE_NONCHAR and U_IS_UNICODE_CHAR.

  From the original ConvertUTF.[ch]:

 * Copyright 2001-2004 Unicode, Inc.
 * 
 * Disclaimer
 * 
 * This source code is provided as is by Unicode, Inc. No claims are
 * made as to fitness for any particular purpose. No warranties of any
 * kind are expressed or implied. The recipient agrees to determine
 * applicability of information provided. If this file has been
 * purchased on magnetic or optical media from Unicode, Inc., the
 * sole remedy for any claim will be exchange of defective media
 * within 90 days of receipt.
 * 
 * Limitations on Rights to Redistribute This Code
 * 
 * Unicode, Inc. hereby grants the right to freely use the information
 * supplied in this file in the creation of products supporting the
 * Unicode Standard, and to make copies of this file in any form
 * for internal or external distribution as long as this notice
 * remains attached.

*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <sys/errno.h>
#include <math.h>
#include <limits.h>
#include <objc/runtime.h>

#import "JSONKit-Nyaru.h"

//#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFDictionary.h>
#include <CoreFoundation/CFNumber.h>

//#import <Foundation/Foundation.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSObjCRuntime.h>

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#ifdef JKN_ENABLE_CF_TRANSFER_OWNERSHIP_CALLBACKS
#warning As of JSONKit v1.4, JKN_ENABLE_CF_TRANSFER_OWNERSHIP_CALLBACKS is no longer required.  It is no longer a valid option.
#endif

#ifdef __OBJC_GC__
#error JSONKit does not support Objective-C Garbage Collection
#endif

#if __has_feature(objc_arc)
#error JSONKit does not support Objective-C Automatic Reference Counting (ARC)
#endif

// The following checks are really nothing more than sanity checks.
// JSONKit technically has a few problems from a "strictly C99 conforming" standpoint, though they are of the pedantic nitpicking variety.
// In practice, though, for the compilers and architectures we can reasonably expect this code to be compiled for, these pedantic nitpicks aren't really a problem.
// Since we're limited as to what we can do with pre-processor #if checks, these checks are not nearly as through as they should be.

#if (UINT_MAX != 0xffffffffU) || (INT_MIN != (-0x7fffffff-1)) || (ULLONG_MAX != 0xffffffffffffffffULL) || (LLONG_MIN != (-0x7fffffffffffffffLL-1LL))
#error JSONKit requires the C 'int' and 'long long' types to be 32 and 64 bits respectively.
#endif

#if !defined(__LP64__) && ((UINT_MAX != ULONG_MAX) || (INT_MAX != LONG_MAX) || (INT_MIN != LONG_MIN) || (WORD_BIT != LONG_BIT))
#error JSONKit requires the C 'int' and 'long' types to be the same on 32-bit architectures.
#endif

// Cocoa / Foundation uses NS*Integer as the type for a lot of arguments.  We make sure that NS*Integer is something we are expecting and is reasonably compatible with size_t / ssize_t

#if (NSUIntegerMax != ULONG_MAX) || (NSIntegerMax != LONG_MAX) || (NSIntegerMin != LONG_MIN)
#error JSONKit requires NSInteger and NSUInteger to be the same size as the C 'long' type.
#endif

#if (NSUIntegerMax != SIZE_MAX) || (NSIntegerMax != SSIZE_MAX)
#error JSONKit requires NSInteger and NSUInteger to be the same size as the C 'size_t' type.
#endif


// For DJB hash.
#define JKN_HASH_INIT           (1402737925UL)

// Use __builtin_clz() instead of trailingBytesForUTF8[] table lookup.
#define JKN_FAST_TRAILING_BYTES

// JKN_CACHE_SLOTS must be a power of 2.  Default size is 1024 slots.
#define JKN_CACHE_SLOTS_BITS    (10)
#define JKN_CACHE_SLOTS         (1UL << JKN_CACHE_SLOTS_BITS)
// JKN_CACHE_PROBES is the number of probe attempts.
#define JKN_CACHE_PROBES        (4UL)
// JKN_INIT_CACHE_AGE must be < (1 << AGE) - 1, where AGE is sizeof(typeof(AGE)) * 8.
#define JKN_INIT_CACHE_AGE      (0)

// JKN_TOKENBUFFER_SIZE is the default stack size for the temporary buffer used to hold "non-simple" strings (i.e., contains \ escapes)
#define JKN_TOKENBUFFER_SIZE    (1024UL * 2UL)

// JKN_STACK_OBJS is the default number of spaces reserved on the stack for temporarily storing pointers to Obj-C objects before they can be transferred to a NSArray / NSDictionary.
#define JKN_STACK_OBJS          (1024UL * 1UL)

#define JKN_JSONBUFFER_SIZE     (1024UL * 4UL)
#define JKN_UTF8BUFFER_SIZE     (1024UL * 16UL)

#define JKN_ENCODE_CACHE_SLOTS  (1024UL)


#if       defined (__GNUC__) && (__GNUC__ >= 4)
#define JKN_ATTRIBUTES(attr, ...)        __attribute__((attr, ##__VA_ARGS__))
#define JKN_EXPECTED(cond, expect)       __builtin_expect((long)(cond), (expect))
#define JKN_EXPECT_T(cond)               JKN_EXPECTED(cond, 1U)
#define JKN_EXPECT_F(cond)               JKN_EXPECTED(cond, 0U)
#define JKN_PREFETCH(ptr)                __builtin_prefetch(ptr)
#else  // defined (__GNUC__) && (__GNUC__ >= 4) 
#define JKN_ATTRIBUTES(attr, ...)
#define JKN_EXPECTED(cond, expect)       (cond)
#define JKN_EXPECT_T(cond)               (cond)
#define JKN_EXPECT_F(cond)               (cond)
#define JKN_PREFETCH(ptr)
#endif // defined (__GNUC__) && (__GNUC__ >= 4) 

#define JKN_STATIC_INLINE                         static __inline__ JKN_ATTRIBUTES(always_inline)
#define JKN_ALIGNED(arg)                                            JKN_ATTRIBUTES(aligned(arg))
#define JKN_UNUSED_ARG                                              JKN_ATTRIBUTES(unused)
#define JKN_WARN_UNUSED                                             JKN_ATTRIBUTES(warn_unused_result)
#define JKN_WARN_UNUSED_CONST                                       JKN_ATTRIBUTES(warn_unused_result, const)
#define JKN_WARN_UNUSED_PURE                                        JKN_ATTRIBUTES(warn_unused_result, pure)
#define JKN_WARN_UNUSED_SENTINEL                                    JKN_ATTRIBUTES(warn_unused_result, sentinel)
#define JKN_NONNULL_ARGS(arg, ...)                                  JKN_ATTRIBUTES(nonnull(arg, ##__VA_ARGS__))
#define JKN_WARN_UNUSED_NONNULL_ARGS(arg, ...)                      JKN_ATTRIBUTES(warn_unused_result, nonnull(arg, ##__VA_ARGS__))
#define JKN_WARN_UNUSED_CONST_NONNULL_ARGS(arg, ...)                JKN_ATTRIBUTES(warn_unused_result, const, nonnull(arg, ##__VA_ARGS__))
#define JKN_WARN_UNUSED_PURE_NONNULL_ARGS(arg, ...)                 JKN_ATTRIBUTES(warn_unused_result, pure, nonnull(arg, ##__VA_ARGS__))

#if       defined (__GNUC__) && (__GNUC__ >= 4) && (__GNUC_MINOR__ >= 3)
#define JKN_ALLOC_SIZE_NON_NULL_ARGS_WARN_UNUSED(as, nn, ...) JKN_ATTRIBUTES(warn_unused_result, nonnull(nn, ##__VA_ARGS__), alloc_size(as))
#else  // defined (__GNUC__) && (__GNUC__ >= 4) && (__GNUC_MINOR__ >= 3)
#define JKN_ALLOC_SIZE_NON_NULL_ARGS_WARN_UNUSED(as, nn, ...) JKN_ATTRIBUTES(warn_unused_result, nonnull(nn, ##__VA_ARGS__))
#endif // defined (__GNUC__) && (__GNUC__ >= 4) && (__GNUC_MINOR__ >= 3)


@class JKNArray, JKNDictionaryEnumerator, JKNDictionary;

enum {
  JSONNumberStateStart                 = 0,
  JSONNumberStateFinished              = 1,
  JSONNumberStateError                 = 2,
  JSONNumberStateWholeNumberStart      = 3,
  JSONNumberStateWholeNumberMinus      = 4,
  JSONNumberStateWholeNumberZero       = 5,
  JSONNumberStateWholeNumber           = 6,
  JSONNumberStatePeriod                = 7,
  JSONNumberStateFractionalNumberStart = 8,
  JSONNumberStateFractionalNumber      = 9,
  JSONNumberStateExponentStart         = 10,
  JSONNumberStateExponentPlusMinus     = 11,
  JSONNumberStateExponent              = 12,
};

enum {
  JSONStringStateStart                           = 0,
  JSONStringStateParsing                         = 1,
  JSONStringStateFinished                        = 2,
  JSONStringStateError                           = 3,
  JSONStringStateEscape                          = 4,
  JSONStringStateEscapedUnicode1                 = 5,
  JSONStringStateEscapedUnicode2                 = 6,
  JSONStringStateEscapedUnicode3                 = 7,
  JSONStringStateEscapedUnicode4                 = 8,
  JSONStringStateEscapedUnicodeSurrogate1        = 9,
  JSONStringStateEscapedUnicodeSurrogate2        = 10,
  JSONStringStateEscapedUnicodeSurrogate3        = 11,
  JSONStringStateEscapedUnicodeSurrogate4        = 12,
  JSONStringStateEscapedNeedEscapeForSurrogate   = 13,
  JSONStringStateEscapedNeedEscapedUForSurrogate = 14,
};

enum {
  JKNParseAcceptValue      = (1 << 0),
  JKNParseAcceptComma      = (1 << 1),
  JKNParseAcceptEnd        = (1 << 2),
  JKNParseAcceptValueOrEnd = (JKNParseAcceptValue | JKNParseAcceptEnd),
  JKNParseAcceptCommaOrEnd = (JKNParseAcceptComma | JKNParseAcceptEnd),
};

enum {
  JKNClassUnknown    = 0,
  JKNClassString     = 1,
  JKNClassNumber     = 2,
  JKNClassArray      = 3,
  JKNClassDictionary = 4,
  JKNClassNull       = 5,
    JKNClassDate = 6,
};

enum {
  JKNManagedBufferOnStack        = 1,
  JKNManagedBufferOnHeap         = 2,
  JKNManagedBufferLocationMask   = (0x3),
  JKNManagedBufferLocationShift  = (0),
  
  JKNManagedBufferMustFree       = (1 << 2),
};
typedef JKNFlags JKNManagedBufferFlags;

enum {
  JKNObjectStackOnStack        = 1,
  JKNObjectStackOnHeap         = 2,
  JKNObjectStackLocationMask   = (0x3),
  JKNObjectStackLocationShift  = (0),
  
  JKNObjectStackMustFree       = (1 << 2),
};
typedef JKNFlags JKNObjectStackFlags;

enum {
  JKNTokenTypeInvalid     = 0,
  JKNTokenTypeNumber      = 1,
  JKNTokenTypeString      = 2,
  JKNTokenTypeObjectBegin = 3,
  JKNTokenTypeObjectEnd   = 4,
  JKNTokenTypeArrayBegin  = 5,
  JKNTokenTypeArrayEnd    = 6,
  JKNTokenTypeSeparator   = 7,
  JKNTokenTypeComma       = 8,
  JKNTokenTypeTrue        = 9,
  JKNTokenTypeFalse       = 10,
  JKNTokenTypeNull        = 11,
  JKNTokenTypeWhiteSpace  = 12,
    JKNTokenTypeDate = 13,
};
typedef NSUInteger JKNTokenType;

// These are prime numbers to assist with hash slot probing.
enum {
  JKNValueTypeNone             = 0,
  JKNValueTypeString           = 5,
  JKNValueTypeLongLong         = 7,
  JKNValueTypeUnsignedLongLong = 11,
  JKNValueTypeDouble           = 13,
};
typedef NSUInteger JKNValueType;

enum {
  JKNEncodeOptionAsData              = 1,
  JKNEncodeOptionAsString            = 2,
  JKNEncodeOptionAsTypeMask          = 0x7,
  JKNEncodeOptionCollectionObj       = (1 << 3),
  JKNEncodeOptionStringObj           = (1 << 4),
  JKNEncodeOptionStringObjTrimQuotes = (1 << 5),
  
};
typedef NSUInteger JKNEncodeOptionType;

typedef NSUInteger JKNHash;

typedef struct JKNTokenCacheItem  JKNTokenCacheItem;
typedef struct JKNTokenCache      JKNTokenCache;
typedef struct JKNTokenValue      JKNTokenValue;
typedef struct JKNParseToken      JKNParseToken;
typedef struct JKNPtrRange        JKNPtrRange;
typedef struct JKNObjectStack     JKNObjectStack;
typedef struct JKNBuffer          JKNBuffer;
typedef struct JKNConstBuffer     JKNConstBuffer;
typedef struct JKNConstPtrRange   JKNConstPtrRange;
typedef struct JKNRange           JKNRange;
typedef struct JKNManagedBuffer   JKNManagedBuffer;
typedef struct JKNFastClassLookup JKNFastClassLookup;
typedef struct JKNEncodeCache     JKNEncodeCache;
typedef struct JKNEncodeState     JKNEncodeState;
typedef struct JKNObjCImpCache    JKNObjCImpCache;
typedef struct JKNHashTableEntry  JKNHashTableEntry;

typedef id (*NSNumberAllocImp)(id receiver, SEL selector);
typedef id (*NSNumberInitWithUnsignedLongLongImp)(id receiver, SEL selector, unsigned long long value);
typedef id (*JKNClassFormatterIMP)(id receiver, SEL selector, id object);
#ifdef __BLOCKS__
typedef id (^JKNClassFormatterBlock)(id formatObject);
#endif


struct JKNPtrRange {
  unsigned char *ptr;
  size_t         length;
};

struct JKNConstPtrRange {
  const unsigned char *ptr;
  size_t               length;
};

struct JKNRange {
  size_t location, length;
};

struct JKNManagedBuffer {
  JKNPtrRange           bytes;
  JKNManagedBufferFlags flags;
  size_t               roundSizeUpToMultipleOf;
};

struct JKNObjectStack {
  void               **objects, **keys;
  CFHashCode          *cfHashes;
  size_t               count, index, roundSizeUpToMultipleOf;
  JKNObjectStackFlags   flags;
};

struct JKNBuffer {
  JKNPtrRange bytes;
};

struct JKNConstBuffer {
  JKNConstPtrRange bytes;
};

struct JKNTokenValue {
  JKNConstPtrRange   ptrRange;
  JKNValueType       type;
  JKNHash            hash;
  union {
    long long          longLongValue;
    unsigned long long unsignedLongLongValue;
    double             doubleValue;
  } number;
  JKNTokenCacheItem *cacheItem;
};

struct JKNParseToken {
  JKNConstPtrRange tokenPtrRange;
  JKNTokenType     type;
  JKNTokenValue    value;
  JKNManagedBuffer tokenBuffer;
};

struct JKNTokenCacheItem {
  void          *object;
  JKNHash         hash;
  CFHashCode     cfHash;
  size_t         size;
  unsigned char *bytes;
  JKNValueType    type;
};

struct JKNTokenCache {
  JKNTokenCacheItem *items;
  size_t            count;
  unsigned int      prng_lfsr;
  unsigned char     age[JKN_CACHE_SLOTS];
};

struct JKNObjCImpCache {
  Class                               NSNumberClass;
  NSNumberAllocImp                    NSNumberAlloc;
  NSNumberInitWithUnsignedLongLongImp NSNumberInitWithUnsignedLongLong;
};

struct JKNParseState {
  JKNParseOptionFlags  parseOptionFlags;
  JKNConstBuffer       stringBuffer;
  size_t              atIndex, lineNumber, lineStartIndex;
  size_t              prev_atIndex, prev_lineNumber, prev_lineStartIndex;
  JKNParseToken        token;
  JKNObjectStack       objectStack;
  JKNTokenCache        cache;
  JKNObjCImpCache      objCImpCache;
  NSError            *error;
  int                 errorIsPrev;
  BOOL                mutableCollections;
};

struct JKNFastClassLookup {
  void *stringClass;
  void *numberClass;
  void *arrayClass;
  void *dictionaryClass;
  void *nullClass;
    void *dateClass;
};

struct JKNEncodeCache {
  id object;
  size_t offset;
  size_t length;
};

struct JKNEncodeState {
  JKNManagedBuffer         utf8ConversionBuffer;
  JKNManagedBuffer         stringBuffer;
  size_t                  atIndex;
  JKNFastClassLookup       fastClassLookup;
  JKNEncodeCache           cache[JKN_ENCODE_CACHE_SLOTS];
  JKNSerializeOptionFlags  serializeOptionFlags;
  JKNEncodeOptionType      encodeOption;
  size_t                  depth;
  NSError                *error;
  id                      classFormatterDelegate;
  SEL                     classFormatterSelector;
  JKNClassFormatterIMP     classFormatterIMP;
#ifdef __BLOCKS__
  JKNClassFormatterBlock   classFormatterBlock;
#endif
};

// This is a JSONKit private class.
@interface JKNSerializer : NSObject {
  JKNEncodeState *encodeState;
}

#ifdef __BLOCKS__
#define JKNSERIALIZER_BLOCKS_PROTO id(^)(id object)
#else
#define JKNSERIALIZER_BLOCKS_PROTO id
#endif

+ (id)serializeObject:(id)object options:(JKNSerializeOptionFlags)optionFlags encodeOption:(JKNEncodeOptionType)encodeOption block:(JKNSERIALIZER_BLOCKS_PROTO)block delegate:(id)delegate selector:(SEL)selector error:(NSError **)error;
- (id)serializeObject:(id)object options:(JKNSerializeOptionFlags)optionFlags encodeOption:(JKNEncodeOptionType)encodeOption block:(JKNSERIALIZER_BLOCKS_PROTO)block delegate:(id)delegate selector:(SEL)selector error:(NSError **)error;
- (void)releaseState;

@end

struct JKNHashTableEntry {
  NSUInteger keyHash;
  id key, object;
};


typedef uint32_t UTF32; /* at least 32 bits */
typedef uint16_t UTF16; /* at least 16 bits */
typedef uint8_t  UTF8;  /* typically 8 bits */

typedef enum {
  conversionOK,           /* conversion successful */
  sourceExhausted,        /* partial character in source, but hit end */
  targetExhausted,        /* insuff. room in target for conversion */
  sourceIllegal           /* source sequence is illegal/malformed */
} ConversionResult;

#define UNI_REPLACEMENT_CHAR (UTF32)0x0000FFFD
#define UNI_MAX_BMP          (UTF32)0x0000FFFF
#define UNI_MAX_UTF16        (UTF32)0x0010FFFF
#define UNI_MAX_UTF32        (UTF32)0x7FFFFFFF
#define UNI_MAX_LEGAL_UTF32  (UTF32)0x0010FFFF
#define UNI_SUR_HIGH_START   (UTF32)0xD800
#define UNI_SUR_HIGH_END     (UTF32)0xDBFF
#define UNI_SUR_LOW_START    (UTF32)0xDC00
#define UNI_SUR_LOW_END      (UTF32)0xDFFF


#if !defined(JKN_FAST_TRAILING_BYTES)
static const char trailingBytesForUTF8[256] = {
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5
};
#endif

static const UTF32 offsetsFromUTF8[6] = { 0x00000000UL, 0x00003080UL, 0x000E2080UL, 0x03C82080UL, 0xFA082080UL, 0x82082080UL };
static const UTF8  firstByteMark[7]   = { 0x00, 0x00, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC };

#define JKN_AT_STRING_PTR(x)  (&((x)->stringBuffer.bytes.ptr[(x)->atIndex]))
#define JKN_END_STRING_PTR(x) (&((x)->stringBuffer.bytes.ptr[(x)->stringBuffer.bytes.length]))


static JKNArray          *_JKNArrayCreate(id *objects, NSUInteger count, BOOL mutableCollection);
static void              _JKNArrayInsertObjectAtIndex(JKNArray *array, id newObject, NSUInteger objectIndex);
static void              _JKNArrayReplaceObjectAtIndexWithObject(JKNArray *array, NSUInteger objectIndex, id newObject);
static void              _JKNArrayRemoveObjectAtIndex(JKNArray *array, NSUInteger objectIndex);


static NSUInteger        _JKNDictionaryCapacityForCount(NSUInteger count);
static JKNDictionary     *_JKNDictionaryCreate(id *keys, NSUInteger *keyHashes, id *objects, NSUInteger count, BOOL mutableCollection);
static JKNHashTableEntry *_JKNDictionaryHashEntry(JKNDictionary *dictionary);
static NSUInteger        _JKNDictionaryCapacity(JKNDictionary *dictionary);
static void              _JKNDictionaryResizeIfNeccessary(JKNDictionary *dictionary);
static void              _JKNDictionaryRemoveObjectWithEntry(JKNDictionary *dictionary, JKNHashTableEntry *entry);
static void              _JKNDictionaryAddObject(JKNDictionary *dictionary, NSUInteger keyHash, id key, id object);
static JKNHashTableEntry *_JKNDictionaryHashTableEntryForKey(JKNDictionary *dictionary, id aKey);


static void _JSONDecoderNCleanup(JSONDecoderN *decoder);

static id _NSStringObjectFromJSONString(NSString *jsonString, JKNParseOptionFlags parseOptionFlags, NSError **error, BOOL mutableCollection);


static void JKN_managedBuffer_release(JKNManagedBuffer *managedBuffer);
static void JKN_managedBuffer_setToStackBuffer(JKNManagedBuffer *managedBuffer, unsigned char *ptr, size_t length);
static unsigned char *JKN_managedBuffer_resize(JKNManagedBuffer *managedBuffer, size_t newSize);
static void JKN_objectStack_release(JKNObjectStack *objectStack);
static void JKN_objectStack_setToStackBuffer(JKNObjectStack *objectStack, void **objects, void **keys, CFHashCode *cfHashes, size_t count);
static int  JKN_objectStack_resize(JKNObjectStack *objectStack, size_t newCount);

static void   JKN_error(JKNParseState *parseState, NSString *format, ...);
static int    JKN_parse_string(JKNParseState *parseState);
static int    JKN_parse_number(JKNParseState *parseState);
static size_t JKN_parse_is_newline(JKNParseState *parseState, const unsigned char *atCharacterPtr);
JKN_STATIC_INLINE int JKN_parse_skip_newline(JKNParseState *parseState);
JKN_STATIC_INLINE void JKN_parse_skip_whitespace(JKNParseState *parseState);
static int    JKN_parse_next_token(JKNParseState *parseState);
static void   JKN_error_parse_accept_or3(JKNParseState *parseState, int state, NSString *or1String, NSString *or2String, NSString *or3String);
static void  *JKN_create_dictionary(JKNParseState *parseState, size_t startingObjectIndex);
static void  *JKN_parse_dictionary(JKNParseState *parseState);
static void  *JKN_parse_array(JKNParseState *parseState);
static void  *JKN_object_for_token(JKNParseState *parseState);
static void  *JKN_cachedObjects(JKNParseState *parseState);
JKN_STATIC_INLINE void JKN_cache_age(JKNParseState *parseState);
JKN_STATIC_INLINE void JKN_set_parsed_token(JKNParseState *parseState, const unsigned char *ptr, size_t length, JKNTokenType type, size_t advanceBy);


static void JKN_encode_error(JKNEncodeState *encodeState, NSString *format, ...);
static int JKN_encode_printf(JKNEncodeState *encodeState, JKNEncodeCache *cacheSlot, size_t startingAtIndex, id object, const char *format, ...);
static int JKN_encode_write(JKNEncodeState *encodeState, JKNEncodeCache *cacheSlot, size_t startingAtIndex, id object, const char *format);
static int JKN_encode_writePrettyPrintWhiteSpace(JKNEncodeState *encodeState);
static int JKN_encode_write1slow(JKNEncodeState *encodeState, ssize_t depthChange, const char *format);
static int JKN_encode_write1fast(JKNEncodeState *encodeState, ssize_t depthChange JKN_UNUSED_ARG, const char *format);
static int JKN_encode_writen(JKNEncodeState *encodeState, JKNEncodeCache *cacheSlot, size_t startingAtIndex, id object, const char *format, size_t length);
JKN_STATIC_INLINE JKNHash JKN_encode_object_hash(void *objectPtr);
JKN_STATIC_INLINE void JKN_encode_updateCache(JKNEncodeState *encodeState, JKNEncodeCache *cacheSlot, size_t startingAtIndex, id object);
static int JKN_encode_add_atom_to_buffer(JKNEncodeState *encodeState, void *objectPtr);

#define JKN_encode_write1(es, dc, f)  (JKN_EXPECT_F(_JKN_encode_prettyPrint) ? JKN_encode_write1slow(es, dc, f) : JKN_encode_write1fast(es, dc, f))


JKN_STATIC_INLINE size_t JKN_min(size_t a, size_t b);
JKN_STATIC_INLINE size_t JKN_max(size_t a, size_t b);
JKN_STATIC_INLINE JKNHash JKN_calculateHash(JKNHash currentHash, unsigned char c);

// JSONKit v1.4 used both a JKNArray : NSArray and JKNMutableArray : NSMutableArray, and the same for the dictionary collection type.
// However, Louis Gerbarg (via cocoa-dev) pointed out that Cocoa / Core Foundation actually implements only a single class that inherits from the 
// mutable version, and keeps an ivar bit for whether or not that instance is mutable.  This means that the immutable versions of the collection
// classes receive the mutating methods, but this is handled by having those methods throw an exception when the ivar bit is set to immutable.
// We adopt the same strategy here.  It's both cleaner and gets rid of the method swizzling hackery used in JSONKit v1.4.


// This is a workaround for issue #23 https://github.com/johnezang/JSONKit/pull/23
// Basically, there seem to be a problem with using +load in static libraries on iOS.  However, __attribute__ ((constructor)) does work correctly.
// Since we do not require anything "special" that +load provides, and we can accomplish the same thing using __attribute__ ((constructor)), the +load logic was moved here.

static Class                               _JKNArrayClass                           = NULL;
static size_t                              _JKNArrayInstanceSize                    = 0UL;
static Class                               _JKNDictionaryClass                      = NULL;
static size_t                              _JKNDictionaryInstanceSize               = 0UL;

// For JSONDecoderN...
static Class                               _JKN_NSNumberClass                       = NULL;
static NSNumberAllocImp                    _JKN_NSNumberAllocImp                    = NULL;
static NSNumberInitWithUnsignedLongLongImp _JKN_NSNumberInitWithUnsignedLongLongImp = NULL;

extern void JKN_collectionClassLoadTimeInitialization(void) __attribute__ ((constructor));

void JKN_collectionClassLoadTimeInitialization(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // Though technically not required, the run time environment at load time initialization may be less than ideal.
  
  _JKNArrayClass             = objc_getClass("JKNArray");
  _JKNArrayInstanceSize      = JKN_max(16UL, class_getInstanceSize(_JKNArrayClass));
  
  _JKNDictionaryClass        = objc_getClass("JKNDictionary");
  _JKNDictionaryInstanceSize = JKN_max(16UL, class_getInstanceSize(_JKNDictionaryClass));
  
  // For JSONDecoderN...
  _JKN_NSNumberClass = [NSNumber class];
  _JKN_NSNumberAllocImp = (NSNumberAllocImp)[NSNumber methodForSelector:@selector(alloc)];
  
  // Hacktacular.  Need to do it this way due to the nature of class clusters.
  id temp_NSNumber = [NSNumber alloc];
  _JKN_NSNumberInitWithUnsignedLongLongImp = (NSNumberInitWithUnsignedLongLongImp)[temp_NSNumber methodForSelector:@selector(initWithUnsignedLongLong:)];
  [[temp_NSNumber init] release];
  temp_NSNumber = NULL;
  
  [pool release]; pool = NULL;
}


#pragma mark -
@interface JKNArray : NSMutableArray <NSCopying, NSMutableCopying, NSFastEnumeration> {
  id         *objects;
  NSUInteger  count, capacity, mutations;
}
@end

@implementation JKNArray

+ (id)allocWithZone:(NSZone *)zone
{
#pragma unused(zone)
  [NSException raise:NSInvalidArgumentException format:@"*** - [%@ %@]: The %@ class is private to JSONKit and should not be used in this fashion.", NSStringFromClass([self class]), NSStringFromSelector(_cmd), NSStringFromClass([self class])];
  return(NULL);
}

static JKNArray *_JKNArrayCreate(id *objects, NSUInteger count, BOOL mutableCollection) {
  NSCParameterAssert((objects != NULL) && (_JKNArrayClass != NULL) && (_JKNArrayInstanceSize > 0UL));
  JKNArray *array = NULL;
  if(JKN_EXPECT_T((array = (JKNArray *)calloc(1UL, _JKNArrayInstanceSize)) != NULL)) { // Directly allocate the JKNArray instance via calloc.
    array->isa      = _JKNArrayClass;
    if((array = [array init]) == NULL) { return(NULL); }
    array->capacity = count;
    array->count    = count;
    if(JKN_EXPECT_F((array->objects = (id *)malloc(sizeof(id) * array->capacity)) == NULL)) { [array autorelease]; return(NULL); }
    memcpy(array->objects, objects, array->capacity * sizeof(id));
    array->mutations = (mutableCollection == NO) ? 0UL : 1UL;
  }
  return(array);
}

// Note: The caller is responsible for -retaining the object that is to be added.
static void _JKNArrayInsertObjectAtIndex(JKNArray *array, id newObject, NSUInteger objectIndex) {
  NSCParameterAssert((array != NULL) && (array->objects != NULL) && (array->count <= array->capacity) && (objectIndex <= array->count) && (newObject != NULL));
  if(!((array != NULL) && (array->objects != NULL) && (objectIndex <= array->count) && (newObject != NULL))) { [newObject autorelease]; return; }
  if((array->count + 1UL) >= array->capacity) {
    id *newObjects = NULL;
    if((newObjects = (id *)realloc(array->objects, sizeof(id) * (array->capacity + 16UL))) == NULL) { [NSException raise:NSMallocException format:@"Unable to resize objects array."]; }
    array->objects = newObjects;
    array->capacity += 16UL;
    memset(&array->objects[array->count], 0, sizeof(id) * (array->capacity - array->count));
  }
  array->count++;
  if((objectIndex + 1UL) < array->count) { memmove(&array->objects[objectIndex + 1UL], &array->objects[objectIndex], sizeof(id) * ((array->count - 1UL) - objectIndex)); array->objects[objectIndex] = NULL; }
  array->objects[objectIndex] = newObject;
}

// Note: The caller is responsible for -retaining the object that is to be added.
static void _JKNArrayReplaceObjectAtIndexWithObject(JKNArray *array, NSUInteger objectIndex, id newObject) {
  NSCParameterAssert((array != NULL) && (array->objects != NULL) && (array->count <= array->capacity) && (objectIndex < array->count) && (array->objects[objectIndex] != NULL) && (newObject != NULL));
  if(!((array != NULL) && (array->objects != NULL) && (objectIndex < array->count) && (array->objects[objectIndex] != NULL) && (newObject != NULL))) { [newObject autorelease]; return; }
  CFRelease(array->objects[objectIndex]);
  array->objects[objectIndex] = NULL;
  array->objects[objectIndex] = newObject;
}

static void _JKNArrayRemoveObjectAtIndex(JKNArray *array, NSUInteger objectIndex) {
  NSCParameterAssert((array != NULL) && (array->objects != NULL) && (array->count > 0UL) && (array->count <= array->capacity) && (objectIndex < array->count) && (array->objects[objectIndex] != NULL));
  if(!((array != NULL) && (array->objects != NULL) && (array->count > 0UL) && (array->count <= array->capacity) && (objectIndex < array->count) && (array->objects[objectIndex] != NULL))) { return; }
  CFRelease(array->objects[objectIndex]);
  array->objects[objectIndex] = NULL;
  if((objectIndex + 1UL) < array->count) { memmove(&array->objects[objectIndex], &array->objects[objectIndex + 1UL], sizeof(id) * ((array->count - 1UL) - objectIndex)); array->objects[array->count - 1UL] = NULL; }
  array->count--;
}

- (void)dealloc
{
  if(JKN_EXPECT_T(objects != NULL)) {
    NSUInteger atObject = 0UL;
    for(atObject = 0UL; atObject < count; atObject++) { if(JKN_EXPECT_T(objects[atObject] != NULL)) { CFRelease(objects[atObject]); objects[atObject] = NULL; } }
    free(objects); objects = NULL;
  }
  
  [super dealloc];
}

- (NSUInteger)count
{
  NSParameterAssert((objects != NULL) && (count <= capacity));
  return(count);
}

- (void)getObjects:(id *)objectsPtr range:(NSRange)range
{
  NSParameterAssert((objects != NULL) && (count <= capacity));
  if((objectsPtr     == NULL)  && (NSMaxRange(range) > 0UL))   { [NSException raise:NSRangeException format:@"*** -[%@ %@]: pointer to objects array is NULL but range length is %lu", NSStringFromClass([self class]), NSStringFromSelector(_cmd), (unsigned long)NSMaxRange(range)];        }
  if((range.location >  count) || (NSMaxRange(range) > count)) { [NSException raise:NSRangeException format:@"*** -[%@ %@]: index (%lu) beyond bounds (%lu)",                          NSStringFromClass([self class]), NSStringFromSelector(_cmd), (unsigned long)NSMaxRange(range), (unsigned long)count]; }
#ifndef __clang_analyzer__
  memcpy(objectsPtr, objects + range.location, range.length * sizeof(id));
#endif
}

- (id)objectAtIndex:(NSUInteger)objectIndex
{
  if(objectIndex >= count) { [NSException raise:NSRangeException format:@"*** -[%@ %@]: index (%lu) beyond bounds (%lu)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), (unsigned long)objectIndex, (unsigned long)count]; }
  NSParameterAssert((objects != NULL) && (count <= capacity) && (objects[objectIndex] != NULL));
  return(objects[objectIndex]);
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
  NSParameterAssert((state != NULL) && (stackbuf != NULL) && (len > 0UL) && (objects != NULL) && (count <= capacity));
  if(JKN_EXPECT_F(state->state == 0UL))   { state->mutationsPtr = (unsigned long *)&mutations; state->itemsPtr = stackbuf; }
  if(JKN_EXPECT_F(state->state >= count)) { return(0UL); }
  
  NSUInteger enumeratedCount  = 0UL;
  while(JKN_EXPECT_T(enumeratedCount < len) && JKN_EXPECT_T(state->state < count)) { NSParameterAssert(objects[state->state] != NULL); stackbuf[enumeratedCount++] = objects[state->state++]; }
  
  return(enumeratedCount);
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)objectIndex
{
  if(mutations   == 0UL)   { [NSException raise:NSInternalInconsistencyException format:@"*** -[%@ %@]: mutating method sent to immutable object", NSStringFromClass([self class]), NSStringFromSelector(_cmd)]; }
  if(anObject    == NULL)  { [NSException raise:NSInvalidArgumentException       format:@"*** -[%@ %@]: attempt to insert nil",                    NSStringFromClass([self class]), NSStringFromSelector(_cmd)]; }
  if(objectIndex >  count) { [NSException raise:NSRangeException                 format:@"*** -[%@ %@]: index (%lu) beyond bounds (%lu)",          NSStringFromClass([self class]), NSStringFromSelector(_cmd), (unsigned long)objectIndex, (unsigned long)(count + 1UL)]; }
#ifdef __clang_analyzer__
  [anObject retain]; // Stupid clang analyzer...  Issue #19.
#else
  anObject = [anObject retain];
#endif
  _JKNArrayInsertObjectAtIndex(self, anObject, objectIndex);
  mutations = (mutations == NSUIntegerMax) ? 1UL : mutations + 1UL;
}

- (void)removeObjectAtIndex:(NSUInteger)objectIndex
{
  if(mutations   == 0UL)   { [NSException raise:NSInternalInconsistencyException format:@"*** -[%@ %@]: mutating method sent to immutable object", NSStringFromClass([self class]), NSStringFromSelector(_cmd)]; }
  if(objectIndex >= count) { [NSException raise:NSRangeException                 format:@"*** -[%@ %@]: index (%lu) beyond bounds (%lu)",          NSStringFromClass([self class]), NSStringFromSelector(_cmd), (unsigned long)objectIndex, (unsigned long)count]; }
  _JKNArrayRemoveObjectAtIndex(self, objectIndex);
  mutations = (mutations == NSUIntegerMax) ? 1UL : mutations + 1UL;
}

- (void)replaceObjectAtIndex:(NSUInteger)objectIndex withObject:(id)anObject
{
  if(mutations   == 0UL)   { [NSException raise:NSInternalInconsistencyException format:@"*** -[%@ %@]: mutating method sent to immutable object", NSStringFromClass([self class]), NSStringFromSelector(_cmd)]; }
  if(anObject    == NULL)  { [NSException raise:NSInvalidArgumentException       format:@"*** -[%@ %@]: attempt to insert nil",                    NSStringFromClass([self class]), NSStringFromSelector(_cmd)]; }
  if(objectIndex >= count) { [NSException raise:NSRangeException                 format:@"*** -[%@ %@]: index (%lu) beyond bounds (%lu)",          NSStringFromClass([self class]), NSStringFromSelector(_cmd), (unsigned long)objectIndex, (unsigned long)count]; }
#ifdef __clang_analyzer__
  [anObject retain]; // Stupid clang analyzer...  Issue #19.
#else
  anObject = [anObject retain];
#endif
  _JKNArrayReplaceObjectAtIndexWithObject(self, objectIndex, anObject);
  mutations = (mutations == NSUIntegerMax) ? 1UL : mutations + 1UL;
}

- (id)copyWithZone:(NSZone *)zone
{
  NSParameterAssert((objects != NULL) && (count <= capacity));
  return((mutations == 0UL) ? [self retain] : [(NSArray *)[NSArray allocWithZone:zone] initWithObjects:objects count:count]);
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
  NSParameterAssert((objects != NULL) && (count <= capacity));
  return([(NSMutableArray *)[NSMutableArray allocWithZone:zone] initWithObjects:objects count:count]);
}

@end


#pragma mark -
@interface JKNDictionaryEnumerator : NSEnumerator {
  id         collection;
  NSUInteger nextObject;
}

- (id)initWithJKNDictionary:(JKNDictionary *)initDictionary;
- (NSArray *)allObjects;
- (id)nextObject;

@end

@implementation JKNDictionaryEnumerator

- (id)initWithJKNDictionary:(JKNDictionary *)initDictionary
{
  NSParameterAssert(initDictionary != NULL);
  if((self = [super init]) == NULL) { return(NULL); }
  if((collection = (id)CFRetain(initDictionary)) == NULL) { [self autorelease]; return(NULL); }
  return(self);
}

- (void)dealloc
{
  if(collection != NULL) { CFRelease(collection); collection = NULL; }
  [super dealloc];
}

- (NSArray *)allObjects
{
  NSParameterAssert(collection != NULL);
  NSUInteger count = [(NSDictionary *)collection count], atObject = 0UL;
  id         objects[count];

  while((objects[atObject] = [self nextObject]) != NULL) { NSParameterAssert(atObject < count); atObject++; }

  return([NSArray arrayWithObjects:objects count:atObject]);
}

- (id)nextObject
{
  NSParameterAssert((collection != NULL) && (_JKNDictionaryHashEntry(collection) != NULL));
  JKNHashTableEntry *entry        = _JKNDictionaryHashEntry(collection);
  NSUInteger        capacity     = _JKNDictionaryCapacity(collection);
  id                returnObject = NULL;

  if(entry != NULL) { while((nextObject < capacity) && ((returnObject = entry[nextObject++].key) == NULL)) { /* ... */ } }
  
  return(returnObject);
}

@end

#pragma mark -
@interface JKNDictionary : NSMutableDictionary <NSCopying, NSMutableCopying, NSFastEnumeration> {
  NSUInteger count, capacity, mutations;
  JKNHashTableEntry *entry;
}
@end

@implementation JKNDictionary

+ (id)allocWithZone:(NSZone *)zone
{
#pragma unused(zone)
  [NSException raise:NSInvalidArgumentException format:@"*** - [%@ %@]: The %@ class is private to JSONKit and should not be used in this fashion.", NSStringFromClass([self class]), NSStringFromSelector(_cmd), NSStringFromClass([self class])];
  return(NULL);
}

// These values are taken from Core Foundation CF-550 CFBasicHash.m.  As a bonus, they align very well with our JKNHashTableEntry struct too.
static const NSUInteger JKN_dictionaryCapacities[] = {
  0UL, 3UL, 7UL, 13UL, 23UL, 41UL, 71UL, 127UL, 191UL, 251UL, 383UL, 631UL, 1087UL, 1723UL,
  2803UL, 4523UL, 7351UL, 11959UL, 19447UL, 31231UL, 50683UL, 81919UL, 132607UL,
  214519UL, 346607UL, 561109UL, 907759UL, 1468927UL, 2376191UL, 3845119UL,
  6221311UL, 10066421UL, 16287743UL, 26354171UL, 42641881UL, 68996069UL,
  111638519UL, 180634607UL, 292272623UL, 472907251UL
};

static NSUInteger _JKNDictionaryCapacityForCount(NSUInteger count) {
  NSUInteger bottom = 0UL, top = sizeof(JKN_dictionaryCapacities) / sizeof(NSUInteger), mid = 0UL, tableSize = (NSUInteger)lround(floor(((double)count) * 1.33));
  while(top > bottom) { mid = (top + bottom) / 2UL; if(JKN_dictionaryCapacities[mid] < tableSize) { bottom = mid + 1UL; } else { top = mid; } }
  return(JKN_dictionaryCapacities[bottom]);
}

static void _JKNDictionaryResizeIfNeccessary(JKNDictionary *dictionary) {
  NSCParameterAssert((dictionary != NULL) && (dictionary->entry != NULL) && (dictionary->count <= dictionary->capacity));

  NSUInteger capacityForCount = 0UL;
  if(dictionary->capacity < (capacityForCount = _JKNDictionaryCapacityForCount(dictionary->count + 1UL))) { // resize
    NSUInteger        oldCapacity = dictionary->capacity;
#ifndef NS_BLOCK_ASSERTIONS
    NSUInteger oldCount = dictionary->count;
#endif
    JKNHashTableEntry *oldEntry    = dictionary->entry;
    if(JKN_EXPECT_F((dictionary->entry = (JKNHashTableEntry *)calloc(1UL, sizeof(JKNHashTableEntry) * capacityForCount)) == NULL)) { [NSException raise:NSMallocException format:@"Unable to allocate memory for hash table."]; }
    dictionary->capacity = capacityForCount;
    dictionary->count    = 0UL;
    
    NSUInteger idx = 0UL;
    for(idx = 0UL; idx < oldCapacity; idx++) { if(oldEntry[idx].key != NULL) { _JKNDictionaryAddObject(dictionary, oldEntry[idx].keyHash, oldEntry[idx].key, oldEntry[idx].object); oldEntry[idx].keyHash = 0UL; oldEntry[idx].key = NULL; oldEntry[idx].object = NULL; } }
    NSCParameterAssert((oldCount == dictionary->count));
    free(oldEntry); oldEntry = NULL;
  }
}

static JKNDictionary *_JKNDictionaryCreate(id *keys, NSUInteger *keyHashes, id *objects, NSUInteger count, BOOL mutableCollection) {
  NSCParameterAssert((keys != NULL) && (keyHashes != NULL) && (objects != NULL) && (_JKNDictionaryClass != NULL) && (_JKNDictionaryInstanceSize > 0UL));
  JKNDictionary *dictionary = NULL;
  if(JKN_EXPECT_T((dictionary = (JKNDictionary *)calloc(1UL, _JKNDictionaryInstanceSize)) != NULL)) { // Directly allocate the JKNDictionary instance via calloc.
    dictionary->isa      = _JKNDictionaryClass;
    if((dictionary = [dictionary init]) == NULL) { return(NULL); }
    dictionary->capacity = _JKNDictionaryCapacityForCount(count);
    dictionary->count    = 0UL;
    
    if(JKN_EXPECT_F((dictionary->entry = (JKNHashTableEntry *)calloc(1UL, sizeof(JKNHashTableEntry) * dictionary->capacity)) == NULL)) { [dictionary autorelease]; return(NULL); }

    NSUInteger idx = 0UL;
    for(idx = 0UL; idx < count; idx++) { _JKNDictionaryAddObject(dictionary, keyHashes[idx], keys[idx], objects[idx]); }

    dictionary->mutations = (mutableCollection == NO) ? 0UL : 1UL;
  }
  return(dictionary);
}

- (void)dealloc
{
  if(JKN_EXPECT_T(entry != NULL)) {
    NSUInteger atEntry = 0UL;
    for(atEntry = 0UL; atEntry < capacity; atEntry++) {
      if(JKN_EXPECT_T(entry[atEntry].key    != NULL)) { CFRelease(entry[atEntry].key);    entry[atEntry].key    = NULL; }
      if(JKN_EXPECT_T(entry[atEntry].object != NULL)) { CFRelease(entry[atEntry].object); entry[atEntry].object = NULL; }
    }
  
    free(entry); entry = NULL;
  }

  [super dealloc];
}

static JKNHashTableEntry *_JKNDictionaryHashEntry(JKNDictionary *dictionary) {
  NSCParameterAssert(dictionary != NULL);
  return(dictionary->entry);
}

static NSUInteger _JKNDictionaryCapacity(JKNDictionary *dictionary) {
  NSCParameterAssert(dictionary != NULL);
  return(dictionary->capacity);
}

static void _JKNDictionaryRemoveObjectWithEntry(JKNDictionary *dictionary, JKNHashTableEntry *entry) {
  NSCParameterAssert((dictionary != NULL) && (entry != NULL) && (entry->key != NULL) && (entry->object != NULL) && (dictionary->count > 0UL) && (dictionary->count <= dictionary->capacity));
  CFRelease(entry->key);    entry->key    = NULL;
  CFRelease(entry->object); entry->object = NULL;
  entry->keyHash = 0UL;
  dictionary->count--;
  // In order for certain invariants that are used to speed up the search for a particular key, we need to "re-add" all the entries in the hash table following this entry until we hit a NULL entry.
  NSUInteger removeIdx = entry - dictionary->entry, idx = 0UL;
  NSCParameterAssert((removeIdx < dictionary->capacity));
  for(idx = 0UL; idx < dictionary->capacity; idx++) {
    NSUInteger entryIdx = (removeIdx + idx + 1UL) % dictionary->capacity;
    JKNHashTableEntry *atEntry = &dictionary->entry[entryIdx];
    if(atEntry->key == NULL) { break; }
    NSUInteger keyHash = atEntry->keyHash;
    id key = atEntry->key, object = atEntry->object;
    NSCParameterAssert(object != NULL);
    atEntry->keyHash = 0UL;
    atEntry->key     = NULL;
    atEntry->object  = NULL;
    NSUInteger addKeyEntry = keyHash % dictionary->capacity, addIdx = 0UL;
    for(addIdx = 0UL; addIdx < dictionary->capacity; addIdx++) {
      JKNHashTableEntry *atAddEntry = &dictionary->entry[((addKeyEntry + addIdx) % dictionary->capacity)];
      if(JKN_EXPECT_T(atAddEntry->key == NULL)) { NSCParameterAssert((atAddEntry->keyHash == 0UL) && (atAddEntry->object == NULL)); atAddEntry->key = key; atAddEntry->object = object; atAddEntry->keyHash = keyHash; break; }
    }
  }
}

static void _JKNDictionaryAddObject(JKNDictionary *dictionary, NSUInteger keyHash, id key, id object) {
  NSCParameterAssert((dictionary != NULL) && (key != NULL) && (object != NULL) && (dictionary->count < dictionary->capacity) && (dictionary->entry != NULL));
  NSUInteger keyEntry = keyHash % dictionary->capacity, idx = 0UL;
  for(idx = 0UL; idx < dictionary->capacity; idx++) {
    NSUInteger entryIdx = (keyEntry + idx) % dictionary->capacity;
    JKNHashTableEntry *atEntry = &dictionary->entry[entryIdx];
    if(JKN_EXPECT_F(atEntry->keyHash == keyHash) && JKN_EXPECT_T(atEntry->key != NULL) && (JKN_EXPECT_F(key == atEntry->key) || JKN_EXPECT_F(CFEqual(atEntry->key, key)))) { _JKNDictionaryRemoveObjectWithEntry(dictionary, atEntry); }
    if(JKN_EXPECT_T(atEntry->key == NULL)) { NSCParameterAssert((atEntry->keyHash == 0UL) && (atEntry->object == NULL)); atEntry->key = key; atEntry->object = object; atEntry->keyHash = keyHash; dictionary->count++; return; }
  }

  // We should never get here.  If we do, we -release the key / object because it's our responsibility.
  CFRelease(key);
  CFRelease(object);
}

- (NSUInteger)count
{
  return(count);
}

static JKNHashTableEntry *_JKNDictionaryHashTableEntryForKey(JKNDictionary *dictionary, id aKey) {
  NSCParameterAssert((dictionary != NULL) && (dictionary->entry != NULL) && (dictionary->count <= dictionary->capacity));
  if((aKey == NULL) || (dictionary->capacity == 0UL)) { return(NULL); }
  NSUInteger        keyHash = CFHash(aKey), keyEntry = (keyHash % dictionary->capacity), idx = 0UL;
  JKNHashTableEntry *atEntry = NULL;
  for(idx = 0UL; idx < dictionary->capacity; idx++) {
    atEntry = &dictionary->entry[(keyEntry + idx) % dictionary->capacity];
    if(JKN_EXPECT_T(atEntry->keyHash == keyHash) && JKN_EXPECT_T(atEntry->key != NULL) && ((atEntry->key == aKey) || CFEqual(atEntry->key, aKey))) { NSCParameterAssert(atEntry->object != NULL); return(atEntry); break; }
    if(JKN_EXPECT_F(atEntry->key == NULL)) { NSCParameterAssert(atEntry->object == NULL); return(NULL); break; } // If the key was in the table, we would have found it by now.
  }
  return(NULL);
}

- (id)objectForKey:(id)aKey
{
  NSParameterAssert((entry != NULL) && (count <= capacity));
  JKNHashTableEntry *entryForKey = _JKNDictionaryHashTableEntryForKey(self, aKey);
  return((entryForKey != NULL) ? entryForKey->object : NULL);
}

- (void)getObjects:(id *)objects andKeys:(id *)keys
{
  NSParameterAssert((entry != NULL) && (count <= capacity));
  NSUInteger atEntry = 0UL; NSUInteger arrayIdx = 0UL;
  for(atEntry = 0UL; atEntry < capacity; atEntry++) {
    if(JKN_EXPECT_T(entry[atEntry].key != NULL)) {
      NSCParameterAssert((entry[atEntry].object != NULL) && (arrayIdx < count));
      if(JKN_EXPECT_T(keys    != NULL)) { keys[arrayIdx]    = entry[atEntry].key;    }
      if(JKN_EXPECT_T(objects != NULL)) { objects[arrayIdx] = entry[atEntry].object; }
      arrayIdx++;
    }
  }
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
  NSParameterAssert((state != NULL) && (stackbuf != NULL) && (len > 0UL) && (entry != NULL) && (count <= capacity));
  if(JKN_EXPECT_F(state->state == 0UL))      { state->mutationsPtr = (unsigned long *)&mutations; state->itemsPtr = stackbuf; }
  if(JKN_EXPECT_F(state->state >= capacity)) { return(0UL); }
  
  NSUInteger enumeratedCount  = 0UL;
  while(JKN_EXPECT_T(enumeratedCount < len) && JKN_EXPECT_T(state->state < capacity)) { if(JKN_EXPECT_T(entry[state->state].key != NULL)) { stackbuf[enumeratedCount++] = entry[state->state].key; } state->state++; }
    
  return(enumeratedCount);
}

- (NSEnumerator *)keyEnumerator
{
  return([[[JKNDictionaryEnumerator alloc] initWithJKNDictionary:self] autorelease]);
}

- (void)setObject:(id)anObject forKey:(id)aKey
{
  if(mutations == 0UL)  { [NSException raise:NSInternalInconsistencyException format:@"*** -[%@ %@]: mutating method sent to immutable object", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];       }
  if(aKey      == NULL) { [NSException raise:NSInvalidArgumentException       format:@"*** -[%@ %@]: attempt to insert nil key",                NSStringFromClass([self class]), NSStringFromSelector(_cmd)];       }
  if(anObject  == NULL) { [NSException raise:NSInvalidArgumentException       format:@"*** -[%@ %@]: attempt to insert nil value (key: %@)",    NSStringFromClass([self class]), NSStringFromSelector(_cmd), aKey]; }
  
  _JKNDictionaryResizeIfNeccessary(self);
#ifndef __clang_analyzer__
  aKey     = [aKey     copy];   // Why on earth would clang complain that this -copy "might leak", 
  anObject = [anObject retain]; // but this -retain doesn't!?
#endif // __clang_analyzer__
  _JKNDictionaryAddObject(self, CFHash(aKey), aKey, anObject);
  mutations = (mutations == NSUIntegerMax) ? 1UL : mutations + 1UL;
}

- (void)removeObjectForKey:(id)aKey
{
  if(mutations == 0UL)  { [NSException raise:NSInternalInconsistencyException format:@"*** -[%@ %@]: mutating method sent to immutable object", NSStringFromClass([self class]), NSStringFromSelector(_cmd)]; }
  if(aKey      == NULL) { [NSException raise:NSInvalidArgumentException       format:@"*** -[%@ %@]: attempt to remove nil key",                NSStringFromClass([self class]), NSStringFromSelector(_cmd)]; }
  JKNHashTableEntry *entryForKey = _JKNDictionaryHashTableEntryForKey(self, aKey);
  if(entryForKey != NULL) {
    _JKNDictionaryRemoveObjectWithEntry(self, entryForKey);
    mutations = (mutations == NSUIntegerMax) ? 1UL : mutations + 1UL;
  }
}

- (id)copyWithZone:(NSZone *)zone
{
  NSParameterAssert((entry != NULL) && (count <= capacity));
  return((mutations == 0UL) ? [self retain] : [[NSDictionary allocWithZone:zone] initWithDictionary:self]);
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
  NSParameterAssert((entry != NULL) && (count <= capacity));
  return([[NSMutableDictionary allocWithZone:zone] initWithDictionary:self]);
}

@end



#pragma mark -

JKN_STATIC_INLINE size_t JKN_min(size_t a, size_t b) { return((a < b) ? a : b); }
JKN_STATIC_INLINE size_t JKN_max(size_t a, size_t b) { return((a > b) ? a : b); }

JKN_STATIC_INLINE JKNHash JKN_calculateHash(JKNHash currentHash, unsigned char c) { return((((currentHash << 5) + currentHash) + (c - 29)) ^ (currentHash >> 19)); }


static void JKN_error(JKNParseState *parseState, NSString *format, ...) {
  NSCParameterAssert((parseState != NULL) && (format != NULL));

  va_list varArgsList;
  va_start(varArgsList, format);
  NSString *formatString = [[[NSString alloc] initWithFormat:format arguments:varArgsList] autorelease];
  va_end(varArgsList);

#if 0
  const unsigned char *lineStart      = parseState->stringBuffer.bytes.ptr + parseState->lineStartIndex;
  const unsigned char *lineEnd        = lineStart;
  const unsigned char *atCharacterPtr = NULL;

  for(atCharacterPtr = lineStart; atCharacterPtr < JKN_END_STRING_PTR(parseState); atCharacterPtr++) { lineEnd = atCharacterPtr; if(JKN_parse_is_newline(parseState, atCharacterPtr)) { break; } }

  NSString *lineString = @"", *carretString = @"";
  if(lineStart < JKN_END_STRING_PTR(parseState)) {
    lineString   = [[[NSString alloc] initWithBytes:lineStart length:(lineEnd - lineStart) encoding:NSUTF8StringEncoding] autorelease];
    carretString = [NSString stringWithFormat:@"%*.*s^", (int)(parseState->atIndex - parseState->lineStartIndex), (int)(parseState->atIndex - parseState->lineStartIndex), " "];
  }
#endif

  if(parseState->error == NULL) {
    parseState->error = [NSError errorWithDomain:@"JKNErrorDomain" code:-1L userInfo:
                                   [NSDictionary dictionaryWithObjectsAndKeys:
                                                                              formatString,                                             NSLocalizedDescriptionKey,
                                                                              [NSNumber numberWithUnsignedLong:parseState->atIndex],    @"JKNAtIndexKey",
                                                                              [NSNumber numberWithUnsignedLong:parseState->lineNumber], @"JKNLineNumberKey",
                                                 //lineString,   @"JKNErrorLine0Key",
                                                 //carretString, @"JKNErrorLine1Key",
                                                                              NULL]];
  }
}

#pragma mark -
#pragma mark Buffer and Object Stack management functions

static void JKN_managedBuffer_release(JKNManagedBuffer *managedBuffer) {
  if((managedBuffer->flags & JKNManagedBufferMustFree)) {
    if(managedBuffer->bytes.ptr != NULL) { free(managedBuffer->bytes.ptr); managedBuffer->bytes.ptr = NULL; }
    managedBuffer->flags &= ~JKNManagedBufferMustFree;
  }

  managedBuffer->bytes.ptr     = NULL;
  managedBuffer->bytes.length  = 0UL;
  managedBuffer->flags        &= ~JKNManagedBufferLocationMask;
}

static void JKN_managedBuffer_setToStackBuffer(JKNManagedBuffer *managedBuffer, unsigned char *ptr, size_t length) {
  JKN_managedBuffer_release(managedBuffer);
  managedBuffer->bytes.ptr     = ptr;
  managedBuffer->bytes.length  = length;
  managedBuffer->flags         = (managedBuffer->flags & ~JKNManagedBufferLocationMask) | JKNManagedBufferOnStack;
}

static unsigned char *JKN_managedBuffer_resize(JKNManagedBuffer *managedBuffer, size_t newSize) {
  size_t roundedUpNewSize = newSize;

  if(managedBuffer->roundSizeUpToMultipleOf > 0UL) { roundedUpNewSize = newSize + ((managedBuffer->roundSizeUpToMultipleOf - (newSize % managedBuffer->roundSizeUpToMultipleOf)) % managedBuffer->roundSizeUpToMultipleOf); }

  if((roundedUpNewSize != managedBuffer->bytes.length) && (roundedUpNewSize > managedBuffer->bytes.length)) {
    if((managedBuffer->flags & JKNManagedBufferLocationMask) == JKNManagedBufferOnStack) {
      NSCParameterAssert((managedBuffer->flags & JKNManagedBufferMustFree) == 0);
      unsigned char *newBuffer = NULL, *oldBuffer = managedBuffer->bytes.ptr;
      
      if((newBuffer = (unsigned char *)malloc(roundedUpNewSize)) == NULL) { return(NULL); }
      memcpy(newBuffer, oldBuffer, JKN_min(managedBuffer->bytes.length, roundedUpNewSize));
      managedBuffer->flags        = (managedBuffer->flags & ~JKNManagedBufferLocationMask) | (JKNManagedBufferOnHeap | JKNManagedBufferMustFree);
      managedBuffer->bytes.ptr    = newBuffer;
      managedBuffer->bytes.length = roundedUpNewSize;
    } else {
      NSCParameterAssert(((managedBuffer->flags & JKNManagedBufferMustFree) != 0) && ((managedBuffer->flags & JKNManagedBufferLocationMask) == JKNManagedBufferOnHeap));
      if((managedBuffer->bytes.ptr = (unsigned char *)reallocf(managedBuffer->bytes.ptr, roundedUpNewSize)) == NULL) { return(NULL); }
      managedBuffer->bytes.length = roundedUpNewSize;
    }
  }

  return(managedBuffer->bytes.ptr);
}



static void JKN_objectStack_release(JKNObjectStack *objectStack) {
  NSCParameterAssert(objectStack != NULL);

  NSCParameterAssert(objectStack->index <= objectStack->count);
  size_t atIndex = 0UL;
  for(atIndex = 0UL; atIndex < objectStack->index; atIndex++) {
    if(objectStack->objects[atIndex] != NULL) { CFRelease(objectStack->objects[atIndex]); objectStack->objects[atIndex] = NULL; }
    if(objectStack->keys[atIndex]    != NULL) { CFRelease(objectStack->keys[atIndex]);    objectStack->keys[atIndex]    = NULL; }
  }
  objectStack->index = 0UL;

  if(objectStack->flags & JKNObjectStackMustFree) {
    NSCParameterAssert((objectStack->flags & JKNObjectStackLocationMask) == JKNObjectStackOnHeap);
    if(objectStack->objects  != NULL) { free(objectStack->objects);  objectStack->objects  = NULL; }
    if(objectStack->keys     != NULL) { free(objectStack->keys);     objectStack->keys     = NULL; }
    if(objectStack->cfHashes != NULL) { free(objectStack->cfHashes); objectStack->cfHashes = NULL; }
    objectStack->flags &= ~JKNObjectStackMustFree;
  }

  objectStack->objects  = NULL;
  objectStack->keys     = NULL;
  objectStack->cfHashes = NULL;

  objectStack->count    = 0UL;
  objectStack->flags   &= ~JKNObjectStackLocationMask;
}

static void JKN_objectStack_setToStackBuffer(JKNObjectStack *objectStack, void **objects, void **keys, CFHashCode *cfHashes, size_t count) {
  NSCParameterAssert((objectStack != NULL) && (objects != NULL) && (keys != NULL) && (cfHashes != NULL) && (count > 0UL));
  JKN_objectStack_release(objectStack);
  objectStack->objects  = objects;
  objectStack->keys     = keys;
  objectStack->cfHashes = cfHashes;
  objectStack->count    = count;
  objectStack->flags    = (objectStack->flags & ~JKNObjectStackLocationMask) | JKNObjectStackOnStack;
#ifndef NS_BLOCK_ASSERTIONS
  size_t idx;
  for(idx = 0UL; idx < objectStack->count; idx++) { objectStack->objects[idx] = NULL; objectStack->keys[idx] = NULL; objectStack->cfHashes[idx] = 0UL; }
#endif
}

static int JKN_objectStack_resize(JKNObjectStack *objectStack, size_t newCount) {
  size_t roundedUpNewCount = newCount;
  int    returnCode = 0;

  void       **newObjects  = NULL, **newKeys = NULL;
  CFHashCode  *newCFHashes = NULL;

  if(objectStack->roundSizeUpToMultipleOf > 0UL) { roundedUpNewCount = newCount + ((objectStack->roundSizeUpToMultipleOf - (newCount % objectStack->roundSizeUpToMultipleOf)) % objectStack->roundSizeUpToMultipleOf); }

  if((roundedUpNewCount != objectStack->count) && (roundedUpNewCount > objectStack->count)) {
    if((objectStack->flags & JKNObjectStackLocationMask) == JKNObjectStackOnStack) {
      NSCParameterAssert((objectStack->flags & JKNObjectStackMustFree) == 0);

      if((newObjects  = (void **     )calloc(1UL, roundedUpNewCount * sizeof(void *    ))) == NULL) { returnCode = 1; goto errorExit; }
      memcpy(newObjects, objectStack->objects,   JKN_min(objectStack->count, roundedUpNewCount) * sizeof(void *));
      if((newKeys     = (void **     )calloc(1UL, roundedUpNewCount * sizeof(void *    ))) == NULL) { returnCode = 1; goto errorExit; }
      memcpy(newKeys,     objectStack->keys,     JKN_min(objectStack->count, roundedUpNewCount) * sizeof(void *));

      if((newCFHashes = (CFHashCode *)calloc(1UL, roundedUpNewCount * sizeof(CFHashCode))) == NULL) { returnCode = 1; goto errorExit; }
      memcpy(newCFHashes, objectStack->cfHashes, JKN_min(objectStack->count, roundedUpNewCount) * sizeof(CFHashCode));

      objectStack->flags    = (objectStack->flags & ~JKNObjectStackLocationMask) | (JKNObjectStackOnHeap | JKNObjectStackMustFree);
      objectStack->objects  = newObjects;  newObjects  = NULL;
      objectStack->keys     = newKeys;     newKeys     = NULL;
      objectStack->cfHashes = newCFHashes; newCFHashes = NULL;
      objectStack->count    = roundedUpNewCount;
    } else {
      NSCParameterAssert(((objectStack->flags & JKNObjectStackMustFree) != 0) && ((objectStack->flags & JKNObjectStackLocationMask) == JKNObjectStackOnHeap));
      if((newObjects  = (void  **    )realloc(objectStack->objects,  roundedUpNewCount * sizeof(void *    ))) != NULL) { objectStack->objects  = newObjects;  newObjects  = NULL; } else { returnCode = 1; goto errorExit; }
      if((newKeys     = (void  **    )realloc(objectStack->keys,     roundedUpNewCount * sizeof(void *    ))) != NULL) { objectStack->keys     = newKeys;     newKeys     = NULL; } else { returnCode = 1; goto errorExit; }
      if((newCFHashes = (CFHashCode *)realloc(objectStack->cfHashes, roundedUpNewCount * sizeof(CFHashCode))) != NULL) { objectStack->cfHashes = newCFHashes; newCFHashes = NULL; } else { returnCode = 1; goto errorExit; }

#ifndef NS_BLOCK_ASSERTIONS
      size_t idx;
      for(idx = objectStack->count; idx < roundedUpNewCount; idx++) { objectStack->objects[idx] = NULL; objectStack->keys[idx] = NULL; objectStack->cfHashes[idx] = 0UL; }
#endif
      objectStack->count = roundedUpNewCount;
    }
  }

 errorExit:
  if(newObjects  != NULL) { free(newObjects);  newObjects  = NULL; }
  if(newKeys     != NULL) { free(newKeys);     newKeys     = NULL; }
  if(newCFHashes != NULL) { free(newCFHashes); newCFHashes = NULL; }

  return(returnCode);
}

////////////
#pragma mark -
#pragma mark Unicode related functions

JKN_STATIC_INLINE ConversionResult isValidCodePoint(UTF32 *u32CodePoint) {
  ConversionResult result = conversionOK;
  UTF32            ch     = *u32CodePoint;

  if(JKN_EXPECT_F(ch >= UNI_SUR_HIGH_START) && (JKN_EXPECT_T(ch <= UNI_SUR_LOW_END)))                                                        { result = sourceIllegal; ch = UNI_REPLACEMENT_CHAR; goto finished; }
  if(JKN_EXPECT_F(ch >= 0xFDD0U) && (JKN_EXPECT_F(ch <= 0xFDEFU) || JKN_EXPECT_F((ch & 0xFFFEU) == 0xFFFEU)) && JKN_EXPECT_T(ch <= 0x10FFFFU)) { result = sourceIllegal; ch = UNI_REPLACEMENT_CHAR; goto finished; }
  if(JKN_EXPECT_F(ch == 0U))                                                                                                                { result = sourceIllegal; ch = UNI_REPLACEMENT_CHAR; goto finished; }

 finished:
  *u32CodePoint = ch;
  return(result);
}


static int isLegalUTF8(const UTF8 *source, size_t length) {
  const UTF8 *srcptr = source + length;
  UTF8 a;

  switch(length) {
    default: return(0); // Everything else falls through when "true"...
    case 4: if(JKN_EXPECT_F(((a = (*--srcptr)) < 0x80) || (a > 0xBF))) { return(0); }
    case 3: if(JKN_EXPECT_F(((a = (*--srcptr)) < 0x80) || (a > 0xBF))) { return(0); }
    case 2: if(JKN_EXPECT_F( (a = (*--srcptr)) > 0xBF               )) { return(0); }
      
      switch(*source) { // no fall-through in this inner switch
        case 0xE0: if(JKN_EXPECT_F(a < 0xA0)) { return(0); } break;
        case 0xED: if(JKN_EXPECT_F(a > 0x9F)) { return(0); } break;
        case 0xF0: if(JKN_EXPECT_F(a < 0x90)) { return(0); } break;
        case 0xF4: if(JKN_EXPECT_F(a > 0x8F)) { return(0); } break;
        default:   if(JKN_EXPECT_F(a < 0x80)) { return(0); }
      }
      
    case 1: if(JKN_EXPECT_F((JKN_EXPECT_T(*source < 0xC2)) && JKN_EXPECT_F(*source >= 0x80))) { return(0); }
  }

  if(JKN_EXPECT_F(*source > 0xF4)) { return(0); }

  return(1);
}

static ConversionResult ConvertSingleCodePointInUTF8(const UTF8 *sourceStart, const UTF8 *sourceEnd, UTF8 const **nextUTF8, UTF32 *convertedUTF32) {
  ConversionResult result = conversionOK;
  const UTF8 *source = sourceStart;
  UTF32 ch = 0UL;

#if !defined(JKN_FAST_TRAILING_BYTES)
  unsigned short extraBytesToRead = trailingBytesForUTF8[*source];
#else
  unsigned short extraBytesToRead = __builtin_clz(((*source)^0xff) << 25);
#endif

  if(JKN_EXPECT_F((source + extraBytesToRead + 1) > sourceEnd) || JKN_EXPECT_F(!isLegalUTF8(source, extraBytesToRead + 1))) {
    source++;
    while((source < sourceEnd) && (((*source) & 0xc0) == 0x80) && ((source - sourceStart) < (extraBytesToRead + 1))) { source++; } 
    NSCParameterAssert(source <= sourceEnd);
    result = ((source < sourceEnd) && (((*source) & 0xc0) != 0x80)) ? sourceIllegal : ((sourceStart + extraBytesToRead + 1) > sourceEnd) ? sourceExhausted : sourceIllegal;
    ch = UNI_REPLACEMENT_CHAR;
    goto finished;
  }

  switch(extraBytesToRead) { // The cases all fall through.
    case 5: ch += *source++; ch <<= 6;
    case 4: ch += *source++; ch <<= 6;
    case 3: ch += *source++; ch <<= 6;
    case 2: ch += *source++; ch <<= 6;
    case 1: ch += *source++; ch <<= 6;
    case 0: ch += *source++;
  }
  ch -= offsetsFromUTF8[extraBytesToRead];

  result = isValidCodePoint(&ch);
  
 finished:
  *nextUTF8       = source;
  *convertedUTF32 = ch;
  
  return(result);
}


static ConversionResult ConvertUTF32toUTF8 (UTF32 u32CodePoint, UTF8 **targetStart, UTF8 *targetEnd) {
  const UTF32       byteMask     = 0xBF, byteMark = 0x80;
  ConversionResult  result       = conversionOK;
  UTF8             *target       = *targetStart;
  UTF32             ch           = u32CodePoint;
  unsigned short    bytesToWrite = 0;

  result = isValidCodePoint(&ch);

  // Figure out how many bytes the result will require. Turn any illegally large UTF32 things (> Plane 17) into replacement chars.
       if(ch < (UTF32)0x80)          { bytesToWrite = 1; }
  else if(ch < (UTF32)0x800)         { bytesToWrite = 2; }
  else if(ch < (UTF32)0x10000)       { bytesToWrite = 3; }
  else if(ch <= UNI_MAX_LEGAL_UTF32) { bytesToWrite = 4; }
  else {                               bytesToWrite = 3; ch = UNI_REPLACEMENT_CHAR; result = sourceIllegal; }
        
  target += bytesToWrite;
  if (target > targetEnd) { target -= bytesToWrite; result = targetExhausted; goto finished; }

  switch (bytesToWrite) { // note: everything falls through.
    case 4: *--target = (UTF8)((ch | byteMark) & byteMask); ch >>= 6;
    case 3: *--target = (UTF8)((ch | byteMark) & byteMask); ch >>= 6;
    case 2: *--target = (UTF8)((ch | byteMark) & byteMask); ch >>= 6;
    case 1: *--target = (UTF8) (ch | firstByteMark[bytesToWrite]);
  }

  target += bytesToWrite;

 finished:
  *targetStart = target;
  return(result);
}

JKN_STATIC_INLINE int JKN_string_add_unicodeCodePoint(JKNParseState *parseState, uint32_t unicodeCodePoint, size_t *tokenBufferIdx, JKNHash *stringHash) {
  UTF8             *u8s = &parseState->token.tokenBuffer.bytes.ptr[*tokenBufferIdx];
  ConversionResult  result;

  if((result = ConvertUTF32toUTF8(unicodeCodePoint, &u8s, (parseState->token.tokenBuffer.bytes.ptr + parseState->token.tokenBuffer.bytes.length))) != conversionOK) { if(result == targetExhausted) { return(1); } }
  size_t utf8len = u8s - &parseState->token.tokenBuffer.bytes.ptr[*tokenBufferIdx], nextIdx = (*tokenBufferIdx) + utf8len;
  
  while(*tokenBufferIdx < nextIdx) { *stringHash = JKN_calculateHash(*stringHash, parseState->token.tokenBuffer.bytes.ptr[(*tokenBufferIdx)++]); }

  return(0);
}

////////////
#pragma mark -
#pragma mark Decoding / parsing / deserializing functions

static int JKN_parse_string(JKNParseState *parseState) {
  NSCParameterAssert((parseState != NULL) && (JKN_AT_STRING_PTR(parseState) <= JKN_END_STRING_PTR(parseState)));
  const unsigned char *stringStart       = JKN_AT_STRING_PTR(parseState) + 1;
  const unsigned char *endOfBuffer       = JKN_END_STRING_PTR(parseState);
  const unsigned char *atStringCharacter = stringStart;
  unsigned char       *tokenBuffer       = parseState->token.tokenBuffer.bytes.ptr;
  size_t               tokenStartIndex   = parseState->atIndex;
  size_t               tokenBufferIdx    = 0UL;

  int      onlySimpleString        = 1,  stringState     = JSONStringStateStart;
  uint16_t escapedUnicode1         = 0U, escapedUnicode2 = 0U;
  uint32_t escapedUnicodeCodePoint = 0U;
  JKNHash   stringHash              = JKN_HASH_INIT;
    
  while(1) {
    unsigned long currentChar;

    if(JKN_EXPECT_F(atStringCharacter == endOfBuffer)) { /* XXX Add error message */ stringState = JSONStringStateError; goto finishedParsing; }
    
    if(JKN_EXPECT_F((currentChar = *atStringCharacter++) >= 0x80UL)) {
      const unsigned char *nextValidCharacter = NULL;
      UTF32                u32ch              = 0U;
      ConversionResult     result;

      if(JKN_EXPECT_F((result = ConvertSingleCodePointInUTF8(atStringCharacter - 1, endOfBuffer, (UTF8 const **)&nextValidCharacter, &u32ch)) != conversionOK)) { goto switchToSlowPath; }
      stringHash = JKN_calculateHash(stringHash, currentChar);
      while(atStringCharacter < nextValidCharacter) { NSCParameterAssert(JKN_AT_STRING_PTR(parseState) <= JKN_END_STRING_PTR(parseState)); stringHash = JKN_calculateHash(stringHash, *atStringCharacter++); }
      continue;
    } else {
      if(JKN_EXPECT_F(currentChar == (unsigned long)'"')) { stringState = JSONStringStateFinished; goto finishedParsing; }

      if(JKN_EXPECT_F(currentChar == (unsigned long)'\\')) {
      switchToSlowPath:
        onlySimpleString = 0;
        stringState      = JSONStringStateParsing;
        tokenBufferIdx   = (atStringCharacter - stringStart) - 1L;
        if(JKN_EXPECT_F((tokenBufferIdx + 16UL) > parseState->token.tokenBuffer.bytes.length)) { if((tokenBuffer = JKN_managedBuffer_resize(&parseState->token.tokenBuffer, tokenBufferIdx + 1024UL)) == NULL) { JKN_error(parseState, @"Internal error: Unable to resize temporary buffer. %@ line #%ld", [NSString stringWithUTF8String:__FILE__], (long)__LINE__); stringState = JSONStringStateError; goto finishedParsing; } }
        memcpy(tokenBuffer, stringStart, tokenBufferIdx);
        goto slowMatch;
      }

      if(JKN_EXPECT_F(currentChar < 0x20UL)) { JKN_error(parseState, @"Invalid character < 0x20 found in string: 0x%2.2x.", currentChar); stringState = JSONStringStateError; goto finishedParsing; }

      stringHash = JKN_calculateHash(stringHash, currentChar);
    }
  }

 slowMatch:

  for(atStringCharacter = (stringStart + ((atStringCharacter - stringStart) - 1L)); (atStringCharacter < endOfBuffer) && (tokenBufferIdx < parseState->token.tokenBuffer.bytes.length); atStringCharacter++) {
    if((tokenBufferIdx + 16UL) > parseState->token.tokenBuffer.bytes.length) { if((tokenBuffer = JKN_managedBuffer_resize(&parseState->token.tokenBuffer, tokenBufferIdx + 1024UL)) == NULL) { JKN_error(parseState, @"Internal error: Unable to resize temporary buffer. %@ line #%ld", [NSString stringWithUTF8String:__FILE__], (long)__LINE__); stringState = JSONStringStateError; goto finishedParsing; } }

    NSCParameterAssert(tokenBufferIdx < parseState->token.tokenBuffer.bytes.length);

    unsigned long currentChar = (*atStringCharacter), escapedChar;

    if(JKN_EXPECT_T(stringState == JSONStringStateParsing)) {
      if(JKN_EXPECT_T(currentChar >= 0x20UL)) {
        if(JKN_EXPECT_T(currentChar < (unsigned long)0x80)) { // Not a UTF8 sequence
          if(JKN_EXPECT_F(currentChar == (unsigned long)'"'))  { stringState = JSONStringStateFinished; atStringCharacter++; goto finishedParsing; }
          if(JKN_EXPECT_F(currentChar == (unsigned long)'\\')) { stringState = JSONStringStateEscape; continue; }
          stringHash = JKN_calculateHash(stringHash, currentChar);
          tokenBuffer[tokenBufferIdx++] = currentChar;
          continue;
        } else { // UTF8 sequence
          const unsigned char *nextValidCharacter = NULL;
          UTF32                u32ch              = 0U;
          ConversionResult     result;
          
          if(JKN_EXPECT_F((result = ConvertSingleCodePointInUTF8(atStringCharacter, endOfBuffer, (UTF8 const **)&nextValidCharacter, &u32ch)) != conversionOK)) {
            if((result == sourceIllegal) && ((parseState->parseOptionFlags & JKNParseOptionLooseUnicode) == 0)) { JKN_error(parseState, @"Illegal UTF8 sequence found in \"\" string.");              stringState = JSONStringStateError; goto finishedParsing; }
            if(result == sourceExhausted)                                                                      { JKN_error(parseState, @"End of buffer reached while parsing UTF8 in \"\" string."); stringState = JSONStringStateError; goto finishedParsing; }
            if(JKN_string_add_unicodeCodePoint(parseState, u32ch, &tokenBufferIdx, &stringHash))                { JKN_error(parseState, @"Internal error: Unable to add UTF8 sequence to internal string buffer. %@ line #%ld", [NSString stringWithUTF8String:__FILE__], (long)__LINE__); stringState = JSONStringStateError; goto finishedParsing; }
            atStringCharacter = nextValidCharacter - 1;
            continue;
          } else {
            while(atStringCharacter < nextValidCharacter) { tokenBuffer[tokenBufferIdx++] = *atStringCharacter; stringHash = JKN_calculateHash(stringHash, *atStringCharacter++); }
            atStringCharacter--;
            continue;
          }
        }
      } else { // currentChar < 0x20
        JKN_error(parseState, @"Invalid character < 0x20 found in string: 0x%2.2x.", currentChar); stringState = JSONStringStateError; goto finishedParsing;
      }

    } else { // stringState != JSONStringStateParsing
      int isSurrogate = 1;

      switch(stringState) {
        case JSONStringStateEscape:
          switch(currentChar) {
            case 'u': escapedUnicode1 = 0U; escapedUnicode2 = 0U; escapedUnicodeCodePoint = 0U; stringState = JSONStringStateEscapedUnicode1; break;

            case 'b':  escapedChar = '\b'; goto parsedEscapedChar;
            case 'f':  escapedChar = '\f'; goto parsedEscapedChar;
            case 'n':  escapedChar = '\n'; goto parsedEscapedChar;
            case 'r':  escapedChar = '\r'; goto parsedEscapedChar;
            case 't':  escapedChar = '\t'; goto parsedEscapedChar;
            case '\\': escapedChar = '\\'; goto parsedEscapedChar;
            case '/':  escapedChar = '/';  goto parsedEscapedChar;
            case '"':  escapedChar = '"';  goto parsedEscapedChar;
              
            parsedEscapedChar:
              stringState = JSONStringStateParsing;
              stringHash  = JKN_calculateHash(stringHash, escapedChar);
              tokenBuffer[tokenBufferIdx++] = escapedChar;
              break;
              
            default: JKN_error(parseState, @"Invalid escape sequence found in \"\" string."); stringState = JSONStringStateError; goto finishedParsing; break;
          }
          break;

        case JSONStringStateEscapedUnicode1:
        case JSONStringStateEscapedUnicode2:
        case JSONStringStateEscapedUnicode3:
        case JSONStringStateEscapedUnicode4:           isSurrogate = 0;
        case JSONStringStateEscapedUnicodeSurrogate1:
        case JSONStringStateEscapedUnicodeSurrogate2:
        case JSONStringStateEscapedUnicodeSurrogate3:
        case JSONStringStateEscapedUnicodeSurrogate4:
          {
            uint16_t hexValue = 0U;

            switch(currentChar) {
              case '0' ... '9': hexValue =  currentChar - '0';        goto parsedHex;
              case 'a' ... 'f': hexValue = (currentChar - 'a') + 10U; goto parsedHex;
              case 'A' ... 'F': hexValue = (currentChar - 'A') + 10U; goto parsedHex;
                
              parsedHex:
              if(!isSurrogate) { escapedUnicode1 = (escapedUnicode1 << 4) | hexValue; } else { escapedUnicode2 = (escapedUnicode2 << 4) | hexValue; }
                
              if(stringState == JSONStringStateEscapedUnicode4) {
                if(((escapedUnicode1 >= 0xD800U) && (escapedUnicode1 < 0xE000U))) {
                  if((escapedUnicode1 >= 0xD800U) && (escapedUnicode1 < 0xDC00U)) { stringState = JSONStringStateEscapedNeedEscapeForSurrogate; }
                  else if((escapedUnicode1 >= 0xDC00U) && (escapedUnicode1 < 0xE000U)) { 
                    if((parseState->parseOptionFlags & JKNParseOptionLooseUnicode)) { escapedUnicodeCodePoint = UNI_REPLACEMENT_CHAR; }
                    else { JKN_error(parseState, @"Illegal \\u Unicode escape sequence."); stringState = JSONStringStateError; goto finishedParsing; }
                  }
                }
                else { escapedUnicodeCodePoint = escapedUnicode1; }
              }

              if(stringState == JSONStringStateEscapedUnicodeSurrogate4) {
                if((escapedUnicode2 < 0xdc00) || (escapedUnicode2 > 0xdfff)) {
                  if((parseState->parseOptionFlags & JKNParseOptionLooseUnicode)) { escapedUnicodeCodePoint = UNI_REPLACEMENT_CHAR; }
                  else { JKN_error(parseState, @"Illegal \\u Unicode escape sequence."); stringState = JSONStringStateError; goto finishedParsing; }
                }
                else { escapedUnicodeCodePoint = ((escapedUnicode1 - 0xd800) * 0x400) + (escapedUnicode2 - 0xdc00) + 0x10000; }
              }
                
              if((stringState == JSONStringStateEscapedUnicode4) || (stringState == JSONStringStateEscapedUnicodeSurrogate4)) { 
                if((isValidCodePoint(&escapedUnicodeCodePoint) == sourceIllegal) && ((parseState->parseOptionFlags & JKNParseOptionLooseUnicode) == 0)) { JKN_error(parseState, @"Illegal \\u Unicode escape sequence."); stringState = JSONStringStateError; goto finishedParsing; }
                stringState = JSONStringStateParsing;
                if(JKN_string_add_unicodeCodePoint(parseState, escapedUnicodeCodePoint, &tokenBufferIdx, &stringHash)) { JKN_error(parseState, @"Internal error: Unable to add UTF8 sequence to internal string buffer. %@ line #%ld", [NSString stringWithUTF8String:__FILE__], (long)__LINE__); stringState = JSONStringStateError; goto finishedParsing; }
              }
              else if((stringState >= JSONStringStateEscapedUnicode1) && (stringState <= JSONStringStateEscapedUnicodeSurrogate4)) { stringState++; }
              break;

              default: JKN_error(parseState, @"Unexpected character found in \\u Unicode escape sequence.  Found '%c', expected [0-9a-fA-F].", currentChar); stringState = JSONStringStateError; goto finishedParsing; break;
            }
          }
          break;

        case JSONStringStateEscapedNeedEscapeForSurrogate:
          if(currentChar == '\\') { stringState = JSONStringStateEscapedNeedEscapedUForSurrogate; }
          else { 
            if((parseState->parseOptionFlags & JKNParseOptionLooseUnicode) == 0) { JKN_error(parseState, @"Required a second \\u Unicode escape sequence following a surrogate \\u Unicode escape sequence."); stringState = JSONStringStateError; goto finishedParsing; }
            else { stringState = JSONStringStateParsing; atStringCharacter--;    if(JKN_string_add_unicodeCodePoint(parseState, UNI_REPLACEMENT_CHAR, &tokenBufferIdx, &stringHash)) { JKN_error(parseState, @"Internal error: Unable to add UTF8 sequence to internal string buffer. %@ line #%ld", [NSString stringWithUTF8String:__FILE__], (long)__LINE__); stringState = JSONStringStateError; goto finishedParsing; } }
          }
          break;

        case JSONStringStateEscapedNeedEscapedUForSurrogate:
          if(currentChar == 'u') { stringState = JSONStringStateEscapedUnicodeSurrogate1; }
          else { 
            if((parseState->parseOptionFlags & JKNParseOptionLooseUnicode) == 0) { JKN_error(parseState, @"Required a second \\u Unicode escape sequence following a surrogate \\u Unicode escape sequence."); stringState = JSONStringStateError; goto finishedParsing; }
            else { stringState = JSONStringStateParsing; atStringCharacter -= 2; if(JKN_string_add_unicodeCodePoint(parseState, UNI_REPLACEMENT_CHAR, &tokenBufferIdx, &stringHash)) { JKN_error(parseState, @"Internal error: Unable to add UTF8 sequence to internal string buffer. %@ line #%ld", [NSString stringWithUTF8String:__FILE__], (long)__LINE__); stringState = JSONStringStateError; goto finishedParsing; } }
          }
          break;

        default: JKN_error(parseState, @"Internal error: Unknown stringState. %@ line #%ld", [NSString stringWithUTF8String:__FILE__], (long)__LINE__); stringState = JSONStringStateError; goto finishedParsing; break;
      }
    }
  }

finishedParsing:

  if(JKN_EXPECT_T(stringState == JSONStringStateFinished)) {
    NSCParameterAssert((parseState->stringBuffer.bytes.ptr + tokenStartIndex) < atStringCharacter);

    parseState->token.tokenPtrRange.ptr    = parseState->stringBuffer.bytes.ptr + tokenStartIndex;
    parseState->token.tokenPtrRange.length = (atStringCharacter - parseState->token.tokenPtrRange.ptr);

    if(JKN_EXPECT_T(onlySimpleString)) {
      NSCParameterAssert(((parseState->token.tokenPtrRange.ptr + 1) < endOfBuffer) && (parseState->token.tokenPtrRange.length >= 2UL) && (((parseState->token.tokenPtrRange.ptr + 1) + (parseState->token.tokenPtrRange.length - 2)) < endOfBuffer));
      parseState->token.value.ptrRange.ptr    = parseState->token.tokenPtrRange.ptr    + 1;
      parseState->token.value.ptrRange.length = parseState->token.tokenPtrRange.length - 2UL;
    } else {
      parseState->token.value.ptrRange.ptr    = parseState->token.tokenBuffer.bytes.ptr;
      parseState->token.value.ptrRange.length = tokenBufferIdx;
    }
    
    parseState->token.value.hash = stringHash;
    parseState->token.value.type = JKNValueTypeString;
    parseState->atIndex          = (atStringCharacter - parseState->stringBuffer.bytes.ptr);
  }

  if(JKN_EXPECT_F(stringState != JSONStringStateFinished)) { JKN_error(parseState, @"Invalid string."); }
  return(JKN_EXPECT_T(stringState == JSONStringStateFinished) ? 0 : 1);
}

static int JKN_parse_number(JKNParseState *parseState) {
  NSCParameterAssert((parseState != NULL) && (JKN_AT_STRING_PTR(parseState) <= JKN_END_STRING_PTR(parseState)));
  const unsigned char *numberStart       = JKN_AT_STRING_PTR(parseState);
  const unsigned char *endOfBuffer       = JKN_END_STRING_PTR(parseState);
  const unsigned char *atNumberCharacter = NULL;
  int                  numberState       = JSONNumberStateWholeNumberStart, isFloatingPoint = 0, isNegative = 0, backup = 0;
  size_t               startingIndex     = parseState->atIndex;
  
  for(atNumberCharacter = numberStart; (JKN_EXPECT_T(atNumberCharacter < endOfBuffer)) && (JKN_EXPECT_T(!(JKN_EXPECT_F(numberState == JSONNumberStateFinished) || JKN_EXPECT_F(numberState == JSONNumberStateError)))); atNumberCharacter++) {
    unsigned long currentChar = (unsigned long)(*atNumberCharacter), lowerCaseCC = currentChar | 0x20UL;
    
    switch(numberState) {
      case JSONNumberStateWholeNumberStart: if   (currentChar == '-')                                                                              { numberState = JSONNumberStateWholeNumberMinus;      isNegative      = 1; break; }
      case JSONNumberStateWholeNumberMinus: if   (currentChar == '0')                                                                              { numberState = JSONNumberStateWholeNumberZero;                            break; }
                                       else if(  (currentChar >= '1') && (currentChar <= '9'))                                                     { numberState = JSONNumberStateWholeNumber;                                break; }
                                       else                                                     { /* XXX Add error message */                        numberState = JSONNumberStateError;                                      break; }
      case JSONNumberStateExponentStart:    if(  (currentChar == '+') || (currentChar == '-'))                                                     { numberState = JSONNumberStateExponentPlusMinus;                          break; }
      case JSONNumberStateFractionalNumberStart:
      case JSONNumberStateExponentPlusMinus:if(!((currentChar >= '0') && (currentChar <= '9'))) { /* XXX Add error message */                        numberState = JSONNumberStateError;                                      break; }
                                       else {                                              if(numberState == JSONNumberStateFractionalNumberStart) { numberState = JSONNumberStateFractionalNumber; }
                                                                                           else                                                    { numberState = JSONNumberStateExponent;         }                         break; }
      case JSONNumberStateWholeNumberZero:
      case JSONNumberStateWholeNumber:      if   (currentChar == '.')                                                                              { numberState = JSONNumberStateFractionalNumberStart; isFloatingPoint = 1; break; }
      case JSONNumberStateFractionalNumber: if   (lowerCaseCC == 'e')                                                                              { numberState = JSONNumberStateExponentStart;         isFloatingPoint = 1; break; }
      case JSONNumberStateExponent:         if(!((currentChar >= '0') && (currentChar <= '9')) || (numberState == JSONNumberStateWholeNumberZero)) { numberState = JSONNumberStateFinished;              backup          = 1; break; }
        break;
      default:                                                                                    /* XXX Add error message */                        numberState = JSONNumberStateError;                                      break;
    }
  }
  
  parseState->token.tokenPtrRange.ptr    = parseState->stringBuffer.bytes.ptr + startingIndex;
  parseState->token.tokenPtrRange.length = (atNumberCharacter - parseState->token.tokenPtrRange.ptr) - backup;
  parseState->atIndex                    = (parseState->token.tokenPtrRange.ptr + parseState->token.tokenPtrRange.length) - parseState->stringBuffer.bytes.ptr;

  if(JKN_EXPECT_T(numberState == JSONNumberStateFinished)) {
    unsigned char  numberTempBuf[parseState->token.tokenPtrRange.length + 4UL];
    unsigned char *endOfNumber = NULL;

    memcpy(numberTempBuf, parseState->token.tokenPtrRange.ptr, parseState->token.tokenPtrRange.length);
    numberTempBuf[parseState->token.tokenPtrRange.length] = 0;

    errno = 0;
    
    // Treat "-0" as a floating point number, which is capable of representing negative zeros.
    if(JKN_EXPECT_F(parseState->token.tokenPtrRange.length == 2UL) && JKN_EXPECT_F(numberTempBuf[1] == '0') && JKN_EXPECT_F(isNegative)) { isFloatingPoint = 1; }

    if(isFloatingPoint) {
      parseState->token.value.number.doubleValue = strtod((const char *)numberTempBuf, (char **)&endOfNumber); // strtod is documented to return U+2261 (identical to) 0.0 on an underflow error (along with setting errno to ERANGE).
      parseState->token.value.type               = JKNValueTypeDouble;
      parseState->token.value.ptrRange.ptr       = (const unsigned char *)&parseState->token.value.number.doubleValue;
      parseState->token.value.ptrRange.length    = sizeof(double);
      parseState->token.value.hash               = (JKN_HASH_INIT + parseState->token.value.type);
    } else {
      if(isNegative) {
        parseState->token.value.number.longLongValue = strtoll((const char *)numberTempBuf, (char **)&endOfNumber, 10);
        parseState->token.value.type                 = JKNValueTypeLongLong;
        parseState->token.value.ptrRange.ptr         = (const unsigned char *)&parseState->token.value.number.longLongValue;
        parseState->token.value.ptrRange.length      = sizeof(long long);
        parseState->token.value.hash                 = (JKN_HASH_INIT + parseState->token.value.type) + (JKNHash)parseState->token.value.number.longLongValue;
      } else {
        parseState->token.value.number.unsignedLongLongValue = strtoull((const char *)numberTempBuf, (char **)&endOfNumber, 10);
        parseState->token.value.type                         = JKNValueTypeUnsignedLongLong;
        parseState->token.value.ptrRange.ptr                 = (const unsigned char *)&parseState->token.value.number.unsignedLongLongValue;
        parseState->token.value.ptrRange.length              = sizeof(unsigned long long);
        parseState->token.value.hash                         = (JKN_HASH_INIT + parseState->token.value.type) + (JKNHash)parseState->token.value.number.unsignedLongLongValue;
      }
    }

    if(JKN_EXPECT_F(errno != 0)) {
      numberState = JSONNumberStateError;
      if(errno == ERANGE) {
        switch(parseState->token.value.type) {
          case JKNValueTypeDouble:           JKN_error(parseState, @"The value '%s' could not be represented as a 'double' due to %s.",           numberTempBuf, (parseState->token.value.number.doubleValue == 0.0) ? "underflow" : "overflow"); break; // see above for == 0.0.
          case JKNValueTypeLongLong:         JKN_error(parseState, @"The value '%s' exceeded the minimum value that could be represented: %lld.", numberTempBuf, parseState->token.value.number.longLongValue);                                   break;
          case JKNValueTypeUnsignedLongLong: JKN_error(parseState, @"The value '%s' exceeded the maximum value that could be represented: %llu.", numberTempBuf, parseState->token.value.number.unsignedLongLongValue);                           break;
          default:                          JKN_error(parseState, @"Internal error: Unknown token value type. %@ line #%ld",                     [NSString stringWithUTF8String:__FILE__], (long)__LINE__);                                      break;
        }
      }
    }
    if(JKN_EXPECT_F(endOfNumber != &numberTempBuf[parseState->token.tokenPtrRange.length]) && JKN_EXPECT_F(numberState != JSONNumberStateError)) { numberState = JSONNumberStateError; JKN_error(parseState, @"The conversion function did not consume all of the number tokens characters."); }

    size_t hashIndex = 0UL;
    for(hashIndex = 0UL; hashIndex < parseState->token.value.ptrRange.length; hashIndex++) { parseState->token.value.hash = JKN_calculateHash(parseState->token.value.hash, parseState->token.value.ptrRange.ptr[hashIndex]); }
  }

  if(JKN_EXPECT_F(numberState != JSONNumberStateFinished)) { JKN_error(parseState, @"Invalid number."); }
  return(JKN_EXPECT_T((numberState == JSONNumberStateFinished)) ? 0 : 1);
}

JKN_STATIC_INLINE void JKN_set_parsed_token(JKNParseState *parseState, const unsigned char *ptr, size_t length, JKNTokenType type, size_t advanceBy) {
  parseState->token.tokenPtrRange.ptr     = ptr;
  parseState->token.tokenPtrRange.length  = length;
  parseState->token.type                  = type;
  parseState->atIndex                    += advanceBy;
}

static size_t JKN_parse_is_newline(JKNParseState *parseState, const unsigned char *atCharacterPtr) {
  NSCParameterAssert((parseState != NULL) && (atCharacterPtr != NULL) && (atCharacterPtr >= parseState->stringBuffer.bytes.ptr) && (atCharacterPtr < JKN_END_STRING_PTR(parseState)));
  const unsigned char *endOfStringPtr = JKN_END_STRING_PTR(parseState);

  if(JKN_EXPECT_F(atCharacterPtr >= endOfStringPtr)) { return(0UL); }

  if(JKN_EXPECT_F((*(atCharacterPtr + 0)) == '\n')) { return(1UL); }
  if(JKN_EXPECT_F((*(atCharacterPtr + 0)) == '\r')) { if((JKN_EXPECT_T((atCharacterPtr + 1) < endOfStringPtr)) && ((*(atCharacterPtr + 1)) == '\n')) { return(2UL); } return(1UL); }
  if(parseState->parseOptionFlags & JKNParseOptionUnicodeNewlines) {
    if((JKN_EXPECT_F((*(atCharacterPtr + 0)) == 0xc2)) && (((atCharacterPtr + 1) < endOfStringPtr) && ((*(atCharacterPtr + 1)) == 0x85))) { return(2UL); }
    if((JKN_EXPECT_F((*(atCharacterPtr + 0)) == 0xe2)) && (((atCharacterPtr + 2) < endOfStringPtr) && ((*(atCharacterPtr + 1)) == 0x80) && (((*(atCharacterPtr + 2)) == 0xa8) || ((*(atCharacterPtr + 2)) == 0xa9)))) { return(3UL); }
  }

  return(0UL);
}

JKN_STATIC_INLINE int JKN_parse_skip_newline(JKNParseState *parseState) {
  size_t newlineAdvanceAtIndex = 0UL;
  if(JKN_EXPECT_F((newlineAdvanceAtIndex = JKN_parse_is_newline(parseState, JKN_AT_STRING_PTR(parseState))) > 0UL)) { parseState->lineNumber++; parseState->atIndex += (newlineAdvanceAtIndex - 1UL); parseState->lineStartIndex = parseState->atIndex + 1UL; return(1); }
  return(0);
}

JKN_STATIC_INLINE void JKN_parse_skip_whitespace(JKNParseState *parseState) {
#ifndef __clang_analyzer__
  NSCParameterAssert((parseState != NULL) && (JKN_AT_STRING_PTR(parseState) <= JKN_END_STRING_PTR(parseState)));
  const unsigned char *atCharacterPtr   = NULL;
  const unsigned char *endOfStringPtr   = JKN_END_STRING_PTR(parseState);

  for(atCharacterPtr = JKN_AT_STRING_PTR(parseState); (JKN_EXPECT_T((atCharacterPtr = JKN_AT_STRING_PTR(parseState)) < endOfStringPtr)); parseState->atIndex++) {
    if(((*(atCharacterPtr + 0)) == ' ') || ((*(atCharacterPtr + 0)) == '\t')) { continue; }
    if(JKN_parse_skip_newline(parseState)) { continue; }
    if(parseState->parseOptionFlags & JKNParseOptionComments) {
      if((JKN_EXPECT_F((*(atCharacterPtr + 0)) == '/')) && (JKN_EXPECT_T((atCharacterPtr + 1) < endOfStringPtr))) {
        if((*(atCharacterPtr + 1)) == '/') {
          parseState->atIndex++;
          for(atCharacterPtr = JKN_AT_STRING_PTR(parseState); (JKN_EXPECT_T((atCharacterPtr = JKN_AT_STRING_PTR(parseState)) < endOfStringPtr)); parseState->atIndex++) { if(JKN_parse_skip_newline(parseState)) { break; } }
          continue;
        }
        if((*(atCharacterPtr + 1)) == '*') {
          parseState->atIndex++;
          for(atCharacterPtr = JKN_AT_STRING_PTR(parseState); (JKN_EXPECT_T((atCharacterPtr = JKN_AT_STRING_PTR(parseState)) < endOfStringPtr)); parseState->atIndex++) {
            if(JKN_parse_skip_newline(parseState)) { continue; }
            if(((*(atCharacterPtr + 0)) == '*') && (((atCharacterPtr + 1) < endOfStringPtr) && ((*(atCharacterPtr + 1)) == '/'))) { parseState->atIndex++; break; }
          }
          continue;
        }
      }
    }
    break;
  }
#endif
}

static int JKN_parse_next_token(JKNParseState *parseState)
{
    NSCParameterAssert((parseState != NULL) && (JKN_AT_STRING_PTR(parseState) <= JKN_END_STRING_PTR(parseState)));
    const unsigned char *atCharacterPtr   = NULL;
    const unsigned char *endOfStringPtr   = JKN_END_STRING_PTR(parseState);
    unsigned char        currentCharacter = 0U;
    int                  stopParsing      = 0;

    parseState->prev_atIndex        = parseState->atIndex;
    parseState->prev_lineNumber     = parseState->lineNumber;
    parseState->prev_lineStartIndex = parseState->lineStartIndex;

    JKN_parse_skip_whitespace(parseState);

    if ((JKN_AT_STRING_PTR(parseState) == endOfStringPtr)) {
        stopParsing = 1;
    }

    if((JKN_EXPECT_T(stopParsing == 0)) && (JKN_EXPECT_T((atCharacterPtr = JKN_AT_STRING_PTR(parseState)) < endOfStringPtr))) {
        currentCharacter = *atCharacterPtr;
        if (JKN_EXPECT_T(currentCharacter == '"')) {
            if (JKN_EXPECT_T((stopParsing = JKN_parse_string(parseState)) == 0)) {
                JKN_set_parsed_token(parseState, parseState->token.tokenPtrRange.ptr, parseState->token.tokenPtrRange.length, JKNTokenTypeString, 0UL);
            }
        }
        else if(JKN_EXPECT_T(currentCharacter == ':')) { JKN_set_parsed_token(parseState, atCharacterPtr, 1UL, JKNTokenTypeSeparator,   1UL); }
        else if(JKN_EXPECT_T(currentCharacter == ',')) { JKN_set_parsed_token(parseState, atCharacterPtr, 1UL, JKNTokenTypeComma,       1UL); }
        else if ((JKN_EXPECT_T(currentCharacter >= '0') && JKN_EXPECT_T(currentCharacter <= '9')) || JKN_EXPECT_T(currentCharacter == '-')) {
            if (JKN_EXPECT_T((stopParsing = JKN_parse_number(parseState)) == 0)) {
                JKN_set_parsed_token(parseState, parseState->token.tokenPtrRange.ptr, parseState->token.tokenPtrRange.length, JKNTokenTypeNumber, 0UL);
            }
        }
        else if(JKN_EXPECT_T(currentCharacter == '{')) { JKN_set_parsed_token(parseState, atCharacterPtr, 1UL, JKNTokenTypeObjectBegin, 1UL); }
        else if(JKN_EXPECT_T(currentCharacter == '}')) { JKN_set_parsed_token(parseState, atCharacterPtr, 1UL, JKNTokenTypeObjectEnd,   1UL); }
        else if(JKN_EXPECT_T(currentCharacter == '[')) { JKN_set_parsed_token(parseState, atCharacterPtr, 1UL, JKNTokenTypeArrayBegin,  1UL); }
        else if(JKN_EXPECT_T(currentCharacter == ']')) { JKN_set_parsed_token(parseState, atCharacterPtr, 1UL, JKNTokenTypeArrayEnd,    1UL); }
        else if (JKN_EXPECT_F(currentCharacter == 'T')) {
            parseState->atIndex += 1;
            if (JKN_EXPECT_T((stopParsing = JKN_parse_number(parseState)) == 0)) {
                JKN_set_parsed_token(parseState, parseState->token.tokenPtrRange.ptr, parseState->token.tokenPtrRange.length, JKNTokenTypeDate, 0UL);
            }
        }
        else if(JKN_EXPECT_T(currentCharacter == 't')) { if(!((JKN_EXPECT_T((atCharacterPtr + 4UL) < endOfStringPtr)) && (JKN_EXPECT_T(atCharacterPtr[1] == 'r')) && (JKN_EXPECT_T(atCharacterPtr[2] == 'u')) && (JKN_EXPECT_T(atCharacterPtr[3] == 'e'))))                                            { stopParsing = 1; /* XXX Add error message */ } else { JKN_set_parsed_token(parseState, atCharacterPtr, 4UL, JKNTokenTypeTrue,  4UL); } }
        else if(JKN_EXPECT_T(currentCharacter == 'f')) { if(!((JKN_EXPECT_T((atCharacterPtr + 5UL) < endOfStringPtr)) && (JKN_EXPECT_T(atCharacterPtr[1] == 'a')) && (JKN_EXPECT_T(atCharacterPtr[2] == 'l')) && (JKN_EXPECT_T(atCharacterPtr[3] == 's')) && (JKN_EXPECT_T(atCharacterPtr[4] == 'e')))) { stopParsing = 1; /* XXX Add error message */ } else { JKN_set_parsed_token(parseState, atCharacterPtr, 5UL, JKNTokenTypeFalse, 5UL); } }
        else if(JKN_EXPECT_T(currentCharacter == 'n')) { if(!((JKN_EXPECT_T((atCharacterPtr + 4UL) < endOfStringPtr)) && (JKN_EXPECT_T(atCharacterPtr[1] == 'u')) && (JKN_EXPECT_T(atCharacterPtr[2] == 'l')) && (JKN_EXPECT_T(atCharacterPtr[3] == 'l'))))                                            { stopParsing = 1; /* XXX Add error message */ } else { JKN_set_parsed_token(parseState, atCharacterPtr, 4UL, JKNTokenTypeNull,  4UL); } }
        else { stopParsing = 1; /* XXX Add error message */ }
    }

    if (JKN_EXPECT_F(stopParsing)) {
        JKN_error(parseState, @"Unexpected token, wanted '{', '}', '[', ']', ',', ':', 'true', 'false', 'null', '\"STRING\"', 'NUMBER'.");
    }
    return stopParsing;
}

static void JKN_error_parse_accept_or3(JKNParseState *parseState, int state, NSString *or1String, NSString *or2String, NSString *or3String) {
  NSString *acceptStrings[16];
  int acceptIdx = 0;
  if(state & JKNParseAcceptValue) { acceptStrings[acceptIdx++] = or1String; }
  if(state & JKNParseAcceptComma) { acceptStrings[acceptIdx++] = or2String; }
  if(state & JKNParseAcceptEnd)   { acceptStrings[acceptIdx++] = or3String; }
       if(acceptIdx == 1) { JKN_error(parseState, @"Expected %@, not '%*.*s'",           acceptStrings[0],                                     (int)parseState->token.tokenPtrRange.length, (int)parseState->token.tokenPtrRange.length, parseState->token.tokenPtrRange.ptr); }
  else if(acceptIdx == 2) { JKN_error(parseState, @"Expected %@ or %@, not '%*.*s'",     acceptStrings[0], acceptStrings[1],                   (int)parseState->token.tokenPtrRange.length, (int)parseState->token.tokenPtrRange.length, parseState->token.tokenPtrRange.ptr); }
  else if(acceptIdx == 3) { JKN_error(parseState, @"Expected %@, %@, or %@, not '%*.*s", acceptStrings[0], acceptStrings[1], acceptStrings[2], (int)parseState->token.tokenPtrRange.length, (int)parseState->token.tokenPtrRange.length, parseState->token.tokenPtrRange.ptr); }
}

static void *JKN_parse_array(JKNParseState *parseState) {
  size_t  startingObjectIndex = parseState->objectStack.index;
  int     arrayState          = JKNParseAcceptValueOrEnd, stopParsing = 0;
  void   *parsedArray         = NULL;

  while(JKN_EXPECT_T((JKN_EXPECT_T(stopParsing == 0)) && (JKN_EXPECT_T(parseState->atIndex < parseState->stringBuffer.bytes.length)))) {
    if(JKN_EXPECT_F(parseState->objectStack.index > (parseState->objectStack.count - 4UL))) { if(JKN_objectStack_resize(&parseState->objectStack, parseState->objectStack.count + 128UL)) { JKN_error(parseState, @"Internal error: [array] objectsIndex > %zu, resize failed? %@ line %#ld", (parseState->objectStack.count - 4UL), [NSString stringWithUTF8String:__FILE__], (long)__LINE__); break; } }

    if(JKN_EXPECT_T((stopParsing = JKN_parse_next_token(parseState)) == 0)) {
      void *object = NULL;
#ifndef NS_BLOCK_ASSERTIONS
      parseState->objectStack.objects[parseState->objectStack.index] = NULL;
      parseState->objectStack.keys   [parseState->objectStack.index] = NULL;
#endif
      switch(parseState->token.type) {
        case JKNTokenTypeNumber:
        case JKNTokenTypeString:
        case JKNTokenTypeTrue:
        case JKNTokenTypeFalse:
        case JKNTokenTypeNull:
        case JKNTokenTypeArrayBegin:
        case JKNTokenTypeObjectBegin:
          if(JKN_EXPECT_F((arrayState & JKNParseAcceptValue)          == 0))    { parseState->errorIsPrev = 1; JKN_error(parseState, @"Unexpected value.");              stopParsing = 1; break; }
          if(JKN_EXPECT_F((object = JKN_object_for_token(parseState)) == NULL)) {                              JKN_error(parseState, @"Internal error: Object == NULL"); stopParsing = 1; break; } else { parseState->objectStack.objects[parseState->objectStack.index++] = object; arrayState = JKNParseAcceptCommaOrEnd; }
          break;
        case JKNTokenTypeArrayEnd: if(JKN_EXPECT_T(arrayState & JKNParseAcceptEnd)) { NSCParameterAssert(parseState->objectStack.index >= startingObjectIndex); parsedArray = (void *)_JKNArrayCreate((id *)&parseState->objectStack.objects[startingObjectIndex], (parseState->objectStack.index - startingObjectIndex), parseState->mutableCollections); } else { parseState->errorIsPrev = 1; JKN_error(parseState, @"Unexpected ']'."); } stopParsing = 1; break;
        case JKNTokenTypeComma:    if(JKN_EXPECT_T(arrayState & JKNParseAcceptComma)) { arrayState = JKNParseAcceptValue; } else { parseState->errorIsPrev = 1; JKN_error(parseState, @"Unexpected ','."); stopParsing = 1; } break;
        default: parseState->errorIsPrev = 1; JKN_error_parse_accept_or3(parseState, arrayState, @"a value", @"a comma", @"a ']'"); stopParsing = 1; break;
      }
    }
  }

  if(JKN_EXPECT_F(parsedArray == NULL)) { size_t idx = 0UL; for(idx = startingObjectIndex; idx < parseState->objectStack.index; idx++) { if(parseState->objectStack.objects[idx] != NULL) { CFRelease(parseState->objectStack.objects[idx]); parseState->objectStack.objects[idx] = NULL; } } }
#if !defined(NS_BLOCK_ASSERTIONS)
  else { size_t idx = 0UL; for(idx = startingObjectIndex; idx < parseState->objectStack.index; idx++) { parseState->objectStack.objects[idx] = NULL; parseState->objectStack.keys[idx] = NULL; } }
#endif
  
  parseState->objectStack.index = startingObjectIndex;
  return(parsedArray);
}

static void *JKN_create_dictionary(JKNParseState *parseState, size_t startingObjectIndex) {
  void *parsedDictionary = NULL;

  parseState->objectStack.index--;

  parsedDictionary = _JKNDictionaryCreate((id *)&parseState->objectStack.keys[startingObjectIndex], (NSUInteger *)&parseState->objectStack.cfHashes[startingObjectIndex], (id *)&parseState->objectStack.objects[startingObjectIndex], (parseState->objectStack.index - startingObjectIndex), parseState->mutableCollections);

  return(parsedDictionary);
}

static void *JKN_parse_dictionary(JKNParseState *parseState) {
  size_t  startingObjectIndex = parseState->objectStack.index;
  int     dictState           = JKNParseAcceptValueOrEnd, stopParsing = 0;
  void   *parsedDictionary    = NULL;

  while(JKN_EXPECT_T((JKN_EXPECT_T(stopParsing == 0)) && (JKN_EXPECT_T(parseState->atIndex < parseState->stringBuffer.bytes.length)))) {
    if(JKN_EXPECT_F(parseState->objectStack.index > (parseState->objectStack.count - 4UL))) { if(JKN_objectStack_resize(&parseState->objectStack, parseState->objectStack.count + 128UL)) { JKN_error(parseState, @"Internal error: [dictionary] objectsIndex > %zu, resize failed? %@ line #%ld", (parseState->objectStack.count - 4UL), [NSString stringWithUTF8String:__FILE__], (long)__LINE__); break; } }

    size_t objectStackIndex = parseState->objectStack.index++;
    parseState->objectStack.keys[objectStackIndex]    = NULL;
    parseState->objectStack.objects[objectStackIndex] = NULL;
    void *key = NULL, *object = NULL;

    if(JKN_EXPECT_T((JKN_EXPECT_T(stopParsing == 0)) && (JKN_EXPECT_T((stopParsing = JKN_parse_next_token(parseState)) == 0)))) {
      switch(parseState->token.type) {
        case JKNTokenTypeString:
          if(JKN_EXPECT_F((dictState & JKNParseAcceptValue)        == 0))    { parseState->errorIsPrev = 1; JKN_error(parseState, @"Unexpected string.");           stopParsing = 1; break; }
          if(JKN_EXPECT_F((key = JKN_object_for_token(parseState)) == NULL)) {                              JKN_error(parseState, @"Internal error: Key == NULL."); stopParsing = 1; break; }
          else {
            parseState->objectStack.keys[objectStackIndex] = key;
            if(JKN_EXPECT_T(parseState->token.value.cacheItem != NULL)) { if(JKN_EXPECT_F(parseState->token.value.cacheItem->cfHash == 0UL)) { parseState->token.value.cacheItem->cfHash = CFHash(key); } parseState->objectStack.cfHashes[objectStackIndex] = parseState->token.value.cacheItem->cfHash; }
            else { parseState->objectStack.cfHashes[objectStackIndex] = CFHash(key); }
          }
          break;

        case JKNTokenTypeObjectEnd: if((JKN_EXPECT_T(dictState & JKNParseAcceptEnd)))   { NSCParameterAssert(parseState->objectStack.index >= startingObjectIndex); parsedDictionary = JKN_create_dictionary(parseState, startingObjectIndex); } else { parseState->errorIsPrev = 1; JKN_error(parseState, @"Unexpected '}'."); } stopParsing = 1; break;
        case JKNTokenTypeComma:     if((JKN_EXPECT_T(dictState & JKNParseAcceptComma))) { dictState = JKNParseAcceptValue; parseState->objectStack.index--; continue; } else { parseState->errorIsPrev = 1; JKN_error(parseState, @"Unexpected ','."); stopParsing = 1; } break;

        default: parseState->errorIsPrev = 1; JKN_error_parse_accept_or3(parseState, dictState, @"a \"STRING\"", @"a comma", @"a '}'"); stopParsing = 1; break;
      }
    }

    if(JKN_EXPECT_T(stopParsing == 0)) {
      if(JKN_EXPECT_T((stopParsing = JKN_parse_next_token(parseState)) == 0)) { if(JKN_EXPECT_F(parseState->token.type != JKNTokenTypeSeparator)) { parseState->errorIsPrev = 1; JKN_error(parseState, @"Expected ':'."); stopParsing = 1; } }
    }

    if((JKN_EXPECT_T(stopParsing == 0)) && (JKN_EXPECT_T((stopParsing = JKN_parse_next_token(parseState)) == 0))) {
      switch(parseState->token.type) {
        case JKNTokenTypeNumber:
        case JKNTokenTypeString:
        case JKNTokenTypeTrue:
        case JKNTokenTypeFalse:
        case JKNTokenTypeNull:
        case JKNTokenTypeArrayBegin:
        case JKNTokenTypeObjectBegin:
          if (JKN_EXPECT_F((dictState & JKNParseAcceptValue) == 0)) {
              parseState->errorIsPrev = 1;
              JKN_error(parseState, @"Unexpected value.");
              stopParsing = 1; break;
          }
          if (JKN_EXPECT_F((object = JKN_object_for_token(parseState)) == NULL)) {
              JKN_error(parseState, @"Internal error: Object == NULL.");
              stopParsing = 1;
              break;
          }
          else {
              parseState->objectStack.objects[objectStackIndex] = object;
              dictState = JKNParseAcceptCommaOrEnd;
          }
          break;
        case JKNTokenTypeDate:
              if (JKN_EXPECT_F((dictState & JKNParseAcceptValue) == 0)) {
                  parseState->errorIsPrev = 1;
                  JKN_error(parseState, @"Unexpected value.");
                  stopParsing = 1; break;
              }
              if (JKN_EXPECT_F((object = JKN_object_for_token(parseState)) == NULL)) {
                  JKN_error(parseState, @"Internal error: Object == NULL.");
                  stopParsing = 1;
                  break;
              }
              else {
                  NSDate *date = [NSDate dateWithTimeIntervalSince1970:((NSNumber *)object).doubleValue];
                  parseState->objectStack.objects[objectStackIndex] = date.retain;
                  dictState = JKNParseAcceptCommaOrEnd;
              }
              break;
        default: parseState->errorIsPrev = 1; JKN_error_parse_accept_or3(parseState, dictState, @"a value", @"a comma", @"a '}'"); stopParsing = 1; break;
      }
    }
  }

  if(JKN_EXPECT_F(parsedDictionary == NULL)) { size_t idx = 0UL; for(idx = startingObjectIndex; idx < parseState->objectStack.index; idx++) { if(parseState->objectStack.keys[idx] != NULL) { CFRelease(parseState->objectStack.keys[idx]); parseState->objectStack.keys[idx] = NULL; } if(parseState->objectStack.objects[idx] != NULL) { CFRelease(parseState->objectStack.objects[idx]); parseState->objectStack.objects[idx] = NULL; } } }
#if !defined(NS_BLOCK_ASSERTIONS)
  else { size_t idx = 0UL; for(idx = startingObjectIndex; idx < parseState->objectStack.index; idx++) { parseState->objectStack.objects[idx] = NULL; parseState->objectStack.keys[idx] = NULL; } }
#endif

  parseState->objectStack.index = startingObjectIndex;
  return(parsedDictionary);
}

static id json_parse_it(JKNParseState *parseState) {
  id  parsedObject = NULL;
  int stopParsing  = 0;

  while((JKN_EXPECT_T(stopParsing == 0)) && (JKN_EXPECT_T(parseState->atIndex < parseState->stringBuffer.bytes.length))) {
    if((JKN_EXPECT_T(stopParsing == 0)) && (JKN_EXPECT_T((stopParsing = JKN_parse_next_token(parseState)) == 0))) {
      switch (parseState->token.type) {
        case JKNTokenTypeArrayBegin:
        case JKNTokenTypeObjectBegin:
              parsedObject = [(id)JKN_object_for_token(parseState) autorelease];
              stopParsing = 1;
              break;
        default:
              JKN_error(parseState, @"Expected either '[' or '{'.");
              stopParsing = 1;
              break;
      }
    }
  }

  NSCParameterAssert((parseState->objectStack.index == 0) && (JKN_AT_STRING_PTR(parseState) <= JKN_END_STRING_PTR(parseState)));

  if((parsedObject == NULL) && (JKN_AT_STRING_PTR(parseState) == JKN_END_STRING_PTR(parseState))) { JKN_error(parseState, @"Reached the end of the buffer."); }
  if(parsedObject == NULL) { JKN_error(parseState, @"Unable to parse JSON."); }

  if((parsedObject != NULL) && (JKN_AT_STRING_PTR(parseState) < JKN_END_STRING_PTR(parseState))) {
    JKN_parse_skip_whitespace(parseState);
    if((parsedObject != NULL) && ((parseState->parseOptionFlags & JKNParseOptionPermitTextAfterValidJSON) == 0) && (JKN_AT_STRING_PTR(parseState) < JKN_END_STRING_PTR(parseState))) {
      JKN_error(parseState, @"A valid JSON object was parsed but there were additional non-white-space characters remaining.");
      parsedObject = NULL;
    }
  }

  return(parsedObject);
}

////////////
#pragma mark -
#pragma mark Object cache

// This uses a Galois Linear Feedback Shift Register (LFSR) PRNG to pick which item in the cache to age. It has a period of (2^32)-1.
// NOTE: A LFSR *MUST* be initialized to a non-zero value and must always have a non-zero value. The LFSR is initalized to 1 in -initWithParseOptions:
JKN_STATIC_INLINE void JKN_cache_age(JKNParseState *parseState) {
  NSCParameterAssert((parseState != NULL) && (parseState->cache.prng_lfsr != 0U));
  parseState->cache.prng_lfsr = (parseState->cache.prng_lfsr >> 1) ^ ((0U - (parseState->cache.prng_lfsr & 1U)) & 0x80200003U);
  parseState->cache.age[parseState->cache.prng_lfsr & (parseState->cache.count - 1UL)] >>= 1;
}

// The object cache is nothing more than a hash table with open addressing collision resolution that is bounded by JKN_CACHE_PROBES attempts.
//
// The hash table is a linear C array of JKNTokenCacheItem.  The terms "item" and "bucket" are synonymous with the index in to the cache array, i.e. cache.items[bucket].
//
// Items in the cache have an age associated with them.  An items age is incremented using saturating unsigned arithmetic and decremeted using unsigned right shifts.
// Thus, an items age is managed using an AIMD policy- additive increase, multiplicative decrease.  All age calculations and manipulations are branchless.
// The primitive C type MUST be unsigned.  It is currently a "char", which allows (at a minimum and in practice) 8 bits.
//
// A "useable bucket" is a bucket that is not in use (never populated), or has an age == 0.
//
// When an item is found in the cache, it's age is incremented.
// If a useable bucket hasn't been found, the current item (bucket) is aged along with two random items.
//
// If a value is not found in the cache, and no useable bucket has been found, that value is not added to the cache.

static void *JKN_cachedObjects(JKNParseState *parseState) {
  unsigned long  bucket     = parseState->token.value.hash & (parseState->cache.count - 1UL), setBucket = 0UL, useableBucket = 0UL, x = 0UL;
  void          *parsedAtom = NULL;
    
  if(JKN_EXPECT_F(parseState->token.value.ptrRange.length == 0UL) && JKN_EXPECT_T(parseState->token.value.type == JKNValueTypeString)) { return(@""); }

  for(x = 0UL; x < JKN_CACHE_PROBES; x++) {
    if(JKN_EXPECT_F(parseState->cache.items[bucket].object == NULL)) { setBucket = 1UL; useableBucket = bucket; break; }
    
    if((JKN_EXPECT_T(parseState->cache.items[bucket].hash == parseState->token.value.hash)) && (JKN_EXPECT_T(parseState->cache.items[bucket].size == parseState->token.value.ptrRange.length)) && (JKN_EXPECT_T(parseState->cache.items[bucket].type == parseState->token.value.type)) && (JKN_EXPECT_T(parseState->cache.items[bucket].bytes != NULL)) && (JKN_EXPECT_T(memcmp(parseState->cache.items[bucket].bytes, parseState->token.value.ptrRange.ptr, parseState->token.value.ptrRange.length) == 0U))) {
      parseState->cache.age[bucket]     = (((uint32_t)parseState->cache.age[bucket]) + 1U) - (((((uint32_t)parseState->cache.age[bucket]) + 1U) >> 31) ^ 1U);
      parseState->token.value.cacheItem = &parseState->cache.items[bucket];
      NSCParameterAssert(parseState->cache.items[bucket].object != NULL);
      return((void *)CFRetain(parseState->cache.items[bucket].object));
    } else {
      if(JKN_EXPECT_F(setBucket == 0UL) && JKN_EXPECT_F(parseState->cache.age[bucket] == 0U)) { setBucket = 1UL; useableBucket = bucket; }
      if(JKN_EXPECT_F(setBucket == 0UL))                                                     { parseState->cache.age[bucket] >>= 1; JKN_cache_age(parseState); JKN_cache_age(parseState); }
      // This is the open addressing function.  The values length and type are used as a form of "double hashing" to distribute values with the same effective value hash across different object cache buckets.
      // The values type is a prime number that is relatively coprime to the other primes in the set of value types and the number of hash table buckets.
      bucket = (parseState->token.value.hash + (parseState->token.value.ptrRange.length * (x + 1UL)) + (parseState->token.value.type * (x + 1UL)) + (3UL * (x + 1UL))) & (parseState->cache.count - 1UL);
    }
  }
  
  switch(parseState->token.value.type) {
    case JKNValueTypeString:           parsedAtom = (void *)CFStringCreateWithBytes(NULL, parseState->token.value.ptrRange.ptr, parseState->token.value.ptrRange.length, kCFStringEncodingUTF8, 0); break;
    case JKNValueTypeLongLong:         parsedAtom = (void *)CFNumberCreate(NULL, kCFNumberLongLongType, &parseState->token.value.number.longLongValue);                                             break;
    case JKNValueTypeUnsignedLongLong:
      if(parseState->token.value.number.unsignedLongLongValue <= LLONG_MAX) { parsedAtom = (void *)CFNumberCreate(NULL, kCFNumberLongLongType, &parseState->token.value.number.unsignedLongLongValue); }
      else { parsedAtom = (void *)parseState->objCImpCache.NSNumberInitWithUnsignedLongLong(parseState->objCImpCache.NSNumberAlloc(parseState->objCImpCache.NSNumberClass, @selector(alloc)), @selector(initWithUnsignedLongLong:), parseState->token.value.number.unsignedLongLongValue); }
      break;
    case JKNValueTypeDouble:           parsedAtom = (void *)CFNumberCreate(NULL, kCFNumberDoubleType,   &parseState->token.value.number.doubleValue);                                               break;
    default: JKN_error(parseState, @"Internal error: Unknown token value type. %@ line #%ld", [NSString stringWithUTF8String:__FILE__], (long)__LINE__); break;
  }
  
  if(JKN_EXPECT_T(setBucket) && (JKN_EXPECT_T(parsedAtom != NULL))) {
    bucket = useableBucket;
    if(JKN_EXPECT_T((parseState->cache.items[bucket].object != NULL))) { CFRelease(parseState->cache.items[bucket].object); parseState->cache.items[bucket].object = NULL; }
    
    if(JKN_EXPECT_T((parseState->cache.items[bucket].bytes = (unsigned char *)reallocf(parseState->cache.items[bucket].bytes, parseState->token.value.ptrRange.length)) != NULL)) {
      memcpy(parseState->cache.items[bucket].bytes, parseState->token.value.ptrRange.ptr, parseState->token.value.ptrRange.length);
      parseState->cache.items[bucket].object = (void *)CFRetain(parsedAtom);
      parseState->cache.items[bucket].hash   = parseState->token.value.hash;
      parseState->cache.items[bucket].cfHash = 0UL;
      parseState->cache.items[bucket].size   = parseState->token.value.ptrRange.length;
      parseState->cache.items[bucket].type   = parseState->token.value.type;
      parseState->token.value.cacheItem      = &parseState->cache.items[bucket];
      parseState->cache.age[bucket]          = JKN_INIT_CACHE_AGE;
    } else { // The realloc failed, so clear the appropriate fields.
      parseState->cache.items[bucket].hash   = 0UL;
      parseState->cache.items[bucket].cfHash = 0UL;
      parseState->cache.items[bucket].size   = 0UL;
      parseState->cache.items[bucket].type   = 0UL;
    }
  }
  
  return(parsedAtom);
}


static void *JKN_object_for_token(JKNParseState *parseState) {
  void *parsedAtom = NULL;
  
  parseState->token.value.cacheItem = NULL;
  switch(parseState->token.type) {
    case JKNTokenTypeString:      parsedAtom = JKN_cachedObjects(parseState);    break;
    case JKNTokenTypeNumber:      parsedAtom = JKN_cachedObjects(parseState);    break;
    case JKNTokenTypeObjectBegin: parsedAtom = JKN_parse_dictionary(parseState); break;
    case JKNTokenTypeArrayBegin:  parsedAtom = JKN_parse_array(parseState);      break;
    case JKNTokenTypeTrue:        parsedAtom = (void *)kCFBooleanTrue;          break;
    case JKNTokenTypeFalse:       parsedAtom = (void *)kCFBooleanFalse;         break;
    case JKNTokenTypeNull:        parsedAtom = (void *)kCFNull;                 break;
    case JKNTokenTypeDate:      parsedAtom = JKN_cachedObjects(parseState);    break;
    default: JKN_error(parseState, @"Internal error: Unknown token type. %@ line #%ld", [NSString stringWithUTF8String:__FILE__], (long)__LINE__); break;
  }
  
  return(parsedAtom);
}

#pragma mark -
@implementation JSONDecoderN

+ (id)decoder
{
  return([self decoderWithParseOptions:JKNParseOptionStrict]);
}

+ (id)decoderWithParseOptions:(JKNParseOptionFlags)parseOptionFlags
{
  return([[[self alloc] initWithParseOptions:parseOptionFlags] autorelease]);
}

- (id)init
{
  return([self initWithParseOptions:JKNParseOptionStrict]);
}

- (id)initWithParseOptions:(JKNParseOptionFlags)parseOptionFlags
{
  if((self = [super init]) == NULL) { return(NULL); }

  if(parseOptionFlags & ~JKNParseOptionValidFlags) { [self autorelease]; [NSException raise:NSInvalidArgumentException format:@"Invalid parse options."]; }

  if((parseState = (JKNParseState *)calloc(1UL, sizeof(JKNParseState))) == NULL) { goto errorExit; }

  parseState->parseOptionFlags = parseOptionFlags;
  
  parseState->token.tokenBuffer.roundSizeUpToMultipleOf = 4096UL;
  parseState->objectStack.roundSizeUpToMultipleOf       = 2048UL;

  parseState->objCImpCache.NSNumberClass                    = _JKN_NSNumberClass;
  parseState->objCImpCache.NSNumberAlloc                    = _JKN_NSNumberAllocImp;
  parseState->objCImpCache.NSNumberInitWithUnsignedLongLong = _JKN_NSNumberInitWithUnsignedLongLongImp;
  
  parseState->cache.prng_lfsr = 1U;
  parseState->cache.count     = JKN_CACHE_SLOTS;
  if((parseState->cache.items = (JKNTokenCacheItem *)calloc(1UL, sizeof(JKNTokenCacheItem) * parseState->cache.count)) == NULL) { goto errorExit; }

  return(self);

 errorExit:
  if(self) { [self autorelease]; self = NULL; }
  return(NULL);
}

// This is here primarily to support the NSString and NSData convenience functions so the autoreleased JSONDecoderN can release most of its resources before the pool pops.
static void _JSONDecoderNCleanup(JSONDecoderN *decoder) {
  if((decoder != NULL) && (decoder->parseState != NULL)) {
    JKN_managedBuffer_release(&decoder->parseState->token.tokenBuffer);
    JKN_objectStack_release(&decoder->parseState->objectStack);
    
    [decoder clearCache];
    if(decoder->parseState->cache.items != NULL) { free(decoder->parseState->cache.items); decoder->parseState->cache.items = NULL; }
    
    free(decoder->parseState); decoder->parseState = NULL;
  }
}

- (void)dealloc
{
  _JSONDecoderNCleanup(self);
  [super dealloc];
}

- (void)clearCache
{
  if(JKN_EXPECT_T(parseState != NULL)) {
    if(JKN_EXPECT_T(parseState->cache.items != NULL)) {
      size_t idx = 0UL;
      for(idx = 0UL; idx < parseState->cache.count; idx++) {
        if(JKN_EXPECT_T(parseState->cache.items[idx].object != NULL)) { CFRelease(parseState->cache.items[idx].object); parseState->cache.items[idx].object = NULL; }
        if(JKN_EXPECT_T(parseState->cache.items[idx].bytes  != NULL)) { free(parseState->cache.items[idx].bytes);       parseState->cache.items[idx].bytes  = NULL; }
        memset(&parseState->cache.items[idx], 0, sizeof(JKNTokenCacheItem));
        parseState->cache.age[idx] = 0U;
      }
    }
  }
}

// This needs to be completely rewritten.
static id _JKNParseUTF8String(JKNParseState *parseState, BOOL mutableCollections, const unsigned char *string, size_t length, NSError **error) {
  NSCParameterAssert((parseState != NULL) && (string != NULL) && (parseState->cache.prng_lfsr != 0U));
  parseState->stringBuffer.bytes.ptr    = string;
  parseState->stringBuffer.bytes.length = length;
  parseState->atIndex                   = 0UL;
  parseState->lineNumber                = 1UL;
  parseState->lineStartIndex            = 0UL;
  parseState->prev_atIndex              = 0UL;
  parseState->prev_lineNumber           = 1UL;
  parseState->prev_lineStartIndex       = 0UL;
  parseState->error                     = NULL;
  parseState->errorIsPrev               = 0;
  parseState->mutableCollections        = (mutableCollections == NO) ? NO : YES;
  
  unsigned char stackTokenBuffer[JKN_TOKENBUFFER_SIZE] JKN_ALIGNED(64);
  JKN_managedBuffer_setToStackBuffer(&parseState->token.tokenBuffer, stackTokenBuffer, sizeof(stackTokenBuffer));
  
  void       *stackObjects [JKN_STACK_OBJS] JKN_ALIGNED(64);
  void       *stackKeys    [JKN_STACK_OBJS] JKN_ALIGNED(64);
  CFHashCode  stackCFHashes[JKN_STACK_OBJS] JKN_ALIGNED(64);
  JKN_objectStack_setToStackBuffer(&parseState->objectStack, stackObjects, stackKeys, stackCFHashes, JKN_STACK_OBJS);
  
  id parsedJSON = json_parse_it(parseState);
  
  if((error != NULL) && (parseState->error != NULL)) { *error = parseState->error; }
  
  JKN_managedBuffer_release(&parseState->token.tokenBuffer);
  JKN_objectStack_release(&parseState->objectStack);
  
  parseState->stringBuffer.bytes.ptr    = NULL;
  parseState->stringBuffer.bytes.length = 0UL;
  parseState->atIndex                   = 0UL;
  parseState->lineNumber                = 1UL;
  parseState->lineStartIndex            = 0UL;
  parseState->prev_atIndex              = 0UL;
  parseState->prev_lineNumber           = 1UL;
  parseState->prev_lineStartIndex       = 0UL;
  parseState->error                     = NULL;
  parseState->errorIsPrev               = 0;
  parseState->mutableCollections        = NO;
  
  return(parsedJSON);
}

////////////
#pragma mark Deprecated as of v1.4
////////////

// Deprecated in JSONKit v1.4.  Use objectWithUTF8String:length: instead.
- (id)parseUTF8String:(const unsigned char *)string length:(size_t)length
{
  return([self objectWithUTF8String:string length:length error:NULL]);
}

// Deprecated in JSONKit v1.4.  Use objectWithUTF8String:length:error: instead.
- (id)parseUTF8String:(const unsigned char *)string length:(size_t)length error:(NSError **)error
{
  return([self objectWithUTF8String:string length:length error:error]);
}

// Deprecated in JSONKit v1.4.  Use objectWithData: instead.
- (id)parseJSONData:(NSData *)jsonData
{
  return([self objectWithData:jsonData error:NULL]);
}

// Deprecated in JSONKit v1.4.  Use objectWithData:error: instead.
- (id)parseJSONData:(NSData *)jsonData error:(NSError **)error
{
  return([self objectWithData:jsonData error:error]);
}

////////////
#pragma mark Methods that return immutable collection objects
////////////

- (id)objectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length
{
  return([self objectWithUTF8String:string length:length error:NULL]);
}

- (id)objectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length error:(NSError **)error
{
  if(parseState == NULL) { [NSException raise:NSInternalInconsistencyException format:@"parseState is NULL."];          }
  if(string     == NULL) { [NSException raise:NSInvalidArgumentException       format:@"The string argument is NULL."]; }
  
  return(_JKNParseUTF8String(parseState, NO, string, (size_t)length, error));
}

- (id)objectWithData:(NSData *)jsonData
{
  return([self objectWithData:jsonData error:NULL]);
}

- (id)objectWithData:(NSData *)jsonData error:(NSError **)error
{
  if(jsonData == NULL) { [NSException raise:NSInvalidArgumentException format:@"The jsonData argument is NULL."]; }
  return([self objectWithUTF8String:(const unsigned char *)[jsonData bytes] length:[jsonData length] error:error]);
}

////////////
#pragma mark Methods that return mutable collection objects
////////////

- (id)mutableObjectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length
{
  return([self mutableObjectWithUTF8String:string length:length error:NULL]);
}

- (id)mutableObjectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length error:(NSError **)error
{
  if(parseState == NULL) { [NSException raise:NSInternalInconsistencyException format:@"parseState is NULL."];          }
  if(string     == NULL) { [NSException raise:NSInvalidArgumentException       format:@"The string argument is NULL."]; }
  
  return(_JKNParseUTF8String(parseState, YES, string, (size_t)length, error));
}

- (id)mutableObjectWithData:(NSData *)jsonData
{
  return([self mutableObjectWithData:jsonData error:NULL]);
}

- (id)mutableObjectWithData:(NSData *)jsonData error:(NSError **)error
{
  if(jsonData == NULL) { [NSException raise:NSInvalidArgumentException format:@"The jsonData argument is NULL."]; }
  return([self mutableObjectWithUTF8String:(const unsigned char *)[jsonData bytes] length:[jsonData length] error:error]);
}

@end

/*
 The NSString and NSData convenience methods need a little bit of explanation.
 
 Prior to JSONKit v1.4, the NSString -objectFromJSONStringWithParseOptions:error: method looked like
 
 const unsigned char *utf8String = (const unsigned char *)[self UTF8String];
 if(utf8String == NULL) { return(NULL); }
 size_t               utf8Length = strlen((const char *)utf8String); 
 return([[JSONDecoderN decoderWithParseOptions:parseOptionFlags] parseUTF8String:utf8String length:utf8Length error:error]);
 
 This changed with v1.4 to a more complicated method.  The reason for this is to keep the amount of memory that is
 allocated, but not yet freed because it is dependent on the autorelease pool to pop before it can be reclaimed.
 
 In the simpler v1.3 code, this included all the bytes used to store the -UTF8String along with the JSONDecoderN and all its overhead.
 
 Now we use an autoreleased CFMutableData that is sized to the UTF8 length of the NSString in question and is used to hold the UTF8
 conversion of said string.
 
 Once parsed, the CFMutableData has its length set to 0.  This should, hopefully, allow the CFMutableData to realloc and/or free
 the buffer.
 
 Another change made was a slight modification to JSONDecoderN so that most of the cleanup work that was done in -dealloc was moved
 to a private, internal function.  These convenience routines keep the pointer to the autoreleased JSONDecoderN and calls
 _JSONDecoderNCleanup() to early release the decoders resources since we already know that particular decoder is not going to be used
 again.  
 
 If everything goes smoothly, this will most likely result in perhaps a few hundred bytes that are allocated but waiting for the
 autorelease pool to pop.  This is compared to the thousands and easily hundreds of thousands of bytes that would have been in
 autorelease limbo.  It's more complicated for us, but a win for the user.
 
 Autorelease objects are used in case things don't go smoothly.  By having them autoreleased, we effectively guarantee that our
 requirement to -release the object is always met, not matter what goes wrong.  The downside is having a an object or two in
 autorelease limbo, but we've done our best to minimize that impact, so it all balances out.
 */

@implementation NSString (JSONKitDeserializing)

static id _NSStringObjectFromJSONString(NSString *jsonString, JKNParseOptionFlags parseOptionFlags, NSError **error, BOOL mutableCollection) {
  id                returnObject = NULL;
  CFMutableDataRef  mutableData  = NULL;
  JSONDecoderN      *decoder      = NULL;
  
  CFIndex    stringLength     = CFStringGetLength((CFStringRef)jsonString);
  NSUInteger stringUTF8Length = [jsonString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
  
  if((mutableData = (CFMutableDataRef)[(id)CFDataCreateMutable(NULL, (NSUInteger)stringUTF8Length) autorelease]) != NULL) {
    UInt8   *utf8String = CFDataGetMutableBytePtr(mutableData);
    CFIndex  usedBytes  = 0L, convertedCount = 0L;
    
    convertedCount = CFStringGetBytes((CFStringRef)jsonString, CFRangeMake(0L, stringLength), kCFStringEncodingUTF8, '?', NO, utf8String, (NSUInteger)stringUTF8Length, &usedBytes);
    if(JKN_EXPECT_F(convertedCount != stringLength) || JKN_EXPECT_F(usedBytes < 0L)) { if(error != NULL) { *error = [NSError errorWithDomain:@"JKNErrorDomain" code:-1L userInfo:[NSDictionary dictionaryWithObject:@"An error occurred converting the contents of a NSString to UTF8." forKey:NSLocalizedDescriptionKey]]; } goto exitNow; }
    
    if(mutableCollection == NO) { returnObject = [(decoder = [JSONDecoderN decoderWithParseOptions:parseOptionFlags])        objectWithUTF8String:(const unsigned char *)utf8String length:(size_t)usedBytes error:error]; }
    else                        { returnObject = [(decoder = [JSONDecoderN decoderWithParseOptions:parseOptionFlags]) mutableObjectWithUTF8String:(const unsigned char *)utf8String length:(size_t)usedBytes error:error]; }
  }
  
exitNow:
  if(mutableData != NULL) { CFDataSetLength(mutableData, 0L); }
  if(decoder     != NULL) { _JSONDecoderNCleanup(decoder);     }
  return(returnObject);
}

- (id)objectFromJSONString
{
  return([self objectFromJSONStringWithParseOptions:JKNParseOptionStrict error:NULL]);
}

- (id)objectFromJSONStringWithParseOptions:(JKNParseOptionFlags)parseOptionFlags
{
  return([self objectFromJSONStringWithParseOptions:parseOptionFlags error:NULL]);
}

- (id)objectFromJSONStringWithParseOptions:(JKNParseOptionFlags)parseOptionFlags error:(NSError **)error
{
  return(_NSStringObjectFromJSONString(self, parseOptionFlags, error, NO));
}


- (id)mutableObjectFromJSONString
{
  return([self mutableObjectFromJSONStringWithParseOptions:JKNParseOptionStrict error:NULL]);
}

- (id)mutableObjectFromJSONStringWithParseOptions:(JKNParseOptionFlags)parseOptionFlags
{
  return([self mutableObjectFromJSONStringWithParseOptions:parseOptionFlags error:NULL]);
}

- (id)mutableObjectFromJSONStringWithParseOptions:(JKNParseOptionFlags)parseOptionFlags error:(NSError **)error
{
  return(_NSStringObjectFromJSONString(self, parseOptionFlags, error, YES));
}

@end

@implementation NSData (JSONKitDeserializing)

- (id)objectFromJSONData
{
  return([self objectFromJSONDataWithParseOptions:JKNParseOptionStrict error:NULL]);
}

- (id)objectFromJSONDataWithParseOptions:(JKNParseOptionFlags)parseOptionFlags
{
  return([self objectFromJSONDataWithParseOptions:parseOptionFlags error:NULL]);
}

- (id)objectFromJSONDataWithParseOptions:(JKNParseOptionFlags)parseOptionFlags error:(NSError **)error
{
  JSONDecoderN *decoder = NULL;
  id returnObject = [(decoder = [JSONDecoderN decoderWithParseOptions:parseOptionFlags]) objectWithData:self error:error];
  if(decoder != NULL) { _JSONDecoderNCleanup(decoder); }
  return(returnObject);
}

- (id)mutableObjectFromJSONDataN
{
  return([self mutableObjectFromJSONDataWithParseOptions:JKNParseOptionStrict error:NULL]);
}

- (id)mutableObjectFromJSONDataWithParseOptions:(JKNParseOptionFlags)parseOptionFlags
{
  return([self mutableObjectFromJSONDataWithParseOptions:parseOptionFlags error:NULL]);
}

- (id)mutableObjectFromJSONDataWithParseOptions:(JKNParseOptionFlags)parseOptionFlags error:(NSError **)error
{
  JSONDecoderN *decoder = NULL;
  id returnObject = [(decoder = [JSONDecoderN decoderWithParseOptions:parseOptionFlags]) mutableObjectWithData:self error:error];
  if(decoder != NULL) { _JSONDecoderNCleanup(decoder); }
  return(returnObject);
}


@end

////////////
#pragma mark -
#pragma mark Encoding / deserializing functions

static void JKN_encode_error(JKNEncodeState *encodeState, NSString *format, ...) {
  NSCParameterAssert((encodeState != NULL) && (format != NULL));

  va_list varArgsList;
  va_start(varArgsList, format);
  NSString *formatString = [[[NSString alloc] initWithFormat:format arguments:varArgsList] autorelease];
  va_end(varArgsList);

  if(encodeState->error == NULL) {
    encodeState->error = [NSError errorWithDomain:@"JKNErrorDomain" code:-1L userInfo:
                                   [NSDictionary dictionaryWithObjectsAndKeys:
                                                                              formatString, NSLocalizedDescriptionKey,
                                                                              NULL]];
  }
}

JKN_STATIC_INLINE void JKN_encode_updateCache(JKNEncodeState *encodeState, JKNEncodeCache *cacheSlot, size_t startingAtIndex, id object) {
  NSCParameterAssert(encodeState != NULL);
  if(JKN_EXPECT_T(cacheSlot != NULL)) {
    NSCParameterAssert((object != NULL) && (startingAtIndex <= encodeState->atIndex));
    cacheSlot->object = object;
    cacheSlot->offset = startingAtIndex;
    cacheSlot->length = (size_t)(encodeState->atIndex - startingAtIndex);  
  }
}

static int JKN_encode_printf(JKNEncodeState *encodeState, JKNEncodeCache *cacheSlot, size_t startingAtIndex, id object, const char *format, ...) {
  va_list varArgsList, varArgsListCopy;
  va_start(varArgsList, format);
  va_copy(varArgsListCopy, varArgsList);

  NSCParameterAssert((encodeState != NULL) && (encodeState->atIndex < encodeState->stringBuffer.bytes.length) && (startingAtIndex <= encodeState->atIndex) && (format != NULL));

  ssize_t  formattedStringLength = 0L;
  int      returnValue           = 0;

  if(JKN_EXPECT_T((formattedStringLength = vsnprintf((char *)&encodeState->stringBuffer.bytes.ptr[encodeState->atIndex], (encodeState->stringBuffer.bytes.length - encodeState->atIndex), format, varArgsList)) >= (ssize_t)(encodeState->stringBuffer.bytes.length - encodeState->atIndex))) {
    NSCParameterAssert(((encodeState->atIndex + (formattedStringLength * 2UL) + 256UL) > encodeState->stringBuffer.bytes.length));
    if(JKN_EXPECT_F(((encodeState->atIndex + (formattedStringLength * 2UL) + 256UL) > encodeState->stringBuffer.bytes.length)) && JKN_EXPECT_F((JKN_managedBuffer_resize(&encodeState->stringBuffer, encodeState->atIndex + (formattedStringLength * 2UL)+ 4096UL) == NULL))) { JKN_encode_error(encodeState, @"Unable to resize temporary buffer."); returnValue = 1; goto exitNow; }
    if(JKN_EXPECT_F((formattedStringLength = vsnprintf((char *)&encodeState->stringBuffer.bytes.ptr[encodeState->atIndex], (encodeState->stringBuffer.bytes.length - encodeState->atIndex), format, varArgsListCopy)) >= (ssize_t)(encodeState->stringBuffer.bytes.length - encodeState->atIndex))) { JKN_encode_error(encodeState, @"vsnprintf failed unexpectedly."); returnValue = 1; goto exitNow; }
  }
  
exitNow:
  va_end(varArgsList);
  va_end(varArgsListCopy);
  if(JKN_EXPECT_T(returnValue == 0)) { encodeState->atIndex += formattedStringLength; JKN_encode_updateCache(encodeState, cacheSlot, startingAtIndex, object); }
  return(returnValue);
}

static int JKN_encode_write(JKNEncodeState *encodeState, JKNEncodeCache *cacheSlot, size_t startingAtIndex, id object, const char *format) {
  NSCParameterAssert((encodeState != NULL) && (encodeState->atIndex < encodeState->stringBuffer.bytes.length) && (startingAtIndex <= encodeState->atIndex) && (format != NULL));
  if(JKN_EXPECT_F(((encodeState->atIndex + strlen(format) + 256UL) > encodeState->stringBuffer.bytes.length)) && JKN_EXPECT_F((JKN_managedBuffer_resize(&encodeState->stringBuffer, encodeState->atIndex + strlen(format) + 1024UL) == NULL))) { JKN_encode_error(encodeState, @"Unable to resize temporary buffer."); return(1); }

  size_t formatIdx = 0UL;
  for(formatIdx = 0UL; format[formatIdx] != 0; formatIdx++) { NSCParameterAssert(encodeState->atIndex < encodeState->stringBuffer.bytes.length); encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = format[formatIdx]; }
  JKN_encode_updateCache(encodeState, cacheSlot, startingAtIndex, object);
  return(0);
}

static int JKN_encode_writePrettyPrintWhiteSpace(JKNEncodeState *encodeState) {
  NSCParameterAssert((encodeState != NULL) && ((encodeState->serializeOptionFlags & JKNSerializeOptionPretty) != 0UL));
  if(JKN_EXPECT_F((encodeState->atIndex + ((encodeState->depth + 1UL) * 2UL) + 16UL) > encodeState->stringBuffer.bytes.length) && JKN_EXPECT_T(JKN_managedBuffer_resize(&encodeState->stringBuffer, encodeState->atIndex + ((encodeState->depth + 1UL) * 2UL) + 4096UL) == NULL)) { JKN_encode_error(encodeState, @"Unable to resize temporary buffer."); return(1); }
  encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\n';
  size_t depthWhiteSpace = 0UL;
  for(depthWhiteSpace = 0UL; depthWhiteSpace < (encodeState->depth * 2UL); depthWhiteSpace++) { NSCParameterAssert(encodeState->atIndex < encodeState->stringBuffer.bytes.length); encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = ' '; }
  return(0);
}  

static int JKN_encode_write1slow(JKNEncodeState *encodeState, ssize_t depthChange, const char *format) {
  NSCParameterAssert((encodeState != NULL) && (encodeState->atIndex < encodeState->stringBuffer.bytes.length) && (format != NULL) && ((depthChange >= -1L) && (depthChange <= 1L)) && ((encodeState->depth == 0UL) ? (depthChange >= 0L) : 1) && ((encodeState->serializeOptionFlags & JKNSerializeOptionPretty) != 0UL));
  if(JKN_EXPECT_F((encodeState->atIndex + ((encodeState->depth + 1UL) * 2UL) + 16UL) > encodeState->stringBuffer.bytes.length) && JKN_EXPECT_F(JKN_managedBuffer_resize(&encodeState->stringBuffer, encodeState->atIndex + ((encodeState->depth + 1UL) * 2UL) + 4096UL) == NULL)) { JKN_encode_error(encodeState, @"Unable to resize temporary buffer."); return(1); }
  encodeState->depth += depthChange;
  if(JKN_EXPECT_T(format[0] == ':')) { encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = format[0]; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = ' '; }
  else {
    if(JKN_EXPECT_F(depthChange == -1L)) { if(JKN_EXPECT_F(JKN_encode_writePrettyPrintWhiteSpace(encodeState))) { return(1); } }
    encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = format[0];
    if(JKN_EXPECT_T(depthChange != -1L)) { if(JKN_EXPECT_F(JKN_encode_writePrettyPrintWhiteSpace(encodeState))) { return(1); } }
  }
  NSCParameterAssert(encodeState->atIndex < encodeState->stringBuffer.bytes.length);
  return(0);
}

static int JKN_encode_write1fast(JKNEncodeState *encodeState, ssize_t depthChange JKN_UNUSED_ARG, const char *format) {
  NSCParameterAssert((encodeState != NULL) && (encodeState->atIndex < encodeState->stringBuffer.bytes.length) && ((encodeState->serializeOptionFlags & JKNSerializeOptionPretty) == 0UL));
  if(JKN_EXPECT_T((encodeState->atIndex + 4UL) < encodeState->stringBuffer.bytes.length)) { encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = format[0]; }
  else { return(JKN_encode_write(encodeState, NULL, 0UL, NULL, format)); }
  return(0);
}

static int JKN_encode_writen(JKNEncodeState *encodeState, JKNEncodeCache *cacheSlot, size_t startingAtIndex, id object, const char *format, size_t length) {
  NSCParameterAssert((encodeState != NULL) && (encodeState->atIndex < encodeState->stringBuffer.bytes.length) && (startingAtIndex <= encodeState->atIndex));
  if(JKN_EXPECT_F((encodeState->stringBuffer.bytes.length - encodeState->atIndex) < (length + 4UL))) { if(JKN_managedBuffer_resize(&encodeState->stringBuffer, encodeState->atIndex + 4096UL + length) == NULL) { JKN_encode_error(encodeState, @"Unable to resize temporary buffer."); return(1); } }
  memcpy(encodeState->stringBuffer.bytes.ptr + encodeState->atIndex, format, length);
  encodeState->atIndex += length;
  JKN_encode_updateCache(encodeState, cacheSlot, startingAtIndex, object);
  return(0);
}

JKN_STATIC_INLINE JKNHash JKN_encode_object_hash(void *objectPtr) {
  return( ( (((JKNHash)objectPtr) >> 21) ^ (((JKNHash)objectPtr) >> 9)   ) + (((JKNHash)objectPtr) >> 4) );
}

static int JKN_encode_add_atom_to_buffer(JKNEncodeState *encodeState, void *objectPtr) {
  NSCParameterAssert((encodeState != NULL) && (encodeState->atIndex < encodeState->stringBuffer.bytes.length) && (objectPtr != NULL));

  id     object          = (id)objectPtr, encodeCacheObject = object;
  int    isClass         = JKNClassUnknown;
  size_t startingAtIndex = encodeState->atIndex;

  JKNHash         objectHash = JKN_encode_object_hash(objectPtr);
  JKNEncodeCache *cacheSlot  = &encodeState->cache[objectHash % JKN_ENCODE_CACHE_SLOTS];

  if(JKN_EXPECT_T(cacheSlot->object == object)) {
    NSCParameterAssert((cacheSlot->object != NULL) &&
                       (cacheSlot->offset < encodeState->atIndex)                   && ((cacheSlot->offset + cacheSlot->length) < encodeState->atIndex)                                    &&
                       (cacheSlot->offset < encodeState->stringBuffer.bytes.length) && ((cacheSlot->offset + cacheSlot->length) < encodeState->stringBuffer.bytes.length)                  &&
                       ((encodeState->stringBuffer.bytes.ptr + encodeState->atIndex)                     < (encodeState->stringBuffer.bytes.ptr + encodeState->stringBuffer.bytes.length)) &&
                       ((encodeState->stringBuffer.bytes.ptr + cacheSlot->offset)                        < (encodeState->stringBuffer.bytes.ptr + encodeState->stringBuffer.bytes.length)) &&
                       ((encodeState->stringBuffer.bytes.ptr + cacheSlot->offset + cacheSlot->length)    < (encodeState->stringBuffer.bytes.ptr + encodeState->stringBuffer.bytes.length)));
    if(JKN_EXPECT_F(((encodeState->atIndex + cacheSlot->length + 256UL) > encodeState->stringBuffer.bytes.length)) && JKN_EXPECT_F((JKN_managedBuffer_resize(&encodeState->stringBuffer, encodeState->atIndex + cacheSlot->length + 1024UL) == NULL))) { JKN_encode_error(encodeState, @"Unable to resize temporary buffer."); return(1); }
    NSCParameterAssert(((encodeState->atIndex + cacheSlot->length) < encodeState->stringBuffer.bytes.length) &&
                       ((encodeState->stringBuffer.bytes.ptr + encodeState->atIndex)                     < (encodeState->stringBuffer.bytes.ptr + encodeState->stringBuffer.bytes.length)) &&
                       ((encodeState->stringBuffer.bytes.ptr + encodeState->atIndex + cacheSlot->length) < (encodeState->stringBuffer.bytes.ptr + encodeState->stringBuffer.bytes.length)) &&
                       ((encodeState->stringBuffer.bytes.ptr + cacheSlot->offset)                        < (encodeState->stringBuffer.bytes.ptr + encodeState->stringBuffer.bytes.length)) &&
                       ((encodeState->stringBuffer.bytes.ptr + cacheSlot->offset + cacheSlot->length)    < (encodeState->stringBuffer.bytes.ptr + encodeState->stringBuffer.bytes.length)) &&
                       ((encodeState->stringBuffer.bytes.ptr + cacheSlot->offset + cacheSlot->length)    < (encodeState->stringBuffer.bytes.ptr + encodeState->atIndex)));
    memcpy(encodeState->stringBuffer.bytes.ptr + encodeState->atIndex, encodeState->stringBuffer.bytes.ptr + cacheSlot->offset, cacheSlot->length);
    encodeState->atIndex += cacheSlot->length;
    return(0);
  }

  // When we encounter a class that we do not handle, and we have either a delegate or block that the user supplied to format unsupported classes,
  // we "re-run" the object check.  However, we re-run the object check exactly ONCE.  If the user supplies an object that isn't one of the
  // supported classes, we fail the second time (i.e., double fault error).
  BOOL rerunningAfterClassFormatter = NO;
 rerunAfterClassFormatter:;

  // XXX XXX XXX XXX
  //     
  //     We need to work around a bug in 10.7, which breaks ABI compatibility with Objective-C going back not just to 10.0, but OpenStep and even NextStep.
  //     
  //     It has long been documented that "the very first thing that a pointer to an Objective-C object "points to" is a pointer to that objects class".
  //     
  //     This is euphemistically called "tagged pointers".  There are a number of highly technical problems with this, most involving long passages from
  //     the C standard(s).  In short, one can make a strong case, couched from the perspective of the C standard(s), that that 10.7 "tagged pointers" are
  //     fundamentally Wrong and Broken, and should have never been implemented.  Assuming those points are glossed over, because the change is very clearly
  //     breaking ABI compatibility, this should have resulted in a minimum of a "minimum version required" bump in various shared libraries to prevent
  //     causes code that used to work just fine to suddenly break without warning.
  //
  //     In fact, the C standard says that the hack below is "undefined behavior"- there is no requirement that the 10.7 tagged pointer hack of setting the
  //     "lower, unused bits" must be preserved when casting the result to an integer type, but this "works" because for most architectures
  //     `sizeof(long) == sizeof(void *)` and the compiler uses the same representation for both.  (note: this is informal, not meant to be
  //     normative or pedantically correct).
  //     
  //     In other words, while this "works" for now, technically the compiler is not obligated to do "what we want", and a later version of the compiler
  //     is not required in any way to produce the same results or behavior that earlier versions of the compiler did for the statement below.
  //
  //     Fan-fucking-tastic.
  //     
  //     Why not just use `object_getClass()`?  Because `object->isa` reduces to (typically) a *single* instruction.  Calling `object_getClass()` requires
  //     that the compiler potentially spill registers, establish a function call frame / environment, and finally execute a "jump subroutine" instruction.
  //     Then, the called subroutine must spend half a dozen instructions in its prolog, however many instructions doing whatever it does, then half a dozen
  //     instructions in its prolog.  One instruction compared to dozens, maybe a hundred instructions.
  //     
  //     Yes, that's one to two orders of magnitude difference.  Which is compelling in its own right.  When going for performance, you're often happy with
  //     gains in the two to three percent range.
  //     
  // XXX XXX XXX XXX


  BOOL   workAroundMacOSXABIBreakingBug = (JKN_EXPECT_F(((NSUInteger)object) & 0x1))     ? YES  : NO;
  void  *objectISA                      = (JKN_EXPECT_F(workAroundMacOSXABIBreakingBug)) ? NULL : *((void **)objectPtr);
  if(JKN_EXPECT_F(workAroundMacOSXABIBreakingBug)) { goto slowClassLookup; }

       if(JKN_EXPECT_T(objectISA == encodeState->fastClassLookup.stringClass))     { isClass = JKNClassString;     }
  else if(JKN_EXPECT_T(objectISA == encodeState->fastClassLookup.numberClass))     { isClass = JKNClassNumber;     }
  else if(JKN_EXPECT_T(objectISA == encodeState->fastClassLookup.dictionaryClass)) { isClass = JKNClassDictionary; }
  else if(JKN_EXPECT_T(objectISA == encodeState->fastClassLookup.arrayClass))      { isClass = JKNClassArray;      }
  else if(JKN_EXPECT_T(objectISA == encodeState->fastClassLookup.nullClass))       { isClass = JKNClassNull;       }
  else if (JKN_EXPECT_F(objectISA == encodeState->fastClassLookup.dateClass)) {
      isClass = JKNClassDate;
  }
  else {
  slowClassLookup:
         if(JKN_EXPECT_T([object isKindOfClass:[NSString     class]])) { if(workAroundMacOSXABIBreakingBug == NO) { encodeState->fastClassLookup.stringClass     = objectISA; } isClass = JKNClassString;     }
    else if(JKN_EXPECT_T([object isKindOfClass:[NSNumber     class]])) { if(workAroundMacOSXABIBreakingBug == NO) { encodeState->fastClassLookup.numberClass     = objectISA; } isClass = JKNClassNumber;     }
    else if(JKN_EXPECT_T([object isKindOfClass:[NSDictionary class]])) { if(workAroundMacOSXABIBreakingBug == NO) { encodeState->fastClassLookup.dictionaryClass = objectISA; } isClass = JKNClassDictionary; }
    else if(JKN_EXPECT_T([object isKindOfClass:[NSArray      class]])) { if(workAroundMacOSXABIBreakingBug == NO) { encodeState->fastClassLookup.arrayClass      = objectISA; } isClass = JKNClassArray;      }
    else if(JKN_EXPECT_T([object isKindOfClass:[NSNull       class]])) { if(workAroundMacOSXABIBreakingBug == NO) { encodeState->fastClassLookup.nullClass       = objectISA; } isClass = JKNClassNull;       }
          else if (JKN_EXPECT_T([object isKindOfClass:NSDate.class])) {
              if (workAroundMacOSXABIBreakingBug == NO) {
                  encodeState->fastClassLookup.dateClass = objectISA;
              }
              isClass = JKNClassDate;
          }
    else {
      if((rerunningAfterClassFormatter == NO) && (
#ifdef __BLOCKS__
           ((encodeState->classFormatterBlock) && ((object = encodeState->classFormatterBlock(object))                                                                         != NULL)) ||
#endif
           ((encodeState->classFormatterIMP)   && ((object = encodeState->classFormatterIMP(encodeState->classFormatterDelegate, encodeState->classFormatterSelector, object)) != NULL))    )) { rerunningAfterClassFormatter = YES; goto rerunAfterClassFormatter; }
      
      if(rerunningAfterClassFormatter == NO) { JKN_encode_error(encodeState, @"Unable to serialize object class %@.", NSStringFromClass([encodeCacheObject class])); return(1); }
      else { JKN_encode_error(encodeState, @"Unable to serialize object class %@ that was returned by the unsupported class formatter.  Original object class was %@.", (object == NULL) ? @"NULL" : NSStringFromClass([object class]), NSStringFromClass([encodeCacheObject class])); return(1); }
    }
  }

  // This is here for the benefit of the optimizer.  It allows the optimizer to do loop invariant code motion for the JKNClassArray
  // and JKNClassDictionary cases when printing simple, single characters via JKN_encode_write(), which is actually a macro:
  // #define JKN_encode_write1(es, dc, f) (_JKN_encode_prettyPrint ? JKN_encode_write1slow(es, dc, f) : JKN_encode_write1fast(es, dc, f))
  int _JKN_encode_prettyPrint = JKN_EXPECT_T((encodeState->serializeOptionFlags & JKNSerializeOptionPretty) == 0) ? 0 : 1;

  switch(isClass) {
    case JKNClassString:
      {
        {
          const unsigned char *cStringPtr = (const unsigned char *)CFStringGetCStringPtr((CFStringRef)object, kCFStringEncodingMacRoman);
          if(cStringPtr != NULL) {
            const unsigned char *utf8String = cStringPtr;
            size_t               utf8Idx    = 0UL;

            CFIndex stringLength = CFStringGetLength((CFStringRef)object);
            if(JKN_EXPECT_F(((encodeState->atIndex + (stringLength * 2UL) + 256UL) > encodeState->stringBuffer.bytes.length)) && JKN_EXPECT_F((JKN_managedBuffer_resize(&encodeState->stringBuffer, encodeState->atIndex + (stringLength * 2UL) + 1024UL) == NULL))) { JKN_encode_error(encodeState, @"Unable to resize temporary buffer."); return(1); }

            if(JKN_EXPECT_T((encodeState->encodeOption & JKNEncodeOptionStringObjTrimQuotes) == 0UL)) { encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\"'; }
            for(utf8Idx = 0UL; utf8String[utf8Idx] != 0U; utf8Idx++) {
              NSCParameterAssert(((&encodeState->stringBuffer.bytes.ptr[encodeState->atIndex]) - encodeState->stringBuffer.bytes.ptr) < (ssize_t)encodeState->stringBuffer.bytes.length);
              NSCParameterAssert(encodeState->atIndex < encodeState->stringBuffer.bytes.length);
              if(JKN_EXPECT_F(utf8String[utf8Idx] >= 0x80U)) { encodeState->atIndex = startingAtIndex; goto slowUTF8Path; }
              if(JKN_EXPECT_F(utf8String[utf8Idx] <  0x20U)) {
                switch(utf8String[utf8Idx]) {
                  case '\b': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 'b'; break;
                  case '\f': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 'f'; break;
                  case '\n': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 'n'; break;
                  case '\r': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 'r'; break;
                  case '\t': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 't'; break;
                  default: if(JKN_EXPECT_F(JKN_encode_printf(encodeState, NULL, 0UL, NULL, "\\u%4.4x", utf8String[utf8Idx]))) { return(1); } break;
                }
              } else {
                if(JKN_EXPECT_F(utf8String[utf8Idx] == '\"') || JKN_EXPECT_F(utf8String[utf8Idx] == '\\') || (JKN_EXPECT_F(encodeState->serializeOptionFlags & JKNSerializeOptionEscapeForwardSlashes) && JKN_EXPECT_F(utf8String[utf8Idx] == '/'))) { encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; }
                encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = utf8String[utf8Idx];
              }
            }
            NSCParameterAssert((encodeState->atIndex + 1UL) < encodeState->stringBuffer.bytes.length);
            if(JKN_EXPECT_T((encodeState->encodeOption & JKNEncodeOptionStringObjTrimQuotes) == 0UL)) { encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\"'; }
            JKN_encode_updateCache(encodeState, cacheSlot, startingAtIndex, encodeCacheObject);
            return(0);
          }
        }

      slowUTF8Path:
        {
          CFIndex stringLength        = CFStringGetLength((CFStringRef)object);
          CFIndex maxStringUTF8Length = CFStringGetMaximumSizeForEncoding(stringLength, kCFStringEncodingUTF8) + 32L;
        
          if(JKN_EXPECT_F((size_t)maxStringUTF8Length > encodeState->utf8ConversionBuffer.bytes.length) && JKN_EXPECT_F(JKN_managedBuffer_resize(&encodeState->utf8ConversionBuffer, maxStringUTF8Length + 1024UL) == NULL)) { JKN_encode_error(encodeState, @"Unable to resize temporary buffer."); return(1); }
        
          CFIndex usedBytes = 0L, convertedCount = 0L;
          convertedCount = CFStringGetBytes((CFStringRef)object, CFRangeMake(0L, stringLength), kCFStringEncodingUTF8, '?', NO, encodeState->utf8ConversionBuffer.bytes.ptr, encodeState->utf8ConversionBuffer.bytes.length - 16L, &usedBytes);
          if(JKN_EXPECT_F(convertedCount != stringLength) || JKN_EXPECT_F(usedBytes < 0L)) { JKN_encode_error(encodeState, @"An error occurred converting the contents of a NSString to UTF8."); return(1); }
        
          if(JKN_EXPECT_F((encodeState->atIndex + (maxStringUTF8Length * 2UL) + 256UL) > encodeState->stringBuffer.bytes.length) && JKN_EXPECT_F(JKN_managedBuffer_resize(&encodeState->stringBuffer, encodeState->atIndex + (maxStringUTF8Length * 2UL) + 1024UL) == NULL)) { JKN_encode_error(encodeState, @"Unable to resize temporary buffer."); return(1); }
        
          const unsigned char *utf8String = encodeState->utf8ConversionBuffer.bytes.ptr;
        
          size_t utf8Idx = 0UL;
          if(JKN_EXPECT_T((encodeState->encodeOption & JKNEncodeOptionStringObjTrimQuotes) == 0UL)) { encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\"'; }
          for(utf8Idx = 0UL; utf8Idx < (size_t)usedBytes; utf8Idx++) {
            NSCParameterAssert(((&encodeState->stringBuffer.bytes.ptr[encodeState->atIndex]) - encodeState->stringBuffer.bytes.ptr) < (ssize_t)encodeState->stringBuffer.bytes.length);
            NSCParameterAssert(encodeState->atIndex < encodeState->stringBuffer.bytes.length);
            NSCParameterAssert((CFIndex)utf8Idx < usedBytes);
            if(JKN_EXPECT_F(utf8String[utf8Idx] < 0x20U)) {
              switch(utf8String[utf8Idx]) {
                case '\b': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 'b'; break;
                case '\f': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 'f'; break;
                case '\n': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 'n'; break;
                case '\r': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 'r'; break;
                case '\t': encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = 't'; break;
                default: if(JKN_EXPECT_F(JKN_encode_printf(encodeState, NULL, 0UL, NULL, "\\u%4.4x", utf8String[utf8Idx]))) { return(1); } break;
              }
            } else {
              if(JKN_EXPECT_F(utf8String[utf8Idx] >= 0x80U) && (encodeState->serializeOptionFlags & JKNSerializeOptionEscapeUnicode)) {
                const unsigned char *nextValidCharacter = NULL;
                UTF32                u32ch              = 0U;
                ConversionResult     result;

                if(JKN_EXPECT_F((result = ConvertSingleCodePointInUTF8(&utf8String[utf8Idx], &utf8String[usedBytes], (UTF8 const **)&nextValidCharacter, &u32ch)) != conversionOK)) { JKN_encode_error(encodeState, @"Error converting UTF8."); return(1); }
                else {
                  utf8Idx = (nextValidCharacter - utf8String) - 1UL;
                  if(JKN_EXPECT_T(u32ch <= 0xffffU)) { if(JKN_EXPECT_F(JKN_encode_printf(encodeState, NULL, 0UL, NULL, "\\u%4.4x", u32ch)))                                                           { return(1); } }
                  else                              { if(JKN_EXPECT_F(JKN_encode_printf(encodeState, NULL, 0UL, NULL, "\\u%4.4x\\u%4.4x", (0xd7c0U + (u32ch >> 10)), (0xdc00U + (u32ch & 0x3ffU))))) { return(1); } }
                }
              } else {
                if(JKN_EXPECT_F(utf8String[utf8Idx] == '\"') || JKN_EXPECT_F(utf8String[utf8Idx] == '\\') || (JKN_EXPECT_F(encodeState->serializeOptionFlags & JKNSerializeOptionEscapeForwardSlashes) && JKN_EXPECT_F(utf8String[utf8Idx] == '/'))) { encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\\'; }
                encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = utf8String[utf8Idx];
              }
            }
          }
          NSCParameterAssert((encodeState->atIndex + 1UL) < encodeState->stringBuffer.bytes.length);
          if(JKN_EXPECT_T((encodeState->encodeOption & JKNEncodeOptionStringObjTrimQuotes) == 0UL)) { encodeState->stringBuffer.bytes.ptr[encodeState->atIndex++] = '\"'; }
          JKN_encode_updateCache(encodeState, cacheSlot, startingAtIndex, encodeCacheObject);
          return(0);
        }
      }
      break;

    case JKNClassNumber:
      {
             if(object == (id)kCFBooleanTrue)  { return(JKN_encode_writen(encodeState, cacheSlot, startingAtIndex, encodeCacheObject, "true",  4UL)); }
        else if(object == (id)kCFBooleanFalse) { return(JKN_encode_writen(encodeState, cacheSlot, startingAtIndex, encodeCacheObject, "false", 5UL)); }
        
        const char         *objCType = [object objCType];
        char                anum[256], *aptr = &anum[255];
        int                 isNegative = 0;
        unsigned long long  ullv;
        long long           llv;
        
        if(JKN_EXPECT_F(objCType == NULL) || JKN_EXPECT_F(objCType[0] == 0) || JKN_EXPECT_F(objCType[1] != 0)) { JKN_encode_error(encodeState, @"NSNumber conversion error, unknown type.  Type: '%s'", (objCType == NULL) ? "<NULL>" : objCType); return(1); }
        
        switch(objCType[0]) {
          case 'c': case 'i': case 's': case 'l': case 'q':
            if(JKN_EXPECT_T(CFNumberGetValue((CFNumberRef)object, kCFNumberLongLongType, &llv)))  {
              if(llv < 0LL)  { ullv = -llv; isNegative = 1; } else { ullv = llv; isNegative = 0; }
              goto convertNumber;
            } else { JKN_encode_error(encodeState, @"Unable to get scalar value from number object."); return(1); }
            break;
          case 'C': case 'I': case 'S': case 'L': case 'Q': case 'B':
            if(JKN_EXPECT_T(CFNumberGetValue((CFNumberRef)object, kCFNumberLongLongType, &ullv))) {
            convertNumber:
              if(JKN_EXPECT_F(ullv < 10ULL)) { *--aptr = ullv + '0'; } else { while(JKN_EXPECT_T(ullv > 0ULL)) { *--aptr = (ullv % 10ULL) + '0'; ullv /= 10ULL; NSCParameterAssert(aptr > anum); } }
              if(isNegative) { *--aptr = '-'; }
              NSCParameterAssert(aptr > anum);
              return(JKN_encode_writen(encodeState, cacheSlot, startingAtIndex, encodeCacheObject, aptr, &anum[255] - aptr));
            } else { JKN_encode_error(encodeState, @"Unable to get scalar value from number object."); return(1); }
            break;
          case 'f': case 'd':
            {
              double dv;
              if(JKN_EXPECT_T(CFNumberGetValue((CFNumberRef)object, kCFNumberDoubleType, &dv))) {
                if(JKN_EXPECT_F(!isfinite(dv))) { JKN_encode_error(encodeState, @"Floating point values must be finite.  JSON does not support NaN or Infinity."); return(1); }
                return(JKN_encode_printf(encodeState, cacheSlot, startingAtIndex, encodeCacheObject, "%.17g", dv));
              } else { JKN_encode_error(encodeState, @"Unable to get floating point value from number object."); return(1); }
            }
            break;
          default: JKN_encode_error(encodeState, @"NSNumber conversion error, unknown type.  Type: '%c' / 0x%2.2x", objCType[0], objCType[0]); return(1); break;
        }
      }
      break;
    
    case JKNClassArray:
      {
        int     printComma = 0;
        CFIndex arrayCount = CFArrayGetCount((CFArrayRef)object), idx = 0L;
        if(JKN_EXPECT_F(JKN_encode_write1(encodeState, 1L, "["))) { return(1); }
        if(JKN_EXPECT_F(arrayCount > 1020L)) {
          for(id arrayObject in object)          { if(JKN_EXPECT_T(printComma)) { if(JKN_EXPECT_F(JKN_encode_write1(encodeState, 0L, ","))) { return(1); } } printComma = 1; if(JKN_EXPECT_F(JKN_encode_add_atom_to_buffer(encodeState, arrayObject)))  { return(1); } }
        } else {
          void *objects[1024];
          CFArrayGetValues((CFArrayRef)object, CFRangeMake(0L, arrayCount), (const void **)objects);
          for(idx = 0L; idx < arrayCount; idx++) { if(JKN_EXPECT_T(printComma)) { if(JKN_EXPECT_F(JKN_encode_write1(encodeState, 0L, ","))) { return(1); } } printComma = 1; if(JKN_EXPECT_F(JKN_encode_add_atom_to_buffer(encodeState, objects[idx]))) { return(1); } }
        }
        return(JKN_encode_write1(encodeState, -1L, "]"));
      }
      break;

    case JKNClassDictionary:
      {
        int     printComma      = 0;
        CFIndex dictionaryCount = CFDictionaryGetCount((CFDictionaryRef)object), idx = 0L;
        id      enumerateObject = JKN_EXPECT_F(_JKN_encode_prettyPrint) ? [[object allKeys] sortedArrayUsingSelector:@selector(compare:)] : object;

        if(JKN_EXPECT_F(JKN_encode_write1(encodeState, 1L, "{"))) { return(1); }
        if(JKN_EXPECT_F(_JKN_encode_prettyPrint) || JKN_EXPECT_F(dictionaryCount > 1020L)) {
          for(id keyObject in enumerateObject) {
            if(JKN_EXPECT_T(printComma)) { if(JKN_EXPECT_F(JKN_encode_write1(encodeState, 0L, ","))) { return(1); } }
            printComma = 1;
            void *keyObjectISA = *((void **)keyObject);
            if(JKN_EXPECT_F((keyObjectISA != encodeState->fastClassLookup.stringClass)) && JKN_EXPECT_F(([keyObject isKindOfClass:[NSString class]] == NO))) { JKN_encode_error(encodeState, @"Key must be a string object."); return(1); }
            if(JKN_EXPECT_F(JKN_encode_add_atom_to_buffer(encodeState, keyObject)))                                                        { return(1); }
            if(JKN_EXPECT_F(JKN_encode_write1(encodeState, 0L, ":")))                                                                      { return(1); }
            if(JKN_EXPECT_F(JKN_encode_add_atom_to_buffer(encodeState, (void *)CFDictionaryGetValue((CFDictionaryRef)object, keyObject)))) { return(1); }
          }
        } else {
          void *keys[1024], *objects[1024];
          CFDictionaryGetKeysAndValues((CFDictionaryRef)object, (const void **)keys, (const void **)objects);
          for(idx = 0L; idx < dictionaryCount; idx++) {
            if(JKN_EXPECT_T(printComma)) { if(JKN_EXPECT_F(JKN_encode_write1(encodeState, 0L, ","))) { return(1); } }
            printComma = 1;
            void *keyObjectISA = *((void **)keys[idx]);
            if(JKN_EXPECT_F(keyObjectISA != encodeState->fastClassLookup.stringClass) && JKN_EXPECT_F([(id)keys[idx] isKindOfClass:[NSString class]] == NO)) { JKN_encode_error(encodeState, @"Key must be a string object."); return(1); }
            if(JKN_EXPECT_F(JKN_encode_add_atom_to_buffer(encodeState, keys[idx])))    { return(1); }
            if(JKN_EXPECT_F(JKN_encode_write1(encodeState, 0L, ":")))                  { return(1); }
            if(JKN_EXPECT_F(JKN_encode_add_atom_to_buffer(encodeState, objects[idx]))) { return(1); }
          }
        }
        return(JKN_encode_write1(encodeState, -1L, "}"));
      }
      break;
          
      case JKNClassNull:
          return(JKN_encode_writen(encodeState, cacheSlot, startingAtIndex, encodeCacheObject, "null", 4UL)); break;
          
      case JKNClassDate:
      {
          object = [NSNumber numberWithDouble:((NSDate *)object).timeIntervalSince1970];
          const char         *objCType = [object objCType];
          
          if(JKN_EXPECT_F(objCType == NULL) || JKN_EXPECT_F(objCType[0] == 0) || JKN_EXPECT_F(objCType[1] != 0)) { JKN_encode_error(encodeState, @"NSDate conversion error, unknown type.  Type: '%s'", (objCType == NULL) ? "<NULL>" : objCType); return(1); }
          
          switch(objCType[0]) {
              case 'f': case 'd':
              {
                  double dv;
                  if(JKN_EXPECT_T(CFNumberGetValue((CFNumberRef)object, kCFNumberDoubleType, &dv))) {
                      if(JKN_EXPECT_F(!isfinite(dv))) { JKN_encode_error(encodeState, @"Floating point values must be finite.  JSON does not support NaN or Infinity."); return(1); }
                      return(JKN_encode_printf(encodeState, cacheSlot, startingAtIndex, encodeCacheObject, "T%.17g", dv));
                  } else { JKN_encode_error(encodeState, @"Unable to get floating point value from number object."); return(1); }
              }
                  break;
              default: JKN_encode_error(encodeState, @"NSNumber conversion error, unknown type.  Type: '%c' / 0x%2.2x", objCType[0], objCType[0]); return(1); break;
          }
      }
          break;
          
    default: JKN_encode_error(encodeState, @"Unable to serialize object class %@.", NSStringFromClass([object class])); return(1); break;
  }

  return(0);
}


@implementation JKNSerializer

+ (id)serializeObject:(id)object options:(JKNSerializeOptionFlags)optionFlags encodeOption:(JKNEncodeOptionType)encodeOption block:(JKNSERIALIZER_BLOCKS_PROTO)block delegate:(id)delegate selector:(SEL)selector error:(NSError **)error
{
  return([[[[self alloc] init] autorelease] serializeObject:object options:optionFlags encodeOption:encodeOption block:block delegate:delegate selector:selector error:error]);
}

- (id)serializeObject:(id)object options:(JKNSerializeOptionFlags)optionFlags encodeOption:(JKNEncodeOptionType)encodeOption block:(JKNSERIALIZER_BLOCKS_PROTO)block delegate:(id)delegate selector:(SEL)selector error:(NSError **)error
{
#ifndef __BLOCKS__
#pragma unused(block)
#endif
    NSParameterAssert((object != NULL) && (encodeState == NULL) && ((delegate != NULL) ? (block == NULL) : 1) && ((block != NULL) ? (delegate == NULL) : 1) &&
                    (((encodeOption & JKNEncodeOptionCollectionObj) != 0UL) ? (((encodeOption & JKNEncodeOptionStringObj)     == 0UL) && ((encodeOption & JKNEncodeOptionStringObjTrimQuotes) == 0UL)) : 1) &&
                    (((encodeOption & JKNEncodeOptionStringObj)     != 0UL) ?  ((encodeOption & JKNEncodeOptionCollectionObj) == 0UL)                                                                 : 1));

    id returnObject = NULL;

    if(encodeState != NULL) { [self releaseState]; }
    if((encodeState = (struct JKNEncodeState *)calloc(1UL, sizeof(JKNEncodeState))) == NULL) { [NSException raise:NSMallocException format:@"Unable to allocate state structure."]; return(NULL); }

    if((error != NULL) && (*error != NULL)) { *error = NULL; }

    if(delegate != NULL) {
        if(selector                               == NULL) { [NSException raise:NSInvalidArgumentException format:@"The delegate argument is not NULL, but the selector argument is NULL."]; }
        if([delegate respondsToSelector:selector] == NO)   { [NSException raise:NSInvalidArgumentException format:@"The serializeUnsupportedClassesUsingDelegate: delegate does not respond to the selector argument."]; }
        encodeState->classFormatterDelegate = delegate;
        encodeState->classFormatterSelector = selector;
        encodeState->classFormatterIMP      = (JKNClassFormatterIMP)[delegate methodForSelector:selector];
        NSCParameterAssert(encodeState->classFormatterIMP != NULL);
    }

#ifdef __BLOCKS__
    encodeState->classFormatterBlock                          = block;
#endif
    encodeState->serializeOptionFlags                         = optionFlags;
    encodeState->encodeOption                                 = encodeOption;
    encodeState->stringBuffer.roundSizeUpToMultipleOf         = (1024UL * 32UL);
    encodeState->utf8ConversionBuffer.roundSizeUpToMultipleOf = 4096UL;
    
    unsigned char stackJSONBuffer[JKN_JSONBUFFER_SIZE] JKN_ALIGNED(64);
    JKN_managedBuffer_setToStackBuffer(&encodeState->stringBuffer,         stackJSONBuffer, sizeof(stackJSONBuffer));

    unsigned char stackUTF8Buffer[JKN_UTF8BUFFER_SIZE] JKN_ALIGNED(64);
    JKN_managedBuffer_setToStackBuffer(&encodeState->utf8ConversionBuffer, stackUTF8Buffer, sizeof(stackUTF8Buffer));

    if (((encodeOption & JKNEncodeOptionCollectionObj) != 0UL) && (([object isKindOfClass:[NSArray  class]] == NO) && ([object isKindOfClass:[NSDictionary class]] == NO))) {
        JKN_encode_error(encodeState, @"Unable to serialize object class %@, expected a NSArray or NSDictionary.", NSStringFromClass([object class]));
        goto errorExit;
    }
    if (((encodeOption & JKNEncodeOptionStringObj) != 0UL) && ([object isKindOfClass:[NSString class]] == NO)) {
        JKN_encode_error(encodeState, @"Unable to serialize object class %@, expected a NSString.", NSStringFromClass([object class]));
        goto errorExit;
    }

    if (JKN_encode_add_atom_to_buffer(encodeState, object) == 0) {
        BOOL stackBuffer = ((encodeState->stringBuffer.flags & JKNManagedBufferMustFree) == 0UL) ? YES : NO;
    
        if((encodeState->atIndex < 2UL))
            if((stackBuffer == NO) && ((encodeState->stringBuffer.bytes.ptr = (unsigned char *)reallocf(encodeState->stringBuffer.bytes.ptr, encodeState->atIndex + 16UL)) == NULL)) { JKN_encode_error(encodeState, @"Unable to realloc buffer"); goto errorExit; }

        switch((encodeOption & JKNEncodeOptionAsTypeMask)) {
            case JKNEncodeOptionAsData:
                if(stackBuffer == YES) { if((returnObject = [(id)CFDataCreate(                 NULL,                encodeState->stringBuffer.bytes.ptr, (CFIndex)encodeState->atIndex)                                  autorelease]) == NULL) { JKN_encode_error(encodeState, @"Unable to create NSData object"); } }
                else                   { if((returnObject = [(id)CFDataCreateWithBytesNoCopy(  NULL,                encodeState->stringBuffer.bytes.ptr, (CFIndex)encodeState->atIndex, NULL)                            autorelease]) == NULL) { JKN_encode_error(encodeState, @"Unable to create NSData object"); } }
                break;

            case JKNEncodeOptionAsString:
                if(stackBuffer == YES) { if((returnObject = [(id)CFStringCreateWithBytes(      NULL, (const UInt8 *)encodeState->stringBuffer.bytes.ptr, (CFIndex)encodeState->atIndex, kCFStringEncodingUTF8, NO)       autorelease]) == NULL) { JKN_encode_error(encodeState, @"Unable to create NSString object"); } }
                else                   { if((returnObject = [(id)CFStringCreateWithBytesNoCopy(NULL, (const UInt8 *)encodeState->stringBuffer.bytes.ptr, (CFIndex)encodeState->atIndex, kCFStringEncodingUTF8, NO, NULL) autorelease]) == NULL) { JKN_encode_error(encodeState, @"Unable to create NSString object"); } }
                break;

            default: JKN_encode_error(encodeState, @"Unknown encode as type."); break;
        }

        if((returnObject != NULL) && (stackBuffer == NO)) { encodeState->stringBuffer.flags &= ~JKNManagedBufferMustFree; encodeState->stringBuffer.bytes.ptr = NULL; encodeState->stringBuffer.bytes.length = 0UL; }
    }

errorExit:
    if((encodeState != NULL) && (error != NULL) && (encodeState->error != NULL)) { *error = encodeState->error; encodeState->error = NULL; }
    [self releaseState];

    return(returnObject);
}


- (void)releaseState
{
  if(encodeState != NULL) {
    JKN_managedBuffer_release(&encodeState->stringBuffer);
    JKN_managedBuffer_release(&encodeState->utf8ConversionBuffer);
    free(encodeState); encodeState = NULL;
  }  
}

- (void)dealloc
{
  [self releaseState];
  [super dealloc];
}

@end

@implementation NSString (JSONKitSerializing)

////////////
#pragma mark Methods for serializing a single NSString.
////////////

// Useful for those who need to serialize just a NSString.  Otherwise you would have to do something like [NSArray arrayWithObject:stringToBeJSONSerialized], serializing the array, and then chopping of the extra ^\[.*\]$ square brackets.

// NSData returning methods...

- (NSData *)JSONData
{
  return([self JSONDataWithOptions:JKNSerializeOptionNone includeQuotes:YES error:NULL]);
}

- (NSData *)JSONDataWithOptions:(JKNSerializeOptionFlags)serializeOptions includeQuotes:(BOOL)includeQuotes error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsData | ((includeQuotes == NO) ? JKNEncodeOptionStringObjTrimQuotes : 0UL) | JKNEncodeOptionStringObj) block:NULL delegate:NULL selector:NULL error:error]);
}

// NSString returning methods...

- (NSString *)JSONString
{
  return([self JSONStringWithOptions:JKNSerializeOptionNone includeQuotes:YES error:NULL]);
}

- (NSString *)JSONStringWithOptions:(JKNSerializeOptionFlags)serializeOptions includeQuotes:(BOOL)includeQuotes error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsString | ((includeQuotes == NO) ? JKNEncodeOptionStringObjTrimQuotes : 0UL) | JKNEncodeOptionStringObj) block:NULL delegate:NULL selector:NULL error:error]);
}

@end

@implementation NSArray (JSONKitSerializing)

// NSData returning methods...

- (NSData *)JSONData
{
  return([JKNSerializer serializeObject:self options:JKNSerializeOptionNone encodeOption:(JKNEncodeOptionAsData | JKNEncodeOptionCollectionObj) block:NULL delegate:NULL selector:NULL error:NULL]);
}

- (NSData *)JSONDataWithOptions:(JKNSerializeOptionFlags)serializeOptions error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsData | JKNEncodeOptionCollectionObj) block:NULL delegate:NULL selector:NULL error:error]);
}

- (NSData *)JSONDataWithOptions:(JKNSerializeOptionFlags)serializeOptions serializeUnsupportedClassesUsingDelegate:(id)delegate selector:(SEL)selector error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsData | JKNEncodeOptionCollectionObj) block:NULL delegate:delegate selector:selector error:error]);
}

// NSString returning methods...

- (NSString *)JSONString
{
  return([JKNSerializer serializeObject:self options:JKNSerializeOptionNone encodeOption:(JKNEncodeOptionAsString | JKNEncodeOptionCollectionObj) block:NULL delegate:NULL selector:NULL error:NULL]);
}

- (NSString *)JSONStringWithOptions:(JKNSerializeOptionFlags)serializeOptions error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsString | JKNEncodeOptionCollectionObj) block:NULL delegate:NULL selector:NULL error:error]);
}

- (NSString *)JSONStringWithOptions:(JKNSerializeOptionFlags)serializeOptions serializeUnsupportedClassesUsingDelegate:(id)delegate selector:(SEL)selector error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsString | JKNEncodeOptionCollectionObj) block:NULL delegate:delegate selector:selector error:error]);
}

@end

@implementation NSDictionary (JSONKitSerializing)

// NSData returning methods...

- (NSData *)JSONDataN
{
  return([JKNSerializer serializeObject:self options:JKNSerializeOptionNone encodeOption:(JKNEncodeOptionAsData | JKNEncodeOptionCollectionObj) block:NULL delegate:NULL selector:NULL error:NULL]);
}

- (NSData *)JSONDataWithOptions:(JKNSerializeOptionFlags)serializeOptions error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsData | JKNEncodeOptionCollectionObj) block:NULL delegate:NULL selector:NULL error:error]);
}

- (NSData *)JSONDataWithOptions:(JKNSerializeOptionFlags)serializeOptions serializeUnsupportedClassesUsingDelegate:(id)delegate selector:(SEL)selector error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsData | JKNEncodeOptionCollectionObj) block:NULL delegate:delegate selector:selector error:error]);
}

// NSString returning methods...

- (NSString *)JSONString
{
  return([JKNSerializer serializeObject:self options:JKNSerializeOptionNone encodeOption:(JKNEncodeOptionAsString | JKNEncodeOptionCollectionObj) block:NULL delegate:NULL selector:NULL error:NULL]);
}

- (NSString *)JSONStringWithOptions:(JKNSerializeOptionFlags)serializeOptions error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsString | JKNEncodeOptionCollectionObj) block:NULL delegate:NULL selector:NULL error:error]);
}

- (NSString *)JSONStringWithOptions:(JKNSerializeOptionFlags)serializeOptions serializeUnsupportedClassesUsingDelegate:(id)delegate selector:(SEL)selector error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsString | JKNEncodeOptionCollectionObj) block:NULL delegate:delegate selector:selector error:error]);
}

@end


#ifdef __BLOCKS__

@implementation NSArray (JSONKitSerializingBlockAdditions)

- (NSData *)JSONDataWithOptions:(JKNSerializeOptionFlags)serializeOptions serializeUnsupportedClassesUsingBlock:(id(^)(id object))block error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsData | JKNEncodeOptionCollectionObj) block:block delegate:NULL selector:NULL error:error]);
}

- (NSString *)JSONStringWithOptions:(JKNSerializeOptionFlags)serializeOptions serializeUnsupportedClassesUsingBlock:(id(^)(id object))block error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsString | JKNEncodeOptionCollectionObj) block:block delegate:NULL selector:NULL error:error]);
}

@end

@implementation NSDictionary (JSONKitSerializingBlockAdditions)

- (NSData *)JSONDataWithOptions:(JKNSerializeOptionFlags)serializeOptions serializeUnsupportedClassesUsingBlock:(id(^)(id object))block error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsData | JKNEncodeOptionCollectionObj) block:block delegate:NULL selector:NULL error:error]);
}

- (NSString *)JSONStringWithOptions:(JKNSerializeOptionFlags)serializeOptions serializeUnsupportedClassesUsingBlock:(id(^)(id object))block error:(NSError **)error
{
  return([JKNSerializer serializeObject:self options:serializeOptions encodeOption:(JKNEncodeOptionAsString | JKNEncodeOptionCollectionObj) block:block delegate:NULL selector:NULL error:error]);
}

@end

#endif // __BLOCKS__

