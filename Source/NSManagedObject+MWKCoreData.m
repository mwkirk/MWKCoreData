//
//  NSManagedObject+MWKCoreData.m
//  MWKCoreData
//
//  Created by Mark Kirk on 6/15/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//  MIT License. Please see the included LICENSE file of the
//  software https://github.com/mwkirk/MWKCoreData
//
// Portions of this software are based upon and inspired by ObjectiveRecord
// https://github.com/supermarin/ObjectiveRecord by Marin Usalj <http://supermar.in>
// The following notice is included per ObjectiveRecord's MIT License:
//
// Copyright (c) 2014 Marin Usalj <http://supermar.in>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "NSManagedObject+MWKCoreData.h"
#import "NSManagedObjectContext+MWKCoreData.h"

@implementation NSObject (null)

- (BOOL)exists
{
    return self && self != [NSNull null];
}

- (void)awakeFromCreate
{
    // no-op
}

@end



@implementation NSManagedObject (MWKCoreData)

#pragma mark - awakeFromCreate

- (void)awakeFromCreate
{
    [super awakeFromCreate];
}


#pragma mark - Finders

+ (NSArray*)all
{
    return [self allInContext:[NSManagedObjectContext defaultContext]];
}


+ (NSArray*)allWithOrder:(id)order
{
    return [self allInContext:[NSManagedObjectContext defaultContext] order:order];
}


+ (NSArray*)allInContext:(NSManagedObjectContext*)context
{
    return [self allInContext:context order:nil];
}


+ (NSArray*)allInContext:(NSManagedObjectContext*)context order:(id)order
{
    return [self fetchWithCondition:nil inContext:context withOrder:order fetchLimit:nil];
}


+ (NSArray*)where:(id)condition, ...
{
    va_list va_arguments;
    va_start(va_arguments, condition);
    NSPredicate *predicate = [self predicateFromObject:condition arguments:va_arguments];
    va_end(va_arguments);

    return [self where:predicate inContext:[NSManagedObjectContext defaultContext]];
}


+ (NSArray*)where:(id)condition order:(id)order
{
    return [self where:condition inContext:[NSManagedObjectContext defaultContext] order:order];
}


+ (NSArray*)where:(id)condition limit:(NSNumber*)limit
{
    return [self where:condition inContext:[NSManagedObjectContext defaultContext] limit:limit];
}


+ (NSArray*)where:(id)condition order:(id)order limit:(NSNumber*)limit
{
    return [self where:condition inContext:[NSManagedObjectContext defaultContext] order:order limit:limit];
}


+ (NSArray*)where:(id)condition inContext:(NSManagedObjectContext*)context
{
    return [self where:condition inContext:context order:nil limit:nil];
}


+ (NSArray*)where:(id)condition inContext:(NSManagedObjectContext*)context order:(id)order
{
    return [self where:condition inContext:context order:order limit:nil];
}


+ (NSArray*)where:(id)condition inContext:(NSManagedObjectContext*)context limit:(NSNumber*)limit
{
    return [self where:condition inContext:context order:nil limit:limit];
}


+ (NSArray*)where:(id)condition inContext:(NSManagedObjectContext*)context order:(id)order limit:(NSNumber*)limit
{
    return [self fetchWithCondition:condition inContext:context withOrder:order fetchLimit:limit];
}


#pragma mark - Aggregation

+ (NSUInteger)count
{
    return [self countInContext:[NSManagedObjectContext defaultContext]];
}


+ (NSUInteger)countWhere:(id)condition, ...
{
    va_list va_arguments;
    va_start(va_arguments, condition);
    NSPredicate *predicate = [self predicateFromObject:condition arguments:va_arguments];
    va_end(va_arguments);

    return [self countWhere:predicate inContext:[NSManagedObjectContext defaultContext]];
}


+ (NSUInteger)countInContext:(NSManagedObjectContext*)context
{
    return [self countForFetchWithPredicate:nil inContext:context];
}

+ (NSUInteger)countWhere:(id)condition inContext:(NSManagedObjectContext*)context
{
    NSPredicate *predicate = [self predicateFromObject:condition];
    return [self countForFetchWithPredicate:predicate inContext:context];
}

#pragma mark - Creation / Deletion

+ (instancetype)create
{
    return [self createInContext:[NSManagedObjectContext defaultContext]];
}


+ (instancetype)createInContext:(NSManagedObjectContext*)context
{
    id obj = [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
                                           inManagedObjectContext:context];
    if ([obj respondsToSelector:@selector(awakeFromCreate)]) {
        [obj awakeFromCreate];
    }
    
    return obj;
}


- (BOOL)save
{
    return [self.managedObjectContext save];
}


- (void)delete
{
    [self.managedObjectContext deleteObject:self];
}


+ (void)deleteAll
{
    [self deleteAllInContext:[NSManagedObjectContext defaultContext]];
}


+ (void)deleteAllInContext:(NSManagedObjectContext*)context
{
    [[self allInContext:context] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj delete];
    }];
}


#pragma mark - Naming

+ (NSString*)entityName
{
    return NSStringFromClass(self);
}


#pragma mark - Private

+ (NSPredicate*)predicateFromDictionary:(NSDictionary*)dict
{
    NSMutableArray *subpredicates = [NSMutableArray arrayWithCapacity:dict.count];
    
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"%K = %@", key, obj];
        if (pred) [subpredicates addObject:pred];
    }];
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
}


