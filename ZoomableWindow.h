//
//  ZoomableWindow.h
//  megazoomer
//
//  Created by Ian Henderson on 20.09.05.
//  Copyright 2005 Ian Henderson. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSWindow(ZoomableWindow)

+ (void)swizzleZoomerMethods;

+ (BOOL)anyBig;

- (BOOL)isMegaZoomable;

- (BOOL)isBig;
- (BOOL)isGettingBig;

- (void)megaZoom;
- (void)returnToOriginal;

- (void)toggleMegaZoom;

- (NSRect)megaZoomedFrame;

@end
