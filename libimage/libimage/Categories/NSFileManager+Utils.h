//
//  NSFileManager+Utils.h
//  cam2mac
//
//  Created by Nicolas Bonamy on 11/01/13.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (Utils)

- (NSString*) temporaryFilename;
- (NSString*) temporaryFilename:(NSString*) baseFilename;

+ (NSString*) temporaryFilename;
+ (NSString*) temporaryFilename:(NSString*) baseFilename;

@end