+ (NSPredicate*)predicateFromObject:(id)condition
{
    return [self predicateFromObject:condition arguments:NULL];
}


+ (NSPredicate*)predicateFromObject:(id)condition arguments:(va_list)arguments
{
    if ([condition isKindOfClass:[NSPredicate class]])
        return condition;

    if ([condition isKindOfClass:[NSString class]])
        return [NSPredicate predicateWithFormat:condition arguments:arguments];

    if ([condition isKindOfClass:[NSDictionary class]])
        return [self predicateFromDictionary:condition];

    return nil;
}


+ (NSSortDescriptor*)sortDescriptorFromDictionary:(NSDictionary*)dict
{
    BOOL isAscending = ![[dict.allValues.firstObject uppercaseString] isEqualToString:@"DESC"];
    return [NSSortDescriptor sortDescriptorWithKey:dict.allKeys.firstObject
                                         ascending:isAscending];
}


+ (NSSortDescriptor*)sortDescriptorFromString:(NSString*)order
{
    NSArray *parts = [order componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *components = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    
    NSString *key = [components firstObject];
    NSString *value = [components count] > 1 ? components[1] : @"ASC";

    return [self sortDescriptorFromDictionary:@{key: value}];

}


+ (NSSortDescriptor*)sortDescriptorFromObject:(id)order
{
    if ([order isKindOfClass:[NSSortDescriptor class]])
        return order;

    if ([order isKindOfClass:[NSString class]])
        return [self sortDescriptorFromString:order];

    if ([order isKindOfClass:[NSDictionary class]])
        return [self sortDescriptorFromDictionary:order];

    return nil;
}


+ (NSArray*)sortDescriptorsFromObject:(id)order
{
    if ([order isKindOfClass:[NSString class]])
        order = [order componentsSeparatedByString:@","];
    
    if ([order isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [NSMutableArray new];
        
        [order enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [array addObject:[self sortDescriptorFromObject:obj]];
        }];
        
        return array;
    }
    
    return @[[self sortDescriptorFromObject:order]];
}


+ (NSFetchRequest*)createFetchRequestInContext:(NSManagedObjectContext*)context
{
    NSFetchRequest *request = [NSFetchRequest new];
    NSEntityDescription *entity = [NSEntityDescription entityForName:[self entityName]
                                              inManagedObjectContext:context];
    [request setEntity:entity];
    return request;
}


+ (NSArray*)fetchWithCondition:(id)condition
                     inContext:(NSManagedObjectContext*)context
                     withOrder:(id)order
                    fetchLimit:(NSNumber*)fetchLimit
{
    
    NSFetchRequest *request = [self createFetchRequestInContext:context];
    
    if (condition)
        [request setPredicate:[self predicateFromObject:condition]];
    
    if (order)
        [request setSortDescriptors:[self sortDescriptorsFromObject:order]];

    if (fetchLimit)
        [request setFetchLimit:[fetchLimit integerValue]];

    return [context executeFetchRequest:request error:nil];
}


+ (NSUInteger)countForFetchWithPredicate:(NSPredicate*)predicate
                               inContext:(NSManagedObjectContext*)context
{
    NSFetchRequest *request = [self createFetchRequestInContext:context];
    [request setPredicate:predicate];

    return [context countForFetchRequest:request error:nil];
}


- (void)setSafeValue:(id)value forKey:(NSString*)key
{
    if (value == nil || value == [NSNull null]) {
        [self setNilValueForKey:key];
        return;
    }

    NSAttributeDescription *attribute = [[self entity] attributesByName][key];
    NSAttributeType attributeType = [attribute attributeType];

    if ((attributeType == NSStringAttributeType) && ([value isKindOfClass:[NSNumber class]]))
        value = [value stringValue];

    else if ([value isKindOfClass:[NSString class]]) {

        if ([self isIntegerAttributeType:attributeType])
            value = [NSNumber numberWithLongLong:[value longLongValue]];

        else if (attributeType == NSBooleanAttributeType)
            value = [NSNumber numberWithBool:[value boolValue]];

        else if ([self isFloatAttributeType:attributeType])
            value = [NSNumber numberWithDouble:[value doubleValue]];

        else if (attributeType == NSDateAttributeType)
            value = [self.defaultFormatter dateFromString:value];
    }

    [self setPrimitiveValue:value forKey:key];
}


- (BOOL)isIntegerAttributeType:(NSAttributeType)attributeType
{
    return (attributeType == NSInteger16AttributeType) ||
           (attributeType == NSInteger32AttributeType) ||
           (attributeType == NSInteger64AttributeType);
}


- (BOOL)isFloatAttributeType:(NSAttributeType)attributeType
{
    return (attributeType == NSFloatAttributeType) ||
           (attributeType == NSDoubleAttributeType);
}

#pragma mark - Date Formatting

- (NSDateFormatter*)defaultFormatter
{
    static NSDateFormatter *sharedFormatter;
    static dispatch_once_t singletonToken;
    dispatch_once(&singletonToken, ^{
        sharedFormatter = [[NSDateFormatter alloc] init];
        [sharedFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss z"];
    });

    return sharedFormatter;
}

@end
