//
//  ModelV1Tests.m
//  MWKCoreData
//
//  Created by Mark Kirk on 6/17/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <MWKCoreData/MWKCoreData.h>
#import "TestUtil.h"

@interface FixtureStores : XCTestCase

@end

@implementation FixtureStores

//
// These were each run once to create the store fixtures. I know, kinda lame...
//


- (void)createFixtureForModelVersion1
{
    CoreDataManager *mgr = [self managerForModelName:@"MWKCoreDataTests" version:@""];
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    ctx.persistentStoreCoordinator = mgr.persistentStoreCoordinator;

    // Employee is the only entity in this model, create several Employees
    NSArray *names = @[@"Adam Smith", @"Bob Johnson", @"Carla Jones"];
    
    for (NSString *name in names) {
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Employee" inManagedObjectContext:ctx];
        NSManagedObject *obj = [[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:ctx];
        [obj setValue:name forKey:@"name"];
    }
    
    NSError *error = nil;
    [ctx save:&error];
    
    NSLog(@"%@", mgr.persistentStoreURL);
}


- (void)createFixtureForModelVersion2
{
    CoreDataManager *mgr = [self managerForModelName:@"MWKCoreDataTests" version:@"2"];
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    ctx.persistentStoreCoordinator = mgr.persistentStoreCoordinator;
    
    NSArray *names = @[@"Adam Smith", @"Bob Johnson", @"Carla Jones"];
    NSArray *deptNames = @[@"Marketing", @"Shipping", @"Engineering"];
    
    for (int i = 0; i < names.count; ++i) {
        NSEntityDescription *deptEntity = [NSEntityDescription entityForName:@"Dept" inManagedObjectContext:ctx];
        NSManagedObject *dept = [[NSManagedObject alloc] initWithEntity:deptEntity insertIntoManagedObjectContext:ctx];
        [dept setValue:deptNames[i] forKey:@"name"];
        
        NSEntityDescription *employeeEntity = [NSEntityDescription entityForName:@"Employee" inManagedObjectContext:ctx];
        NSManagedObject *employee = [[NSManagedObject alloc] initWithEntity:employeeEntity insertIntoManagedObjectContext:ctx];
        [employee setValue:names[i] forKey:@"name"];
        [employee setValue:dept forKey:@"dept"];
    }
    
    NSError *error = nil;
    [ctx save:&error];
    
    NSLog(@"%@", mgr.persistentStoreURL);
}





#pragma mark - Helpers

- (CoreDataManager*)managerForModelName:(NSString*)aModelName version:(NSString*)aVersion
{
    // Load model version 1 (no version suffix)
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSManagedObjectModel *model = [TestUtil modelWithName:aModelName version:aVersion inBundle:testBundle];
    XCTAssertNotNil(model);
    
    // Creates a store with model version 1
    CoreDataManager *mgr = [[CoreDataManager alloc] initWithManagedObjectModel:model
                                                        persistentStoreOptions:nil
                                                           persistentStoreType:nil
                                                             persisentStoreURL:nil
                                                                        bundle:testBundle];
    
    // Remove any existing store file
    [[NSFileManager defaultManager] removeItemAtURL:mgr.persistentStoreURL error:nil];
    
    NSError *error = nil;
    [mgr initializeStack:&error];
    XCTAssertNil(error);
    
    return mgr;
}

@end
