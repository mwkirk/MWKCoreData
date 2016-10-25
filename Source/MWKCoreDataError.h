//
//  MWKCoreDataError.h
//  MWKCoreData
//
//  Created by Mark Kirk on 6/19/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString* const MWKCoreDataErrorDomain;

typedef enum : NSUInteger {
    MWKCoreDataErrorNoManagedObjectModelFilesFound = 8001,
    MWKCoreDataErrorSourceManagedObjectModelFileNotFound = 8002,
    MWKCoreDataErrorNewerManagedObjectModelFilesNotFound = 8003,
    MWKCoreDataErrorNoMappingModelsFound = 8004,
} MWKCoreDataError;

