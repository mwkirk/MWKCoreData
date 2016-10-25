//
//  EmployeeToEmployeePolicy.m
//  MWKCoreData
//
//  Created by Mark Kirk on 6/24/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//

#import "EmployeeToEmployeePolicy.h"

@implementation EmployeeToEmployeePolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject*)aSrcInstance
                                      entityMapping:(NSEntityMapping*)aEntityMapping
                                            manager:(NSMigrationManager*)aMigrationMgr
                                              error:(NSError *__autoreleasing*)aError
{
    NSNumber *destModelVersion = aEntityMapping.userInfo[@"destModelVersion"];
    
    if (destModelVersion && destModelVersion.integerValue == 3) {
        NSString *srcName = (NSString*)[aSrcInstance valueForKey:@"name"];
        NSArray *names = [srcName componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if (names.count != 2) {
            [NSException raise:NSGenericException format:@"Employee name doesn't split into first/last names. Bad fixture store?"];
        }
        
        NSManagedObject *destInstance = [NSEntityDescription insertNewObjectForEntityForName:aEntityMapping.destinationEntityName
                                                                      inManagedObjectContext:aMigrationMgr.destinationContext];
        [destInstance setValue:[names firstObject] forKey:@"firstName"];
        [destInstance setValue:[names lastObject] forKey:@"lastName"];
        
        [aMigrationMgr associateSourceInstance:aSrcInstance withDestinationInstance:destInstance forEntityMapping:aEntityMapping];
        return YES;
    }
    
    // Call super if it's an unhandled dest model version
    return [super createDestinationInstancesForSourceInstance:aSrcInstance
                                                entityMapping:aEntityMapping
                                                      manager:aMigrationMgr
                                                        error:aError];
}



@end
