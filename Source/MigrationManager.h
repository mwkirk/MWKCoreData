//
//  MigrationManager.h
//  MWKCoreData
//
//  Created by Mark Kirk on 6/19/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//  MIT License. Please see the included LICENSE file of the
//  software https://github.com/mwkirk/MWKCoreData
//
//  Based largely upon the excellent objc.io Issue #4 article
//  "Custom Core Data Migrations" by Martin Hwasser and his
//  accompanying example code (used under the MIT License):
//  https://www.objc.io/issues/4-core-data/core-data-migration/
//  https://github.com/objcio/issue-4-core-data-migration
//  MHWMigrationManager.h
//  BookMigration
//
//  Created by Martin Hwasser on 8/30/13.
//  Copyright (c) 2013 Martin Hwasser. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NSManagedObjectModel;

// Progress update block handler
typedef void (^MWKCoreDataMigrationProgressHandler)(NSUInteger aPass, float aProgress);


@interface MigrationManager : NSObject

@property (nonatomic, copy) MWKCoreDataMigrationProgressHandler migrationProgressHandler;
@property (nonatomic, strong) NSURL *originalSrcStoreBackupURL;
@property (nonatomic, strong) NSComparator modelURLVersionComparator;

- (BOOL)progressivelyMigrateStoreAtURL:(NSURL*)aSrcStoreURL
                                ofType:(NSString*)aType
                               toModel:(NSManagedObjectModel*)aFinalModel
                          modelsBundle:(NSBundle*)aBundle
                                 error:(NSError**)aError;

@end