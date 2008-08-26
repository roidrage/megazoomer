//
//  ZoomableWindow.m
//  megazoomer
//
//  Created by Ian Henderson on 20.09.05.
//  Copyright 2005 Ian Henderson. All rights reserved.
//

#import "MegaZoomer.h"
#import "ZoomableWindow.h"
#import <Carbon/Carbon.h>
#import <objc/objc-class.h>

#define NOT_BIG 0
#define GETTING_BIG 1
#define TOTALLY_BIG 2

static NSMutableDictionary *bignesses = nil;
static NSMutableDictionary *originalFrames = nil;
static NSMutableDictionary *originalBackgroundMovabilities = nil;

@interface NSWindow(ZoomableWindowSwizzle)
- (NSRect)__appkit_constrainFrameRect:(NSRect)r toScreen:(NSScreen *)s;
- (BOOL)__appkit_isZoomable;
- (BOOL)__appkit_isResizable;
- (BOOL)__appkit_isMiniaturizable;
- (BOOL)__appkit_validateMenuItem:(NSMenuItem *)item;
- (void)__appkit_zoom:sender;
- (void)__appkit_performZoom:sender;
- (void)__appkit_toggleToolbarShown:sender;
- (void)__appkit_setFrame:(NSRect)windowFrame display:(BOOL)displayViews;
- (void)__appkit_close;
@end

@implementation NSWindow(ZoomableWindow)

- (void)__megazoomer_close
{
    if ([self isBig]) {
        [self returnToOriginal];
    }
    [self __appkit_close];
}

- (void)__megazoomer_setFrame:(NSRect)windowFrame display:(BOOL)displayViews
{
	if (![self isBig]) {
		[self __appkit_setFrame:windowFrame display:displayViews];
	}
}

- (NSRect)__megazoomer_constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
{
	if ([self isBig] || [self isGettingBig]) {
		return [self megaZoomedFrame];
	} else {
		return [self __appkit_constrainFrameRect:frameRect toScreen:screen];
	}
}

- (void)setBig:(int)big
{
	if (!bignesses) {
		bignesses = [[NSMutableDictionary alloc] init];
	}
	[bignesses setObject:[NSNumber numberWithInt:big] forKey:[NSNumber numberWithInt:[self windowNumber]]];
}

- (void)returnToOriginal
{
	NSRect originalFrame = [[originalFrames objectForKey:[NSNumber numberWithInt:[self windowNumber]]] rectValue];
    [self setBig:NOT_BIG];
    [self setShowsResizeIndicator:YES];
    [self setFrame:originalFrame display:YES animate:YES];
    [self setMovableByWindowBackground:[[originalBackgroundMovabilities objectForKey:[NSNumber numberWithInt:[self windowNumber]]] boolValue]];
    if (![NSWindow anyBig]) {
        SetSystemUIMode(kUIModeNormal, 0);
    }
}

- (void)__megazoomer_toggleToolbarShown:sender
{
    if (![self isBig]) {
        [self __appkit_toggleToolbarShown:sender];
    }
}

- (BOOL)__megazoomer_validateMenuItem:(NSMenuItem *)item
{
    if ([self isBig] && ([item action] == @selector(toggleToolbarShown:) || [item action] == @selector(performZoom:) )) {
        return NO;
    }
    if ([self respondsToSelector:@selector(__appkit_validateMenuItem:)]) {
        return [self __appkit_validateMenuItem:item];
    }
    return YES;
}

#define NOT_WHEN_BIG(method) \
- (BOOL)__megazoomer_ ## method \
{ \
    if ([self isBig]) { \
        return NO; \
    } \
    return [self __appkit_ ## method]; \
}

NOT_WHEN_BIG(isResizable)
NOT_WHEN_BIG(isMiniaturizable)
NOT_WHEN_BIG(isZoomable)

- (void)__megazoomer_zoom:sender
{
    if (![self isBig]) {
        [self __appkit_zoom:sender];
    }
}

- (void)__megazoomer_performZoom:sender
{
    if (![self isBig]) {
        [self __appkit_performZoom:sender];
    }
}

- (BOOL)isMegaZoomable
{
    return [self __appkit_isZoomable] || ([MegaZoomer zoomMenuItem] != nil && [self validateMenuItem:[MegaZoomer zoomMenuItem]]);
}

- (NSRect)megaZoomedFrame
{
    NSRect newContentRect = [[self screen] frame];
    return [NSWindow frameRectForContentRect:newContentRect styleMask:[self styleMask]];
}

- (void)megaZoom
{
    if (![self isMegaZoomable]) {
        return;
    }
    if (![NSWindow anyBig]) {
        SetSystemUIMode(kUIModeAllHidden, kUIOptionAutoShowMenuBar);
    }
	if (!originalFrames) {
		originalFrames = [[NSMutableDictionary alloc] init];
	}
	[originalFrames setObject:[NSValue valueWithRect:[self frame]] forKey:[NSNumber numberWithInt:[self windowNumber]]];
    
    if (!originalBackgroundMovabilities) {
        originalBackgroundMovabilities = [[NSMutableDictionary alloc] init];
    }
	[originalBackgroundMovabilities setObject:[NSNumber numberWithBool:[self isMovableByWindowBackground]] forKey:[NSNumber numberWithInt:[self windowNumber]]];
    
    [self setBig:GETTING_BIG];
    [self setShowsResizeIndicator:NO];
    [self setFrame:[self megaZoomedFrame] display:YES animate:YES];
    [self setMovableByWindowBackground:NO];
    [self setBig:TOTALLY_BIG];
}

- (void)toggleMegaZoom
{
    if ([self isBig]) {
        [self returnToOriginal];
    } else {
        [self megaZoom];
    }
}

- (BOOL)isBig
{
	return [[bignesses objectForKey:[NSNumber numberWithInt:[self windowNumber]]] intValue] == TOTALLY_BIG;
}
- (BOOL)isGettingBig
{
	return [[bignesses objectForKey:[NSNumber numberWithInt:[self windowNumber]]] intValue] == GETTING_BIG;
}

+ (BOOL)anyBig
{
    NSEnumerator *bignessEnumerator = [[bignesses allValues] objectEnumerator];
    NSNumber *isBig;
    while ((isBig = [bignessEnumerator nextObject]) != nil) {
        if ([isBig boolValue]) {
            return YES;
        }
    }
    return NO;
}

+ (void)swizzle:(struct objc_method *)custom
{
    SEL custom_sel = custom->method_name;
    NSString *name = NSStringFromSelector(custom_sel);
    // __megazoomer_ <- 13 characters
    name = [name substringFromIndex:13];
    SEL old_sel = NSSelectorFromString(name);
    SEL new_sel = NSSelectorFromString([NSString stringWithFormat:@"__appkit_%@", name]);
    
    struct objc_method *old = class_getInstanceMethod([self class], old_sel);
    
    if (old == NULL) {
        return;
    }
    
    custom->method_name = old_sel;
    old->method_name = new_sel;
}

+ (void)swizzleZoomerMethods
{
    void *iter = 0;
    struct objc_method_list *mlist;
    while (mlist = class_nextMethodList([self class], &iter)) {
        int i;
        for (i=0; i<mlist->method_count; i++) {
            struct objc_method *m = mlist->method_list + i;
            NSString *name = NSStringFromSelector(m->method_name);
            if ([name hasPrefix:@"__megazoomer_"]) {
                [self swizzle:m];
            }
        }
    }
}

@end
