//
//  MWKCoreDataTests.m
//  MWKCoreDataTests
//
//  Created by Mark Kirk on 6/15/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <MWKCoreData/MWKCoreData.h>
#import "TestUtil.h"

@interface CoreDataManagerDefaultsTests : XCTestCase

@property (nonatomic, strong) CoreDataManager *mgr;

@end


@implementation CoreDataManagerDefaultsTests

- (void)setUp
{
    [super setUp];
    self.mgr = [[CoreDataManager alloc] initWithManagedObjectModel:nil
                                            persistentStoreOptions:nil
                                               persistentStoreType:nil
                                                 persisentStoreURL:nil
                                                            bundle:[NSBundle bundleForClass:[self class]]];
}


- (void)tearDown
{
    NSURL *storeUrl = self.mgr.persistentStoreURL;
    self.mgr = nil;
    [TestUtil removeSQLitePersistentStoreAtURL:storeUrl];
    [super tearDown];
}


- (void)testDefaultManagedObjectModel
{
    XCTAssertNotNil(self.mgr.managedObjectModel);

    NSArray *entities = self.mgr.managedObjectModel.entities;
    XCTAssert(entities.count > 0);
}


- (void)testDefaultPersistentStoreOptions
{
    NSDictionary *options = @{NSInferMappingModelAutomaticallyOption : @YES,
                              NSPersistentStoreFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication};
    XCTAssertTrue([options isEqualToDictionary:self.mgr.persistentStoreOptions]);
}


- (void)testDefaultPersistentStoreType
{
    XCTAssertEqualObjects(self.mgr.persistentStoreType, NSSQLiteStoreType);
}


- (void)testDefaultPersistentStoreURL
{
    XCTAssertNotNil(self.mgr.persistentStoreURL);
}


- (void)testDefaultStackInitialization
{
    NSError *error = nil;
    XCTAssertTrue([self.mgr initializeStack:&error]);
    XCTAssertNil(error);
}



- (void)testDefaultPersistentStoreCoordinatorPriorToStackInitialization
{
    NSPersistentStoreCoordinator *psc = self.mgr.persistentStoreCoordinator;
    XCTAssertNil(psc);
}


- (void)testDefaultPersistentStoreCoordinatorAfterStackInitialization
{
    NSError *error = nil;
    XCTAssertTrue([self.mgr initializeStack:&error]);
    
    NSPersistentStoreCoordinator *psc = self.mgr.persistentStoreCoordinator;
    XCTAssertNotNil(psc);

    // Verify store count
    XCTAssertTrue(psc.persistentStores.count == 1);

    // Check that store's url matches
    NSPersistentStore *store = [psc.persistentStores firstObject];
    XCTAssertEqualObjects(store.URL, self.mgr.persistentStoreURL);
}


- (void)testDefaultPersisentStoreCreated
{
    // Check that store's sqlite file was created
    XCTAssertTrue([self.mgr initializeStack:nil]);
    NSPersistentStoreCoordinator *psc = self.mgr.persistentStoreCoordinator;
    XCTAssertNotNil(psc);

    NSLog(@"store: %@", self.mgr.persistentStoreURL.path);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.mgr.persistentStoreURL.path]);
}



@end
