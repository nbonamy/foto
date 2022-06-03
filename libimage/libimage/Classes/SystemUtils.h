//
//  SystemUtils.h
//  cam2mac
//
//  Created by Nicolas Bonamy on 02/01/13.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import <Foundation/Foundation.h>

#define IPHOTO_BUNDLE_ID @"com.apple.iPhoto"
#define PHOTOSHOP_BUNDLE_ID @"com.adobe.Photoshop"

@interface SystemUtils : NSObject

+ (NSString*) defaultApplicationForFile:(NSString*) path;

+ (NSString*) bundlePathForIdentifier:(NSString*) identifier;

+ (void) openFiles:(NSArray*) files withBundleIdentifier:(NSString*) identifier;

@end
