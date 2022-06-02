//
//  BitmapImage.h
//  cam2mac
//
//  Created by Nicolas Bonamy on 16/01/13.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSImage+Transform.h"
#import "NSBitmapImageRep+Save.h"

__attribute__((deprecated))
@interface BitmapImage : NSBitmapImageRep

- (id) initWithBitmapImage:(NSBitmapImageRep*) image;

// "copying" another bitmap image
- (id) initLikeBitmapImage:(NSBitmapImageRep*) image;
- (id) initLikeBitmapImage:(NSBitmapImageRep*) image width:(NSUInteger) width height:(NSUInteger) height;

// loading
- (id) initWithContentsOfFile:(NSString*) path;
+ (BitmapImage*) loadImageFromFile:(NSString*) path;

// info
- (NSSize) size;
- (NSRect) bounds;
- (NSUInteger) width;
- (NSUInteger) height;
- (NSUInteger) bytesPerPixel;
- (unsigned char*) dataAtX:(NSInteger) x atY:(NSInteger) y;

// processing
- (BitmapImage*) scaleTo:(NSSize) size;
- (BitmapImage*) transform:(ImageTransformation) transform;

@end
