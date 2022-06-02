//
//  FileUtils.h
//  cam2mac
//
//  Created by Nicolas Bonamy on 26/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileUtils : NSObject

+ (BOOL) isFile:(NSString*) path conformingTo:(CFStringRef) UTType orHasExtensionIn:(NSArray*) extensions;
+ (BOOL) isImageFile:(NSString*) path;
+ (BOOL) isVideoFile:(NSString*) path;

+ (NSImage*) getIcon:(NSString*) path;

+ (void) moveItemToTrash:(NSString*) path;

+ (NSDate*) getCreationDateForFile:(NSString*) file;
+ (NSDate*) getModificationDateForFile:(NSString*) file;
+ (void) setCreationDate:(NSDate*) creationDate forFile:(NSString*) file;
+ (void) setModificationDate:(NSDate*) modificationDate forFile:(NSString*) file;

+ (BOOL) replaceFile:(NSString*) oldFile withFile:(NSString*) newFile;
+ (BOOL) replaceFile:(NSString*) oldFile withFile:(NSString*) newFile isTemporary:(BOOL) isTemp;

@end
